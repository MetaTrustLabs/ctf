// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library Math {
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

library NaryaSwapLibrary {
    using SafeMath for uint;

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'NaryaSwapLibrary: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'NaryaSwapLibrary: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'NaryaSwapLibrary: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'NaryaSwapLibrary: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator).add(1);
    }
}


contract ERC20 is IERC20 {
    using SafeMath for uint;

    string public constant name = 'PWNSwap LP';
    string public constant symbol = 'PWNSwap-LP';
    uint8 public constant decimals = 18;
    uint  public override totalSupply;
    mapping(address => uint) public override balanceOf;
    mapping(address => mapping(address => uint)) public override allowance;

    constructor() {}

    function _mint(address to, uint value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Transfer(from, address(0), value);
    }

    function _approve(address owner, address spender, uint value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(address from, address to, uint value) private {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint value) external override returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) external override returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) external override returns (bool) {
        if (allowance[from][msg.sender] != type(uint).max) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }
}

contract NaryaSwapPool is ERC20 {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    address public token;
    address public factory;
    bool isSetup;

    event Sync(uint reserve0, uint reserve1);
    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'txn expired');
        _;
    }

    constructor() { }

    // for uniswap compatibility
    function token0() external pure returns (address) { return 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; }
    function token1() external view returns (address) { return token; }
    function reserve0() external view returns (uint) { return address(this).balance; }
    function reserve1() external view returns (uint) { return IERC20(token).balanceOf(address(this)); }
    function getReserves() external view returns(uint, uint, uint) {
        return (
            address(this).balance,
            IERC20(token).balanceOf(address(this)),
            block.timestamp
        );
    }
    // end

    function setup(address _token) external {
        require(!isSetup, "Already Setup");
        isSetup = true;
        token = _token;
        factory = msg.sender;
    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'ETH transfer failed');
    }

    // Swap Functions ->
    function swapExactETHForTokens(uint _tokenAmountMin, address to, uint deadline) payable external ensure(deadline) returns (uint _tokenAmount) {
        IERC20 _token_inter = IERC20(token);
        uint reserveEth = (address(this).balance).sub(msg.value);
        uint reserveToken = _token_inter.balanceOf(address(this));

        _tokenAmount = NaryaSwapLibrary.getAmountOut(msg.value, reserveEth, reserveToken);
        require(_tokenAmountMin <= _tokenAmount, "slippage issue");
        _token_inter.safeTransfer(to, _tokenAmount);

        emit Swap(msg.sender, msg.value, 0, 0, _tokenAmount, to);
        emit Sync(reserveEth.add(msg.value), reserveToken.sub(_tokenAmount));
    }

    function swapETHForExactTokens(uint _tokenAmount, address to, uint deadline) payable external ensure(deadline) returns (uint _ethAmount) {
        IERC20 _token_inter = IERC20(token);
        uint reserveEth = (address(this).balance).sub(msg.value);
        uint reserveToken = _token_inter.balanceOf(address(this));

        _ethAmount = NaryaSwapLibrary.getAmountIn(_tokenAmount, reserveEth, reserveToken);
        require(_ethAmount <= msg.value, "slippage issue");
        _token_inter.safeTransfer(to, _tokenAmount);

        if(msg.value > _ethAmount){
            safeTransferETH(msg.sender, msg.value.sub(_ethAmount));
        }

        emit Swap(msg.sender, _ethAmount, 0, 0, _tokenAmount, to);
        emit Sync(reserveEth.add(_ethAmount), reserveToken.sub(_tokenAmount));
    }

    function swapExactTokensForETH(uint _tokenAmount, uint _ethAmountMin, address to, uint deadline) external ensure(deadline) returns (uint _ethAmount) {
        IERC20 _token_inter = IERC20(token);
        uint reserveEth = address(this).balance;
        uint reserveToken = _token_inter.balanceOf(address(this));

        _ethAmount = NaryaSwapLibrary.getAmountOut(_tokenAmount, reserveToken, reserveEth);
        require(_ethAmountMin <= _ethAmount, "slippage issue");
        _token_inter.safeTransferFrom(msg.sender, address(this), _tokenAmount);
        safeTransferETH(to, _ethAmount);

        emit Swap(msg.sender, 0, _tokenAmount, _ethAmount, 0, to);
        emit Sync(reserveEth.sub(_ethAmount), reserveToken.add(_tokenAmount));
    }

    function swapTokensForExactETH(uint _ethAmount, uint _tokenAmountMax, address to, uint deadline) external ensure(deadline) returns (uint _tokenAmount) {
        IERC20 _token_inter = IERC20(token);
        uint reserveEth = address(this).balance;
        uint reserveToken = _token_inter.balanceOf(address(this));

        _tokenAmount = NaryaSwapLibrary.getAmountIn(_ethAmount, reserveToken, reserveEth);
        require(_tokenAmount <= _tokenAmountMax, "slippage issue");
        _token_inter.safeTransferFrom(msg.sender, address(this), _tokenAmount);
        safeTransferETH(to, _ethAmount);

        emit Swap(msg.sender, 0, _tokenAmount, _ethAmount, 0, to);
        emit Sync(reserveEth.sub(_ethAmount), reserveToken.add(_tokenAmount));
    }

    // add Liquidity ->
    function _addLiquidityETHinternal(uint _tokenAmountMin, uint _tokenAmountMax, address from, address to) internal returns (uint liquidity) {
        require(msg.value > 0 && _tokenAmountMin > 0, 'invalid amounts');
        uint _ethAmount = msg.value;
        IERC20 _token_inter = IERC20(token);

        uint reserveEth = (address(this).balance).sub(msg.value);
        uint reserveToken = _token_inter.balanceOf(address(this));
        uint _totalSupply = totalSupply;

        uint _tokenAmount;
        if(_totalSupply > 0){
            _tokenAmount = ( msg.value.mul( reserveToken ) ).div(reserveEth);
            require(_tokenAmount >= _tokenAmountMin, "wrong token ratio");
            require(_tokenAmount <= _tokenAmountMax, "wrong token ratio");
        }
        else {
            _tokenAmount = _tokenAmountMin;
        }

        _token_inter.safeTransferFrom(from, address(this), _tokenAmount);

        require(reserveToken == (_token_inter.balanceOf(address(this))).sub(_tokenAmount), 'deflationary tokens not supported');

        if (_totalSupply == 0) {
            liquidity = Math.sqrt(_ethAmount.mul(_tokenAmount)).sub(10**3);
           _mint(address(0), 10**3);
        } else {
            liquidity = Math.min(_ethAmount.mul(_totalSupply) / reserveEth, _tokenAmount.mul(_totalSupply) / reserveToken);
        }
        require(liquidity > 0, 'liquidity mint issue');

        uint _fee = NaryaSwapFactory(factory).fee();
        if(_fee > 0){
            uint _feeAmount = ( liquidity.mul(_fee) ).div(10**5);
            _mint(NaryaSwapFactory(factory).protocolManager(), _feeAmount);
            liquidity = liquidity.sub(_feeAmount);
        }

        _mint(to, liquidity);

        emit Mint(from, _ethAmount, _tokenAmount);
    }

    function addLiquidityETHonCreate(uint _tokenAmountMin, uint _tokenAmountMax, address from, address to, uint deadline) payable external ensure(deadline) returns (uint liquidity) {
        require(msg.sender == factory, 'dont be so smart');
        liquidity = _addLiquidityETHinternal(_tokenAmountMin, _tokenAmountMax, from, to);
    }

    function addLiquidityETH(uint _tokenAmountMin, uint _tokenAmountMax, address to, uint deadline) payable external ensure(deadline) returns (uint liquidity) {
        liquidity = _addLiquidityETHinternal(_tokenAmountMin, _tokenAmountMax, msg.sender, to);
    }

    function removeLiquidity(uint liquidity, address to, uint deadline) external ensure(deadline) returns (uint _ethAmount, uint _tokenAmount) {
        require(liquidity > 0, 'no liquidity');
        IERC20 _token_inter = IERC20(token);

        uint reserveEth = address(this).balance;
        uint reserveToken = _token_inter.balanceOf(address(this));

        uint _totalSupply = totalSupply;
        _ethAmount = liquidity.mul(reserveEth) / _totalSupply;
        _tokenAmount = liquidity.mul(reserveToken) / _totalSupply;
        require(_ethAmount > 0 && _tokenAmount > 0, 'liquidity burn issue');

        _burn(msg.sender, liquidity);

        _token_inter.safeTransfer(to, _tokenAmount);
        safeTransferETH(to, _ethAmount);

        emit Burn(msg.sender, _ethAmount, _tokenAmount, to);
    }

    function rescueTokens(address _token, address to) external {
        require(msg.sender == factory, 'dont be so smart');
        require(_token != token, "can't rescue base token");
        IERC20(_token).safeTransfer(to, IERC20(_token).balanceOf(address(this)));
    }
}

contract NaryaSwapFactory {
    uint public fee;
    address public pairCodeAddress;
    address public protocolManager;

    mapping(address => address) public getPair;
    address[] public allPairs;

    event PairCreated(address indexed token, address pair, uint);
    event protocolManagerChanged(address indexed previousManager, address indexed newManager);
    event feeUpdated(uint previousFee, uint newFee);

    modifier onlyOwner() {
        require(protocolManager == msg.sender, "no access");
        _;
    }

    constructor() {
        protocolManager = msg.sender;
        NaryaSwapPool pairContract = new NaryaSwapPool();
        pairCodeAddress = address(pairContract);
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function createPair(address token) public returns (address pair) {
        require(token != address(0), 'zero address');
        require(getPair[token] == address(0), 'pair already created');

        address payable _proxyAddress;
        bytes20 targetBytes = bytes20(pairCodeAddress);
        bytes32 salt = keccak256(abi.encodePacked(token));

        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            _proxyAddress := create2(0, clone, 0x37, salt)
        }

        pair = address(_proxyAddress);
        NaryaSwapPool(pair).setup(token);

        getPair[token] = pair;
        allPairs.push(pair);
        emit PairCreated(token, pair, allPairs.length);
    }

    function createPairWithAddLiquidityETH(address token, uint _tokenAmountMin, uint _tokenAmountMax, address to, uint deadline) payable external returns (address pair, uint liquidity) {
        pair = getPair[token];
        if(pair == address(0)){ pair = createPair(token); }
        liquidity = NaryaSwapPool(pair).addLiquidityETHonCreate{value: msg.value}(_tokenAmountMin, _tokenAmountMax, msg.sender, to, deadline);
    }

    function changeFee(uint _fee) external onlyOwner {
        require(_fee < 10000, "invalid fee");
        emit feeUpdated(fee, _fee);
        fee = _fee;
    }

    function changeProtocolManager(address _protocolManager) external onlyOwner {
        require(_protocolManager != address(0), "zero address");
        emit protocolManagerChanged(protocolManager, _protocolManager);
        protocolManager = _protocolManager;
    }

    function rescueTokens(address token, address to) external onlyOwner {
        require(token != address(0), "zero address");
        require(token != to, "to / token issue");
        require(IERC20(token).transfer(to, IERC20(token).balanceOf(address(this))), "can't process");
    }

    function rescueTokensFromPool(address pool, address token, address to) external onlyOwner {
        require(pool != address(0), "zero address");
        require(token != address(0), "zero address");
        require(token != to, "to / token issue");
        NaryaSwapPool(pool).rescueTokens(token, to);
    }
}
