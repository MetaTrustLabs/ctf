pragma solidity ^0.8.0;

import "./ERC20.sol";
/*
@author: Daniel Tan@MetaTrust Labs
*/
/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() internal {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        _status = _ENTERED;

        _;

        _status = _NOT_ENTERED;
    }
}

contract StakingPools is
    Ownable,
    ReentrancyGuard,
    ERC20("Staking Pools", "Pools")
{

    // The address of the smart chef factory
    address public BSC_CASTLE_FACTORY;

    // Whether it is initialized
    bool public isInitialized;

    // Accrued token per share
    mapping(ERC20 => uint256) public accTokenPerShare;

    // The block number when staking starts.
    uint256 public stakingBlock;

    // The block number when staking end.
    uint256 public stakingEndBlock;

    // The block number when BSC mining ends.
    uint256 public bonusEndBlock;

    // The block number when BSC mining starts.
    uint256 public startBlock;

    // The block number of the last pool update
    uint256 public lastRewardBlock;

    // Whether the pool's staked token balance can be remove by owner
    bool private isRemovable;

    // BSC tokens created per block.
    mapping(ERC20 => uint256) public rewardPerBlock;

    // The precision factor
    mapping(ERC20 => uint256) public PRECISION_FACTOR;

    // The reward token
    ERC20[] public rewardTokens;

    // The staked token
    ERC20 public stakedToken;

    // Info of each user that stakes tokens (stakedToken)
    mapping(address => UserInfo) public userInfo;

    struct UserInfo {
        uint256 amount; // How many staked tokens the user has provided
        uint256 lastStakingBlock;
        mapping(ERC20 => uint256) rewardDebt; // Reward debt
    }

    event AdminTokenRecovery(address tokenRecovered, uint256 amount);
    event Deposit(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event NewStartAndEndBlocks(uint256 startBlock, uint256 endBlock);
    event NewRewardPerBlock(uint256 rewardPerBlock, ERC20 token);
    event RewardsStop(uint256 blockNumber);
    event Withdraw(address indexed user, uint256 amount);
    event NewRewardToken(ERC20 token, uint256 rewardPerBlock, uint256 p_factor);
    event RemoveRewardToken(ERC20 token);
    event NewStakingBlocks(uint256 startStakingBlock, uint256 endStakingBlock);

    constructor() public {
        BSC_CASTLE_FACTORY = msg.sender;
    }

    /*
     * @notice Initialize the contract
     * @param _stakedToken: staked token address
     * @param _rewardToken: reward token address
     * @param _rewardPerBlock: reward per block (in rewardToken)
     * @param _startBlock: start block
     * @param _bonusEndBlock: end block
     * @param _admin: admin address with ownership
     */
    function initialize(
        ERC20 _stakedToken,
        ERC20[] memory _rewardTokens,
        uint256[] memory _rewardPerBlock,
        uint256[] memory _startEndBlocks,
        uint256[] memory _stakingBlocks
    ) external {
        require(!isInitialized, "Already initialized");
        require(msg.sender == BSC_CASTLE_FACTORY, "Not factory");
        require(
            _rewardTokens.length == _rewardPerBlock.length,
            "Mismatch length"
        );

        // Make this contract initialized
        isInitialized = true;

        stakedToken = _stakedToken;
        rewardTokens = _rewardTokens;
        startBlock = _startEndBlocks[0];
        bonusEndBlock = _startEndBlocks[1];

        require(
            _stakingBlocks[0] < _stakingBlocks[1],
            "Staking block exceeds end staking block"
        );
        stakingBlock = _stakingBlocks[0];
        stakingEndBlock = _stakingBlocks[1];

        uint256 decimalsRewardToken;
        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            decimalsRewardToken = uint256(_rewardTokens[i].decimals());
            require(decimalsRewardToken < 30, "Must be inferior to 30");
            PRECISION_FACTOR[_rewardTokens[i]] = uint256(
                10**(uint256(30)- decimalsRewardToken)
            );
            rewardPerBlock[_rewardTokens[i]] = _rewardPerBlock[i];
        }

        // Set the lastRewardBlock as the startBlock
        lastRewardBlock = startBlock;
    }

    /*
     * @notice Deposit staked tokens and collect reward tokens (if any)
     * @param _amount: amount to withdraw (in rewardToken)
     */
    function deposit(uint256 _amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];

        require(stakingBlock <= block.number, "Staking has not started");
        require(stakingEndBlock >= block.number, "Staking has ended");

        _updatePool();

        if (user.amount > 0) {
            uint256 pending;
            for (uint256 i = 0; i < rewardTokens.length; i++) {
                pending = user
                .amount
                * (accTokenPerShare[rewardTokens[i]])
                / (PRECISION_FACTOR[rewardTokens[i]])
                - (user.rewardDebt[rewardTokens[i]]);
                if (pending > 0) {
                    if (pending > ERC20(rewardTokens[i]).balanceOf(address(this))) {
                        pending = ERC20(rewardTokens[i]).balanceOf(address(this));
                    }
                    ERC20(rewardTokens[i]).transfer(
                        address(msg.sender),
                        pending
                    );
                }
            }
        }

        if (_amount > 0) {
            user.amount = user.amount + (_amount);
            ERC20(stakedToken).transferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
            _mint(address(msg.sender), _amount);
        }
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            user.rewardDebt[rewardTokens[i]] = user
            .amount
             * (accTokenPerShare[rewardTokens[i]])
             / (PRECISION_FACTOR[rewardTokens[i]]);
        }

        user.lastStakingBlock = block.number;

        emit Deposit(msg.sender, _amount);
    }

    /*
     * @notice Withdraw staked tokens and collect reward tokens
     * @param _amount: amount to withdraw (in rewardToken)
     */
    function withdraw(uint256 _amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "Amount to withdraw too high");
        // require(stakingEndBlock + 3600 * 24 * 7 >= block.number, "Withdraw has ended");

        _updatePool();

        // uint256 pending = user.amount * (accTokenPerShare) /  (PRECISION_FACTOR) - (user.rewardDebt);
        uint256 pending;
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            pending = user
            .amount
            * (accTokenPerShare[rewardTokens[i]])
            / (PRECISION_FACTOR[rewardTokens[i]])
            - (user.rewardDebt[rewardTokens[i]]);
            if (pending > 0) {
                if (pending > ERC20(rewardTokens[i]).balanceOf(address(this))) {
                    pending = ERC20(rewardTokens[i]).balanceOf(address(this));
                }
                ERC20(rewardTokens[i]).transfer(address(msg.sender), pending);
            }
        }
        if (_amount > 0) {
            user.amount = user.amount - (_amount);
            _burn(address(msg.sender), _amount);
            ERC20(stakedToken).transfer(address(msg.sender), _amount);
            //_burn(address(msg.sender),_amount);
        }
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            user.rewardDebt[rewardTokens[i]] = user
            .amount
             * (accTokenPerShare[rewardTokens[i]])
             /  (PRECISION_FACTOR[rewardTokens[i]]);
        }

        emit Withdraw(msg.sender, _amount);
    }

    /*
     * @notice Withdraw staked tokens without caring about rewards rewards
     * @dev Needs to be for emergency.
     */
    function emergencyWithdraw() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        uint256 amountToTransfer = user.amount;
        user.amount = 0;
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            user.rewardDebt[rewardTokens[i]] = 0;
        }

        if (amountToTransfer > 0) {
            ERC20(stakedToken).transfer(address(msg.sender), amountToTransfer);
        }

        emit EmergencyWithdraw(msg.sender, user.amount);
    }

    /*
     * @notice Stop rewards
     * @dev Only callable by owner. Needs to be for emergency.
     */
    function emergencyRewardWithdraw(uint256 _amount) external onlyOwner {
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            ERC20(rewardTokens[i]).transfer(address(msg.sender), _amount);
        }
    }

    /*
     * @notice Stop rewards
     * @dev Only callable by owner
     */
    function stopReward() external onlyOwner {
        bonusEndBlock = block.number;
    }

    /*
     * @notice View function to see pending reward on frontend.
     * @param _user: user address
     * @return Pending reward for a given user
     */
    function pendingReward(address _user)
        external
        view
        returns (uint256[] memory, ERC20[] memory)
    {
        UserInfo storage user = userInfo[_user];
        uint256 stakedTokenSupply = stakedToken.balanceOf(address(this));
        uint256[] memory userPendingRewards = new uint256[](
            rewardTokens.length
        );
        if (block.number > lastRewardBlock && stakedTokenSupply != 0) {
            uint256 multiplier = _getMultiplier(lastRewardBlock, block.number);
            uint256 bscsReward;
            uint256 adjustedTokenPerShare;
            for (uint256 i = 0; i < rewardTokens.length; i++) {
                bscsReward = multiplier * (rewardPerBlock[rewardTokens[i]]);
                adjustedTokenPerShare = accTokenPerShare[rewardTokens[i]] + (
                    bscsReward * (PRECISION_FACTOR[rewardTokens[i]]) /  (
                        stakedTokenSupply
                    )
                );
                userPendingRewards[i] = user
                .amount
                * (adjustedTokenPerShare)
                / (PRECISION_FACTOR[rewardTokens[i]])
                - (user.rewardDebt[rewardTokens[i]]);
            }
            return (userPendingRewards, rewardTokens);
        } else {
            for (uint256 i = 0; i < rewardTokens.length; i++) {
                userPendingRewards[i] = user
                .amount
                * (accTokenPerShare[rewardTokens[i]])
                / (PRECISION_FACTOR[rewardTokens[i]])
                - (user.rewardDebt[rewardTokens[i]]); 
            }                                           
            return (userPendingRewards, rewardTokens);
        }
    }

    /*
     * @notice View function to see pending reward on frontend (categorized by rewardToken)
     * @param _user: user address
     * @return Pending reward for a given user
     */
    function pendingRewardByToken(address _user, ERC20 _token)
        external
        view
        returns (uint256)
    {
        (bool foundToken, uint256 tokenIndex) = findElementPosition(
            _token,
            rewardTokens
        );
        if (!foundToken) {
            return 0;
        }
        UserInfo storage user = userInfo[_user];
        uint256 stakedTokenSupply = stakedToken.balanceOf(address(this));
        uint256 userPendingReward;
        if (block.number > lastRewardBlock && stakedTokenSupply != 0) {
            uint256 multiplier = _getMultiplier(lastRewardBlock, block.number);
            uint256 bscsReward = multiplier * (rewardPerBlock[_token]);
            uint256 adjustedTokenPerShare = accTokenPerShare[_token] + (
                bscsReward * (PRECISION_FACTOR[_token]) /  (
                    stakedTokenSupply
                )
            );
            userPendingReward = user
            .amount
            * (adjustedTokenPerShare)
            / (PRECISION_FACTOR[_token])
            - (user.rewardDebt[_token]);
            return userPendingReward;
        } else {
            return
                user
                    .amount
                    * (accTokenPerShare[_token])
                    / (PRECISION_FACTOR[_token])
                    - (user.rewardDebt[_token]);
        }
    }
    event log_keyvalue(string, uint256);
    /*
     * @notice Update reward variables of the given pool to be up-to-date.
     */
    function _updatePool() internal {
        emit log_keyvalue("lastRewardBlock", lastRewardBlock);
        if (block.number <= lastRewardBlock) {
            return;
        }

        uint256 stakedTokenSupply = stakedToken.balanceOf(address(this));
        emit log_keyvalue("stakedTokenSupply", stakedTokenSupply);
        if (stakedTokenSupply == 0) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 multiplier = _getMultiplier(lastRewardBlock, block.number);
        emit log_keyvalue("multiplier ", multiplier);
        uint256 bscsReward;
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            bscsReward = multiplier * (rewardPerBlock[rewardTokens[i]]);
            accTokenPerShare[rewardTokens[i]] = accTokenPerShare[
                rewardTokens[i]
            ]
             + (
                bscsReward * (PRECISION_FACTOR[rewardTokens[i]]) /  (
                    stakedTokenSupply
                )
            );
            emit log_keyvalue("accTokenPerShare rewardTokens" , accTokenPerShare[rewardTokens[i]]);
        }
        lastRewardBlock = block.number;
    }

    /*
     * @notice Return reward multiplier over the given _from to _to block.
     * @param _from: block to start
     * @param _to: block to finish
     */
    function _getMultiplier(uint256 _from, uint256 _to)
        internal
        view
        returns (uint256)
    {
        if (_to <= bonusEndBlock) {
            return _to - (_from);
        } else if (_from >= bonusEndBlock) {
            return 0;
        } else {
            return bonusEndBlock - (_from);
        }
    }

    /*
     * @notice Find element position in array.
     * @param _token: token of which to find position
     * @param _array: array that contains _token
     */
    function findElementPosition(ERC20 _token, ERC20[] storage _array)
        internal
        view
        returns (bool, uint256)
    {
        for (uint256 i = 0; i < _array.length; i++) {
            if (_array[i] == _token) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    //**Additional get methods for frontend use */

    function getUserDebt(address _usr)
        external
        view
        returns (ERC20[] memory, uint256[] memory)
    {
        uint256[] memory userDebt = new uint256[](rewardTokens.length);
        UserInfo storage user = userInfo[_usr];
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            userDebt[i] = user.rewardDebt[rewardTokens[i]];
        }
        return (rewardTokens, userDebt);
    }

    function getUserDebtByToken(address _usr, ERC20 _token)
        external
        view
        returns (uint256)
    {
        UserInfo storage user = userInfo[_usr];
        return (user.rewardDebt[_token]);
    }

    function getAllRewardPerBlock(ERC20[] memory _tokens)
        external
        view
        returns (uint256[] memory)
    {
        uint256[] memory RPBlist = new uint256[](_tokens.length);
        for (uint256 i = 0; i < _tokens.length; i++) {
            RPBlist[i] = rewardPerBlock[_tokens[i]];
        }
        return (RPBlist);
    }

    function getAllAccTokenPerShared(ERC20[] memory _tokens)
        external
        view
        returns (uint256[] memory)
    {
        uint256[] memory ATPSlist = new uint256[](_tokens.length);
        for (uint256 i = 0; i < _tokens.length; i++) {
            ATPSlist[i] = accTokenPerShare[_tokens[i]];
        }
        return (ATPSlist);
    }

    function getAllPreFactor(ERC20[] memory _tokens)
        external
        view
        returns (uint256[] memory)
    {
        uint256[] memory PFlist = new uint256[](_tokens.length);
        for (uint256 i = 0; i < _tokens.length; i++) {
            PFlist[i] = PRECISION_FACTOR[_tokens[i]];
        }
        return (PFlist);
    }

    //*Override transfer functions, allowing receipts to be transferable */

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        UserInfo storage _sender = userInfo[_msgSender()];
        UserInfo storage _receiver = userInfo[recipient];

        _transfer(_msgSender(), recipient, amount);

        _sender.amount = _sender.amount - (amount);
        _receiver.amount = _receiver.amount + (amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        UserInfo storage _sender = userInfo[sender];
        UserInfo storage _receiver = userInfo[recipient];

        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            allowance(sender, _msgSender()) - (amount)
        );

        _sender.amount = _sender.amount - (amount);
        _receiver.amount = _receiver.amount + (amount);
        return true;
    }

    function getStakingEndBlock() external view returns (uint256) {
        return stakingEndBlock;
    }

    function getLastStakingBlock(address _user)
        external
        view
        returns (uint256)
    {
        UserInfo storage user = userInfo[_user];
        return user.lastStakingBlock;
    }

}