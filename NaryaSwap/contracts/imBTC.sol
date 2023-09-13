// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC1820Registry.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Sender.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract EarnERC777 is IERC777, IERC20 {
    using SafeMath for uint256;
    using Address for address;

    struct Balance {
        uint256 value;
        uint256 exchangeRate;
    }

    uint256 constant RATE_SCALE = 10**18;
    uint256 constant DECIMAL_SCALE = 10**18;

    IERC1820Registry internal _erc1820;

    mapping(address => Balance) internal _balances;

    uint256 internal _totalSupply;
    uint256 internal _exchangeRate;

    string internal _name;
    string internal _symbol;
    uint8 internal _decimals;

    // We inline the result of the following hashes because Solidity doesn't resolve them at compile time.
    // See https://github.com/ethereum/solidity/issues/4024.

    // keccak256("ERC777TokensSender")
    bytes32 constant internal TOKENS_SENDER_INTERFACE_HASH =
        0x29ddb589b1fb5fc7cf394961c1adf5f8c6454761adf795e67fe149f658abe895;

    // keccak256("ERC777TokensRecipient")
    bytes32 constant internal TOKENS_RECIPIENT_INTERFACE_HASH =
        0xb281fc8c12954d22544db45de3159a39272895b169a852b314f9cc762e44c53b;

    //Empty, This is only used to respond the defaultOperators query.
    address[] internal _defaultOperatorsArray;

    // For each account, a mapping of its operators and revoked default operators.
    mapping(address => mapping(address => bool)) internal _operators;

    // ERC20-allowances
    mapping (address => mapping (address => uint256)) internal _allowances;

    constructor(
        string memory symbolIn,
        string memory nameIn,
        uint8 decimalsIn,
        address erc1820In
    ) {
        require(decimalsIn <= 18, "decimals must be less or equal than 18");

        _name = nameIn;
        _symbol = symbolIn;
        _decimals = decimalsIn;

        _erc1820 = IERC1820Registry(erc1820In);

        _exchangeRate = 10**18;

        // register interfaces
        _erc1820.setInterfaceImplementer(address(this), keccak256("ERC777Token"), address(this));
        _erc1820.setInterfaceImplementer(address(this), keccak256("ERC20Token"), address(this));
    }

    /**
     * @dev See `IERC777.name`.
     */
    function name() external override view returns (string memory) {
        return _name;
    }

    /**
     * @dev See `IERC777.symbol`.
     */
    function symbol() external override view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See `ERC20Detailed.decimals`.
     *
     * Always returns 18, as per the
     * [ERC777 EIP](https://eips.ethereum.org/EIPS/eip-777#backward-compatibility).
     */
    function decimals() external view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See `IERC777.granularity`.
     *
     * This implementation always returns `1`.
     */
    function granularity() external override pure returns (uint256) {
        return 1;
    }

    /**
     * @dev See `IERC777.totalSupply`.
     */
    function totalSupply() external override(IERC20, IERC777) view returns (uint256) {
        return _totalSupply.div(DECIMAL_SCALE);
    }

    /**
     * @dev Returns the amount of tokens owned by an account (`tokenHolder`).
     */
    function balanceOf(address who) external override(IERC20, IERC777) view returns (uint256) {
        return _balanceOf(who);
    }

    function _balanceOf(address who) internal view returns (uint256) {
        return _getBalance(who).value.div(DECIMAL_SCALE);
    }

    function accuracyBalanceOf(address who) external view returns (uint256) {
        return _getBalance(who).value ;
    }

    /**
     * @dev See `IERC777.send`.
     *
     * Also emits a `Transfer` event for ERC20 compatibility.
     */
    function send(address recipient, uint256 amount, bytes calldata data) external override {
        _send(msg.sender, msg.sender, recipient, amount, data, "", true);
    }

    /**
     * @dev See `IERC20.transfer`.
     *
     * Unlike `send`, `recipient` is _not_ required to implement the `tokensReceived`
     * interface if it is a contract.
     *
     * Also emits a `Sent` event.
     */
    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _transfer(recipient, amount);
    }

    function _transfer(address recipient, uint256 amount) internal returns (bool) {
        require(recipient != address(0), "ERC777: transfer to the zero address");

        address from = msg.sender;

        _callTokensToSend(from, from, recipient, amount, "", "");

        _move(from, from, recipient, amount, "", "");

        _callTokensReceived(from, from, recipient, amount, "", "", false);

        return true;
    }

    /**
     * @dev See `IERC777.burn`.
     *
     * Also emits a `Transfer` event for ERC20 compatibility.
     */
    function burn(uint256 amount, bytes calldata data) external override {
        _burn(msg.sender, msg.sender, amount, data, "");
    }

    /**
     * @dev See `IERC777.isOperatorFor`.
     */
    function isOperatorFor(
        address operator,
        address tokenHolder
    ) public override view returns (bool) {
        return operator == tokenHolder ||
            _operators[tokenHolder][operator];
    }

    /**
     * @dev See `IERC777.authorizeOperator`.
     */
    function authorizeOperator(address operator) external override {
        require(msg.sender != operator, "ERC777: authorizing self as operator");

       _operators[msg.sender][operator] = true;

        emit AuthorizedOperator(operator, msg.sender);
    }

    /**
     * @dev See `IERC777.revokeOperator`.
     */
    function revokeOperator(address operator) external override {
        require(operator != msg.sender, "ERC777: revoking self as operator");

        delete _operators[msg.sender][operator];

        emit RevokedOperator(operator, msg.sender);
    }

    /**
     * @dev See `IERC777.defaultOperators`.
     */
    function defaultOperators() external override view returns (address[] memory) {
        return _defaultOperatorsArray;
    }

    /**
     * @dev See `IERC777.operatorSend`.
     *
     * Emits `Sent` and `Transfer` events.
     */
    function operatorSend(
        address sender,
        address recipient,
        uint256 amount,
        bytes calldata data,
        bytes calldata operatorData
    ) external override {
        require(isOperatorFor(msg.sender, sender), "ERC777: caller is not an operator for holder");
        _send(msg.sender, sender, recipient, amount, data, operatorData, true);
    }

    /**
     * @dev See `IERC777.operatorBurn`.
     *
     * Emits `Sent` and `Transfer` events.
     */
    function operatorBurn(address account, uint256 amount, bytes calldata data, bytes calldata operatorData) external override {
        require(isOperatorFor(msg.sender, account), "ERC777: caller is not an operator for holder");
        _burn(msg.sender, account, amount, data, operatorData);
    }

    /**
     * @dev See `IERC20.allowance`.
     *
     * Note that operator and allowance concepts are orthogonal: operators may
     * not have allowance, and accounts with allowance may not be operators
     * themselves.
     */
    function allowance(address holder, address spender) external override view returns (uint256) {
        return _allowances[holder][spender];
    }

    /**
     * @dev See `IERC20.approve`.
     *
     * Note that accounts cannot have allowance issued by their operators.
     */
    function approve(address spender, uint256 value) external override returns (bool) {
        address holder = msg.sender;
        _approve(holder, spender, value);
        return true;
    }

   /**
    * @dev See `IERC20.transferFrom`.
    *
    * Note that operator and allowance concepts are orthogonal: operators cannot
    * call `transferFrom` (unless they have allowance), and accounts with
    * allowance cannot call `operatorSend` (unless they are operators).
    *
    * Emits `Sent` and `Transfer` events.
    */
    function transferFrom(address holder, address recipient, uint256 amount) external override returns (bool) {
        return _transferFrom(holder, recipient, amount);
    }

    function _transferFrom(address holder, address recipient, uint256 amount) internal returns (bool) {
        require(recipient != address(0), "ERC777: transfer to the zero address");
        require(holder != address(0), "ERC777: transfer from the zero address");

        address spender = msg.sender;

        _callTokensToSend(spender, holder, recipient, amount, "", "");

        _move(spender, holder, recipient, amount, "", "");

        _approve(holder, spender, _allowances[holder][spender].sub(amount));

        _callTokensReceived(spender, holder, recipient, amount, "", "", false);

        return true;
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * If a send hook is registered for `raccount`, the corresponding function
     * will be called with `operator`, `data` and `operatorData`.
     *
     * See `IERC777Sender` and `IERC777Recipient`.
     *
     * Emits `Sent` and `Transfer` events.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - if `account` is a contract, it must implement the `tokensReceived`
     * interface.
     */
    function _mint(
        address operator,
        address account,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData
    )
    internal
    {
        require(account != address(0), "ERC777: mint to the zero address");

        _callTokensReceived(operator, address(0), account, amount, userData, operatorData, false);

        uint256 scaleAmount = amount.mul(DECIMAL_SCALE);
        _totalSupply = _totalSupply.add(scaleAmount);
        _addBalance(account, scaleAmount);

        emit Minted(operator, account, amount, userData, operatorData);
        emit Transfer(address(0), account, amount);
    }

    function _getBalance(address account) internal view returns (Balance memory) {
        Balance memory balance = _balances[account];

        if (balance.value == uint256(0)) {
            balance.value = 0;
            balance.exchangeRate = _exchangeRate;
        } else if (balance.exchangeRate != _exchangeRate) {
            balance.value = balance.value.mul(_exchangeRate).div(balance.exchangeRate);
            balance.exchangeRate = _exchangeRate;
        }

        return balance;
    }

    function _addBalance(address account, uint256 amount) internal {
        Balance memory balance = _getBalance(account);

        balance.value = balance.value.add(amount);

        _balances[account] = balance;
    }

    function _subBalance(address account, uint256 amount) internal {
        Balance memory balance = _getBalance(account);

        balance.value = balance.value.sub(amount);

        _balances[account] = balance;
    }

    /**
     * @dev Send tokens
     * @param operator address operator requesting the transfer
     * @param from address token holder address
     * @param to address recipient address
     * @param amount uint256 amount of tokens to transfer
     * @param userData bytes extra information provided by the token holder (if any)
     * @param operatorData bytes extra information provided by the operator (if any)
     * @param requireReceptionAck if true, contract recipients are required to implement ERC777TokensRecipient
     */
    function _send(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData,
        bool requireReceptionAck
    )
        internal
    {
        require(from != address(0), "ERC777: send from the zero address");
        require(to != address(0), "ERC777: send to the zero address");

        _callTokensToSend(operator, from, to, amount, userData, operatorData);

        _move(operator, from, to, amount, userData, operatorData);

        _callTokensReceived(operator, from, to, amount, userData, operatorData, requireReceptionAck);
    }

    /**
     * @dev Burn tokens
     * @param operator address operator requesting the operation
     * @param from address token holder address
     * @param amount uint256 amount of tokens to burn
     * @param data bytes extra information provided by the token holder
     * @param operatorData bytes extra information provided by the operator (if any)
     */
    function _burn(
        address operator,
        address from,
        uint256 amount,
        bytes memory data,
        bytes memory operatorData
    )
        internal
    {
        require(from != address(0), "ERC777: burn from the zero address");

        _callTokensToSend(operator, from, address(0), amount, data, operatorData);

        uint256 scaleAmount = amount.mul(DECIMAL_SCALE);

        _totalSupply = _totalSupply.sub(scaleAmount);
        _subBalance(from, scaleAmount);

        emit Burned(operator, from, amount, data, operatorData);
        emit Transfer(from, address(0), amount);
    }

    function _move(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData
    )
        internal
    {
        uint256 scaleAmount = amount.mul(DECIMAL_SCALE);

        _subBalance(from,scaleAmount);
        _addBalance(to,scaleAmount);

        emit Sent(operator, from, to, amount, userData, operatorData);
        emit Transfer(from, to, amount);
    }

    function _approve(address holder, address spender, uint256 value) internal {
        // TODO: restore this require statement if this function becomes internal, or is called at a new callsite. It is
        // currently unnecessary.
        //require(holder != address(0), "ERC777: approve from the zero address");
        require(spender != address(0), "ERC777: approve to the zero address");

        _allowances[holder][spender] = value;
        emit Approval(holder, spender, value);
    }

    /**
     * @dev Call from.tokensToSend() if the interface is registered
     * @param operator address operator requesting the transfer
     * @param from address token holder address
     * @param to address recipient address
     * @param amount uint256 amount of tokens to transfer
     * @param userData bytes extra information provided by the token holder (if any)
     * @param operatorData bytes extra information provided by the operator (if any)
     */
    function _callTokensToSend(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData
    )
        internal
    {
        address implementer = _erc1820.getInterfaceImplementer(from, TOKENS_SENDER_INTERFACE_HASH);
        if (implementer != address(0)) {
            IERC777Sender(implementer).tokensToSend(operator, from, to, amount, userData, operatorData);
        }
    }

    /**
     * @dev Call to.tokensReceived() if the interface is registered. Reverts if the recipient is a contract but
     * tokensReceived() was not registered for the recipient
     * @param operator address operator requesting the transfer
     * @param from address token holder address
     * @param to address recipient address
     * @param amount uint256 amount of tokens to transfer
     * @param userData bytes extra information provided by the token holder (if any)
     * @param operatorData bytes extra information provided by the operator (if any)
     * @param requireReceptionAck if true, contract recipients are required to implement ERC777TokensRecipient
     */
    function _callTokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData,
        bool requireReceptionAck
    )
        internal
    {
        address implementer = _erc1820.getInterfaceImplementer(to, TOKENS_RECIPIENT_INTERFACE_HASH);
        if (implementer != address(0)) {
            IERC777Recipient(implementer).tokensReceived(operator, from, to, amount, userData, operatorData);
        } else if (requireReceptionAck) {
            require(!to.isContract(), "ERC777: token recipient contract has no implementer for ERC777TokensRecipient");
        }
    }

    function _distributeRevenue(address account) internal returns (bool) {
        uint256 value = _getBalance(account).value;

        require(value > 0, 'Token: the revenue balance must be large than zero');
        require(_totalSupply > value, 'Token: total supply must be large than revenue');

        delete _balances[account];

        _exchangeRate = _exchangeRate.mul(_totalSupply.mul(RATE_SCALE).div(_totalSupply.sub(value))).div(RATE_SCALE);

        emit Transfer(account, address(0), value.div(DECIMAL_SCALE));
        emit RevenueDistributed(account, _exchangeRate, value.div(DECIMAL_SCALE), value.mod(DECIMAL_SCALE));

        return true;
    }

    function exchangeRate() external view returns (uint256) {
        return _exchangeRate;
    }

    event RevenueDistributed(address indexed account, uint256 exchangeRate, uint256 value, uint256 remainder);
}

library Roles {
    struct Role {
        mapping (address => bool) bearer;
    }

    /**
     * @dev Give an account access to this role.
     */
    function add(Role storage role, address account) internal {
        require(!has(role, account), "Roles: account already has role");
        role.bearer[account] = true;
    }

    /**
     * @dev Remove an account's access to this role.
     */
    function remove(Role storage role, address account) internal {
        require(has(role, account), "Roles: account does not have role");
        role.bearer[account] = false;
    }

    /**
     * @dev Check if an account has this role.
     * @return bool
     */
    function has(Role storage role, address account) internal view returns (bool) {
        require(account != address(0), "Roles: account is the zero address");
        return role.bearer[account];
    }
}

contract MinterRole is Ownable {
    using Roles for Roles.Role;

    event MinterAdded(address indexed operator, address indexed account);
    event MinterRemoved(address indexed operator, address indexed account);

    Roles.Role private _minters;

    constructor () {
        _addMinter(msg.sender);
    }

    modifier onlyMinter() {
        require(isMinter(msg.sender), "MinterRole: caller does not have the Minter role");
        _;
    }

    function isMinter(address account) public view returns (bool) {
        return _minters.has(account);
    }

    function addMinter(address account) public onlyOwner {
        _addMinter(account);
    }

    function removeMinter(address account) public onlyOwner {
        _removeMinter(account);
    }

    function _addMinter(address account) internal {
        _minters.add(account);
        emit MinterAdded(msg.sender, account);
    }

    function _removeMinter(address account) internal {
        _minters.remove(account);
        emit MinterRemoved(msg.sender, account);
    }
}


contract IMBTC is EarnERC777, MinterRole {
    address internal _revenueAddress;

    constructor(address _erc1820) EarnERC777("imBTC","The Tokenized Bitcoin", 8, _erc1820) MinterRole() {}

    function mint(address recipient, uint256 amount,
            bytes calldata userData, bytes calldata operatorData) external onlyMinter {
        super._mint(msg.sender, recipient, amount, userData, operatorData);
    }

   function setRevenueAddress(address account) external onlyOwner {
       require(_allowances[account][address(this)] > 0, "Token: the allowances of account must be large than zero");

       _revenueAddress = account;

       emit RevenueAddressSet(account);
   }

   function revenueAddress() external view returns (address) {
       return _revenueAddress;
   }

   function revenue() external view returns (uint256) {
       return _balanceOf(_revenueAddress);
   }

   event RevenueAddressSet(address indexed account);

   function distributeRevenue() external {
       require(_revenueAddress != address(0), 'Token: revenue address must not be zero');

       _distributeRevenue(_revenueAddress);
   }
}
