
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Weth.sol";

// Uncomment this line to use console.log
import "hardhat/console.sol";

contract StakingPlatform {
    
    address public owner;
    address payable public wethAddress;
    uint public totalSupply;

    // max staking per user
    uint public constant maxStakingAmountPerAddress = 50 ether;
    // max staking per contract
    uint public constant maxStakingAmountPerContract = 10000 ether;
    
    struct Stake {
        uint dateCreated;
        uint amount;
    }

    // store
    mapping(address => Stake) public stakingStore;
    mapping(address => uint) public withdrawnRewards;
    
    modifier firstTimeStakeOnly () {
        require(stakingStore[msg.sender].amount == 0, "You already have staked WETH");
        _;
    }
    constructor(address payable _wethAddress) {
        owner = msg.sender;
        wethAddress = _wethAddress;
    }

    // user needs to have WETH to stake it
    function stake(uint amountOfWeth) public firstTimeStakeOnly  {
        // checks
        require(totalSupply <= maxStakingAmountPerContract, "Max staking amount per contract is reached");
        require(amountOfWeth <= 50 ether, "Only 50 eth or less can be staked per user"); 
        
        // effects
        Stake memory newStake = Stake(block.timestamp, amountOfWeth);
        stakingStore[msg.sender] = newStake;
        totalSupply += amountOfWeth;

        // intefactions
        IERC20(wethAddress).transferFrom(msg.sender, address(this), amountOfWeth);        
    }

    function unStake(address rewardsTokenAddress) external {
        // checks
        require(stakingStore[msg.sender].amount > 0, "You have no staked weth");
        require(block.timestamp - stakingStore[msg.sender].dateCreated >= 90 days, "You can unstake your assets after 90 days");
        
        // effects
        uint stakingAmount = stakingStore[msg.sender].amount;
        uint stakingDays = (block.timestamp - stakingStore[msg.sender].dateCreated) / 86400;
        uint rewardsToWithdraw = (stakingAmount * stakingDays) - withdrawnRewards[msg.sender];
        
        stakingStore[msg.sender] = Stake(0,0);
        totalSupply -= stakingAmount;
        
        // interactions
        IERC20(rewardsTokenAddress).transfer(msg.sender, rewardsToWithdraw);
        IERC20(wethAddress).transfer(msg.sender, stakingAmount);
    }

    function claimRewards(address rewardsTokenAddress) external {
        uint stakingAmount = stakingStore[msg.sender].amount;
        uint stakingDays = (block.timestamp - stakingStore[msg.sender].dateCreated) / 86400;
        withdrawnRewards[msg.sender] += stakingAmount * stakingDays;
        IERC20(rewardsTokenAddress).transfer(msg.sender, stakingAmount * stakingDays);
    }

}
