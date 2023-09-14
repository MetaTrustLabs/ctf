// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./DeFiPlatform.sol";
import "./Vault.sol";

contract SetUp {

    DeFiPlatform public platfrom ;
    Vault public vault;
    address public yourAddress;

    constructor() {
        platfrom = new DeFiPlatform();
        vault = new Vault();
        platfrom.setVaultAddress(address(vault));
        vault.setPlatformAddress(address(platfrom));

		yourAddress = msg.sender;
    }

    function isSolved() public view returns(bool) {
        return vault.isSolved();
    }
}