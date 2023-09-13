// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract Foo {
    address who;
    mapping (uint256 => mapping (address => bool)) stats;

    constructor() {}
    
    function setup() external {
        require(uint256(uint160(msg.sender)) % 1000 == 137, "!good caller");
        who = msg.sender;
    }

    function stage1() external {
        require(msg.sender == who, "stage1: !setup");
        stats[1][msg.sender] = true;

        (, bytes memory data) = msg.sender.staticcall(abi.encodeWithSignature("check()"));
        require(abi.decode(data, (bytes32)) == keccak256(abi.encodePacked("1337")), "stage1: !check");

        (, data) = msg.sender.staticcall(abi.encodeWithSignature("check()"));
        require(abi.decode(data, (bytes32)) == keccak256(abi.encodePacked("13337")), "stage1: !check2");
    } 

    function stage2() external {
        require(stats[1][msg.sender], "goto stage1");
        stats[2][msg.sender] = true;
        require(this._stage2() == 7, "!stage2");
    }

    function _stage2() external payable returns (uint x) {
        unchecked {
            x = 1;
            try this._stage2() returns (uint x_) {
                x += x_;
            } catch {}
        }
    }

    function stage3() external {
        require(stats[2][msg.sender], "goto stage2");
        stats[3][msg.sender] = true;
        uint[] memory challenge = new uint[](8);

        challenge[0] = (block.timestamp & 0xf0000000) >> 28;
        challenge[1] = (block.timestamp & 0xf000000) >> 24;
        challenge[2] = (block.timestamp & 0xf00000) >> 20;
        challenge[3] = (block.timestamp & 0xf0000) >> 16;
        challenge[4] = (block.timestamp & 0xf000) >> 12;
        challenge[5] = (block.timestamp & 0xf00) >> 8;
        challenge[6] = (block.timestamp & 0xf0) >> 4;
        challenge[7] = (block.timestamp & 0xf) >> 0;

        /* can you sort it for me? */
        (, bytes memory data) = msg.sender.staticcall{gas: 3_888}(abi.encodeWithSignature("sort(uint256[])", challenge));
        uint[] memory answer = abi.decode(data, (uint[]));

        /* bubble sort */
        for(uint i=0 ; i<8 ; i++) {
            for(uint j=i+1 ; j<8 ; j++) {
                if (challenge[i] > challenge[j]) {
                    uint tmp = challenge[i];
                    challenge[i] = challenge[j];
                    challenge[j] = tmp;
                }
            }
        }

        /* check answer */
        for(uint i=0 ; i<8 ; i++) {
            require(challenge[i] == answer[i], "stage3: !sort");
        }
    }

    function stage4() external {
        require(stats[3][msg.sender], "goto stage3");
        (, bytes memory data) = msg.sender.staticcall(abi.encodeWithSignature("pos()"));
        bytes32 pos = abi.decode(data, (bytes32));
        assembly {
            sstore(pos, 0x1)
        }
    }

    function isSolved() external view returns (bool) {
        return stats[4][who];
    }
}
