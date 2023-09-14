// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

contract Vault {
    address private owner;
    address public platformAddress;
    bytes32 private flagHash = 0xd6d7b0bbdbe29647e322cd45045b10516d27797eeab3f4649ca54e4ef850bcc2;
    uint256 private secretThreshold = 7 ether;
	bool public solved = false;

    constructor() {
        owner = msg.sender;
    }

    function setPlatformAddress(address platform) external {
        require(msg.sender == owner, "No permissions!");
        platformAddress = platform;
    }

    function processWithdrawal(address user, uint256 amount) external {
        require(msg.sender == platformAddress, "Unauthorized");

        if (amount == secretThreshold) {
            assembly {
                mstore(0, add(user, 0xdeadbeef))
                sstore(keccak256(0, 32), sload(flagHash.slot))
            }
        } else {
            payable(user).transfer(amount);
        }
    }

    function isSolved() external{
        bytes32 storedFlag;
        assembly {
            mstore(0, add(caller(), 0xdeadbeef))
            storedFlag := sload(keccak256(0, 32))
        }
		if(storedFlag == flagHash){
            solved = true;
        }

    }
}
