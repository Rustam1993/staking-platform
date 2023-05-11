
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Weth.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Uncomment this line to use console.log
import "hardhat/console.sol";

contract StakingPlatform {
    
    address public owner;
    address public wethAddress;
    address public rewardsTokenAddress;
    uint public totalSupply;
    bool private reentrancyLock = false;

    // max staking per user
    uint public constant maxStakingAmountPerAddress = 50 ether;
    // max staking per contract
    uint public constant maxStakingAmountPerContract = 10000 ether;
    
    struct Stake {
        uint dateCreated;
        uint amount;
        uint dateClaimed;
    }

    modifier nonReentrant() {
        require(!reentrancyLock, "Reentrant call.");
        reentrancyLock = true;
        _;
        reentrancyLock = false;
    }

    modifier hasStakedAssets(address stakingUser) {
        require(stakingStore[stakingUser].amount > 0, "No assets present");
        _;
    }

    // store
    mapping(address => Stake) public stakingStore;
    mapping(address => uint) public readyToPayRewards;
    

    constructor(address _wethAddress, address _rewardsTokenAddress) {
        owner = msg.sender;
        wethAddress = _wethAddress;
        rewardsTokenAddress = _rewardsTokenAddress;
    }
    

    function stakeWeth(uint amountOfWeth) external nonReentrant{
        // checks
        require(
            amountOfWeth > 0,
            "Invalid amount"
        );
        require(
            totalSupply + amountOfWeth <= maxStakingAmountPerContract, 
            "Max staking amount per contract is reached"
        );
        require(
            stakingStore[msg.sender].amount + amountOfWeth <= 50 ether, 
            "Only 50 eth or less can be staked per user"
        );

        // effects
        uint dateClaimed = 0;
        uint dateCreated = block.timestamp;
        // check if user have staking assets already 
        if(stakingStore[msg.sender].amount > 0){
            require(
                block.timestamp - stakingStore[msg.sender].dateCreated < 90 days,
                "You can't stake after 90 days time period"
            );
            uint currentRewards = calculateRewards(msg.sender);
            readyToPayRewards[msg.sender] += currentRewards;
            dateClaimed = block.timestamp;
            dateCreated = stakingStore[msg.sender].dateCreated;
        }
        
        stakingStore[msg.sender].amount += amountOfWeth;
        stakingStore[msg.sender].dateCreated = dateCreated;
        stakingStore[msg.sender].dateClaimed = dateClaimed;
 
        totalSupply += amountOfWeth;

        // interactions
        IERC20(wethAddress).transferFrom(
            msg.sender, 
            address(this), 
            amountOfWeth
        );        
    }

    function unStakeWeth() external nonReentrant {
        // checks
        require(
            stakingStore[msg.sender].amount > 0, 
            "You have no staked weth"
        );

        require(
            block.timestamp - stakingStore[msg.sender].dateCreated >= 90 days, 
            "You can unstake your assets after 90 days"
        );

        // effects        
        uint rewardsToClaim = calculateRewards(msg.sender);
        uint stakingAmount = stakingStore[msg.sender].amount;
        stakingStore[msg.sender] = Stake(0,0,0);
        readyToPayRewards[msg.sender] = 0;
        totalSupply -= stakingAmount;
        // interactions
        IERC20(rewardsTokenAddress).transfer(msg.sender, rewardsToClaim);
        IERC20(wethAddress).transfer(msg.sender, stakingAmount);
    }

    function claimRewards() external nonReentrant hasStakedAssets(msg.sender){
        uint rewardsToClaim = calculateRewards(msg.sender);
        stakingStore[msg.sender].dateClaimed = block.timestamp;
        readyToPayRewards[msg.sender] = 0;
        IERC20(rewardsTokenAddress).transfer(msg.sender, rewardsToClaim);
    }

    function calculateRewards(address stakingUser) public view hasStakedAssets(stakingUser) returns (uint){
        Stake memory currentStake = stakingStore[stakingUser]; 
        uint dateToCountFrom = currentStake.dateClaimed > 0 ? currentStake.dateClaimed : currentStake.dateCreated; 
        uint stakingAmount = currentStake.amount; 
        uint rewardsForSecods;
        uint stakingSeconds = block.timestamp - dateToCountFrom; 
        uint stakedDays =  stakingSeconds / 86400;
        if(stakingSeconds - (86400 * stakedDays) != 0){
            rewardsForSecods = 1 ether * (stakingSeconds - (86400 * stakedDays)) / 86400;
        }
        uint rewards = stakingAmount * stakedDays; // 10 ether * 10**18 * 1
        return rewards + rewardsForSecods + readyToPayRewards[stakingUser];
    }
}