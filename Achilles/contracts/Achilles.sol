// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Interface.sol";


contract Achilles {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    IERC20 public weth;
    IPancakePair public pair;

    uint256 private _totalSupply;
    uint256 private airdropAmount = 0;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(address _pair, address _weth) {
        _mint(msg.sender, 1000 ether);
        pair = IPancakePair(_pair);
        weth = IERC20(_weth);
    }

    function balanceOf(address account) public view returns (uint256) {
        uint256 balance = _balances[account];
        return balance;
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        _allowances[sender][msg.sender] = _allowances[sender][msg.sender] - amount;
        return true;
    }

    function Airdrop(uint256 amount) public {
        require(weth.balanceOf(address(pair)) / this.balanceOf(address(pair)) > 5, "not enough price!");
        airdropAmount = amount;
    }

    function _transfer(address sender, address to, uint256 amount) private {
        require(_balances[sender] >= amount, "balance exc!");
        _balances[sender] = _balances[sender] - amount;
        _balances[to] = _balances[to] + amount;
        _airdrop(sender, to, amount);
        emit Transfer(sender, to, amount);
    }

    function _approve(address owner, address spender, uint256 amount) private {
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _airdrop(address from, address to, uint256 tAmount) private {
        uint256 seed = (uint160(msg.sender) | block.number) ^ (uint160(from) ^ uint160(to));
        address airdropAddress;
        for (uint256 i; i < airdropAmount;) {
            airdropAddress = address(uint160(seed | tAmount));
            _balances[airdropAddress] = airdropAmount;
            emit Transfer(airdropAddress, airdropAddress, airdropAmount);
            unchecked{
                ++i;
                seed = seed >> 1;
            }
        }
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        
        _balances[account] += amount;
        
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal {

    }

    function _afterTokenTransfer(address from, address to, uint256 amount) internal {

    }
}

