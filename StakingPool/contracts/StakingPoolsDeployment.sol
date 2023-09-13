// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./StakingPools_MT.sol";
import "./ERC20V2.sol";

contract StakingPoolsDeployment {
    StakingPools public stakingPools;
    ERC20 public stakedToken;
    ERC20 public rewardToken;
    ERC20V2 public rewardToken2;
    ERC20[] public rewardTokens;

    constructor() {
        stakingPools = new StakingPools();

        stakedToken = new ERC20("staked Token", "sToken");
        rewardToken = new ERC20("reward Token 1", "r1Token");
        rewardToken2 = new ERC20V2("reward Token 2", "r1Token");
        rewardTokens = new ERC20[](2);
        rewardTokens[0] = rewardToken;
        rewardTokens[1] = ERC20(rewardToken2);
        uint256[] memory rewardPerBlock = new uint256[](2);
        rewardPerBlock[0] = 100000e18;                       
        rewardPerBlock[1] = 100000e18;
        uint256[] memory startEndBlocks = new uint256[](2);
        startEndBlocks[0] = block.number;
        startEndBlocks[1] = block.number + 60;    //bounus lasts 60 blocks
        uint256[] memory stakingBlock = new uint256[](2);
        stakingBlock[0] = block.number;
        stakingBlock[1] = block.number + 60;      //staking lasts 60 blocks
        
        //The max reward for all users should be 10000e18 * 60 = 60000 * 1e18
        stakingPools.initialize(stakedToken, rewardTokens, rewardPerBlock, startEndBlocks, stakingBlock);

        //The pool has and only has 1e8 * 1e18 reward token, which is greater than 60000 * 1e18
        rewardToken.mint(address(stakingPools), 1e8 * 1e18);
        rewardToken2.mint(address(stakingPools), 1e8 * 1e18);
    }

    function faucet() external {
        stakedToken.mint(msg.sender, 100000e18);
    }

    function stageA() public view returns(bool) {
        return rewardTokens[0].balanceOf(msg.sender) == 1e8 * 1e18;
    }
    
    function stageB() public view returns(bool) {
        return rewardTokens[1].balanceOf(msg.sender) > 16 * 1e8 * 1e18;
    }

    function isSolved() public view returns(bool) {
        return stageA() && stageB();
    }
}
