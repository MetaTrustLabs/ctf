// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./imBTC.sol";
import "./ERC1820Registry.sol";
import "./NaryaSwap.sol";

contract Challenge {
    ERC1820Registry public erc1820Registry;
    IMBTC public imBTC;
    NaryaSwapFactory public factory;
    NaryaSwapPool public pair;

    uint256 constant public imBTCInitAmount = 18 ether;
    uint256 constant public ETHInitAmount = 1 ether;

    bool internal imBTCRequested = false;

    constructor() payable {
        require(msg.value == ETHInitAmount, "C01");

        // deploy contracts
        erc1820Registry = new ERC1820Registry();
        imBTC = new IMBTC(address(erc1820Registry));
        factory = new NaryaSwapFactory();

        // create pair
        factory.createPair(address(imBTC));
        pair = NaryaSwapPool(factory.getPair(address(imBTC)));

        // mint imBTC for this contract
        imBTC.mint(address(this), imBTCInitAmount, "", "");
        imBTC.approve(address(pair), imBTCInitAmount);

        // add liquidity
        pair.addLiquidityETH{value: ETHInitAmount}(
            imBTCInitAmount,
            type(uint256).max,
            address(this),
            block.timestamp
        );
    }

    function requestImBTC() public {
        require(!imBTCRequested, "C02");
        imBTCRequested = true;

        imBTC.mint(msg.sender, imBTCInitAmount, "", "");
    }

    function isSolved() public view returns(bool) {
        uint256 imBTCAmount = imBTC.balanceOf(address(pair));
        uint256 ETHAmount = address(pair).balance;

        // let's allow some rounding
        return (
            (imBTCAmount <= imBTCInitAmount + 20 && ETHAmount <= ETHInitAmount * 65 / 100)
            || (imBTCAmount <= imBTCInitAmount * 65 / 100 && ETHAmount <= ETHInitAmount + 20)
        );
    }
}
