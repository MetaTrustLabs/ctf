pragma solidity 0.8.17;

import "./interface/IInsurance.sol";
import "./StakingPool.sol";

contract Insurance is IInsurance {
    event ContractProtected(address indexed pool);
    event ContractSettled(address indexed pool);

    uint256 public totalContractsRegistered;
    address public operator;
    mapping(address => bool) public protectedContracts;

    modifier onlyOperator() {
      require(msg.sender == operator, "Only operator");
      _;
    }

    constructor() {
      operator = msg.sender;
    }

    receive() payable external {}

    bytes32 public constant AUTHENTIC_STAKING_POOL_CODE_HASH =
      keccak256(type(StakingPool).runtimeCode);

    function registerContract() external {
      require(!protectedContracts[msg.sender], "Already protected");

      bytes32 codeHash;
      assembly { codeHash := extcodehash(caller()) }
      require(codeHash == AUTHENTIC_STAKING_POOL_CODE_HASH, "Not authentic contract");

      require(StakingPool(payable(msg.sender)).operator() == operator, "Invalid operator");

      protectedContracts[msg.sender] = true;
      totalContractsRegistered += 1;

      emit ContractProtected(msg.sender);
    }

    function unregisterContract() external {
      require(protectedContracts[msg.sender], "Not protected");

      protectedContracts[msg.sender] = false;
      totalContractsRegistered -= 1;

      emit ContractSettled(msg.sender);
    }

    function requestCompensation(uint256 shortfall) external {
      require(protectedContracts[msg.sender], "Not protected");

      uint256 value = min(shortfall, address(this).balance);
      payable(msg.sender).call{value: value}("");
    }

    function withdraw() external onlyOperator {
      require(totalContractsRegistered == 0, "Contract registered not equal 0");
      payable(msg.sender).call{value: address(this).balance}("");
    }

    function min(uint256 a, uint256 b) private pure returns(uint256) {
        return a < b ? a : b;
    }
}
