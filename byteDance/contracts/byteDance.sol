//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ByteDance {
    bool solved;

    constructor() {
        solved = false;
    }

    function checkCode(address _yourContract) public {
       
        require(!solved, "Challenge already solved");

        bytes memory code;
        uint256 size;
        bool hasDanceByte = false;
        assembly {
            size := extcodesize(_yourContract)
            code := mload(0x40)
            mstore(0x40, add(code, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            mstore(code, size)
            extcodecopy(_yourContract, add(code, 0x20), 0, size)
        }

        for (uint256 i = 0; i < size; i++) {
            bytes1 b = code[i];
            if (isByteDance(b)) {
                hasDanceByte = true;
            }
            require(isOddByte(b), "Byte is not odd");
        }
        require(hasDanceByte, "No palindrome byte found");

        (bool success,) = _yourContract.delegatecall("");
        require(success, "Delegatecall failed");
    }

    function isOddByte(bytes1 b) internal pure returns (bool) {
        return (uint8(b) % 2) == 1;
    }

    function isByteDance(bytes1 b) internal pure returns (bool) {

        bool isPal = true;
        assembly {
            let bVal := byte(0, b)
            for { let i := 0 } lt(i, 4) { i := add(i, 1) }
            {
                
                let bitLeft := and(shr(sub(7, i), bVal), 0x01)
                
                let bitRight := and(shr(i, bVal), 0x01)

                if iszero(eq(bitLeft, bitRight)) {
                    
                    isPal := 0
                }
            }
        }
        return isPal;
    }

    function isSolved() public view returns(bool){
        return solved;
    }

}
