// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract VaultLogic {

  address payable public owner;
  bytes32 private password;

  constructor(bytes32 _password) {
    owner = payable(msg.sender);
    password = _password;
  }

  function changeOwner(bytes32 _password, address payable newOwner) public {
           if (password == _password) {
        owner = newOwner;
    } 
  }

 function withdraw() external {
           if (owner == msg.sender) {
          owner.transfer(address(this).balance);
     }
  }

}

contract Vault {

  address public owner;
  VaultLogic logic;

  constructor(address _logicAddress) payable {
    logic = VaultLogic(_logicAddress);
    owner = msg.sender;
  }

  fallback() external {
    (bool result,) = address(logic).delegatecall(msg.data);
    if (result) {
      this;
    }
  }

   receive() external payable {}


}

contract SetUp {

    address public logic ;
    
    address payable public vault;


    constructor(bytes32 _password) payable{
        VaultLogic logicCon = new VaultLogic(_password);
        logic = address(logicCon);
        Vault vaultCon = new Vault(logic);
        vault = payable(address(vaultCon));
        vault.call{value: 1 ether}("");
    }

    function isSolved() public view returns(bool) {
        return vault.balance == 0;
    }
}
