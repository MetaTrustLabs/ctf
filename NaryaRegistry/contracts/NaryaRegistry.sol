// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract NaryaRegistry {
    mapping(address => uint256) public records1;
    mapping(address => uint256) public records2;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public NaryaHackers;
    mapping(address => uint256) public PwnLogs;

    event FLAG(address who);

    constructor() {}

    function isNaryaHacker(address who) public view returns (bool result) {
        return (NaryaHackers[who] > 0);
    }

    function identifyNaryaHacker() public {
        if (balances[msg.sender] == 0xDA0) {
            NaryaHackers[msg.sender] = 1;
            emit FLAG(msg.sender);
        }
    }

    function register() public {
        if (balances[msg.sender] > 0) {
            return;
        }
        records1[msg.sender] = 1;
        records2[msg.sender] = 1;
        balances[msg.sender] =
            0xDA0 +
            59425114757512643212875124 -
            records1[msg.sender] -
            records2[msg.sender];
    }

    function balanceOf(address _who) public view returns (uint256 balance) {
        return balances[_who];
    }

    function pwn(uint256 _amount) public {
        address sender = msg.sender;
        require(PwnLogs[sender] == 0, "Only ONCE. No More!");
        if (
            _amount < records1[sender] ||
            _amount < records2[sender] ||
            records1[sender] + (records2[sender]) != _amount
        ) {
            return;
        }

        if (balances[sender] >= _amount) {
            records1[sender] = records2[sender];
            records2[sender] = _amount;
            (bool result, ) = sender.call(
                abi.encodeWithSignature("PwnedNoMore(uint256)", _amount)
            );
            if (result) {
                result;
            }
            balances[sender] = balances[sender] - (_amount);
        }
        PwnLogs[sender] = 1;
    }
}
