//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ObscuredHoneypot {
    mapping(address => uint256) public ledger;
    string private entryPoint;
	bytes32 private constant secretFlagHash = 0x0b49070388a7c41f42f9b15ef046fccc2ae03c244fa701f3d5ff69e22414bdc9;
    bool private drained = false;
	address private owner;
    bool private solved = false;

	modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    constructor() {
        refreshEntryPoint();
		owner = msg.sender;
    }

    function allocate() external payable {
        ledger[msg.sender] += msg.value;
    }

    function release(uint256 sum) external {
        require(ledger[msg.sender] >= sum, "Insufficient funds");

        if (keccak256(abi.encodePacked(entryPoint)) == keccak256(abi.encodePacked("I"))) {
            trigger();
        }

        ledger[msg.sender] -= sum;
        payable(msg.sender).transfer(sum);

        if (keccak256(abi.encodePacked(entryPoint)) == keccak256(abi.encodePacked("Like"))) {
            trigger();
        }
		if (address(this).balance == 0) {
            drained = true;
        }
    }

    function redeem() external {
        require(ledger[msg.sender] > 0, "No balance to claim");

        if (keccak256(abi.encodePacked(entryPoint)) == keccak256(abi.encodePacked("Goplus"))) {
            trigger();
        }

        payable(msg.sender).transfer(ledger[msg.sender]);
        ledger[msg.sender] = 0;
    }

	function verifyFlag(string memory potentialFlag) external {
        require(drained, "The honeypot hasn't been drained yet!");
        if(keccak256(abi.encodePacked(potentialFlag)) == secretFlagHash){
            solved = true;
        }
    }

    function trigger() private {
        bytes4 methodId = bytes4(keccak256("attack()"));
        assembly {
            let result := call(gas(), caller(), 0, add(methodId, 0x20), 0x04, 0, 0)
            switch result
            case 0 {
                revert(0, 0)
            }
        }
    }

    function refreshEntryPoint() private {
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty)));
        uint256 index = seed % 3;

        if (index == 0) {
            entryPoint = "I";
        } else if (index == 1) {
            entryPoint = "Like";
        } else {
            entryPoint = "Exploiting";
        }
    }

    function isSolved() public view returns(bool){
        return solved;
    }
}