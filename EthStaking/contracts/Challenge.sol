pragma solidity 0.8.17;

import "./StakingPool.sol";
import "./Insurance.sol";


contract Challenge {
  StakingPool public pool;
  Insurance public insurance;

  constructor() payable {
    require(msg.value == 10 ether);

    insurance = new Insurance();
    pool = new StakingPool(msg.sender, address(insurance));
    payable(insurance).call{value: msg.value}("");
  }

  function isSolved() external view returns(bool){
    require(address(insurance).balance == 0, "Not solved");
    return true;
  }
}
