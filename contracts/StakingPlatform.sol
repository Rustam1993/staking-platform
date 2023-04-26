
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
    mapping(address => uint) private withdrawnRewardsStore;
    
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
        require(totalSupply <= maxStakingAmountPerContract, "Max staking amount per contract is reached");
        require(amountOfWeth <= 50 ether, "Only 50 eth or less can be staked per user"); 
        
        IERC20(wethAddress).transferFrom(msg.sender, address(this), amountOfWeth);
                
        Stake memory newStake = Stake(block.timestamp, amountOfWeth);
        stakingStore[msg.sender] = newStake;
        totalSupply += amountOfWeth;
    }

    function unStake( address rewardsTokenAddress) external {
        require(stakingStore[msg.sender].amount > 0, "You have no staked weth");
        require(block.timestamp - stakingStore[msg.sender].dateCreated >= 90 days, "You can unstake your assets after 90 days");

        
        IERC20(wethAddress).transfer(msg.sender, stakingStore[msg.sender].amount);
        this.withdrawRewards(msg.sender, rewardsTokenAddress);
        stakingStore[msg.sender].amount = 0;
        stakingStore[msg.sender].dateCreated = 0;
        withdrawnRewardsStore[msg.sender] = 0;
    }

    function getAvailableRewardsBalance(address forAddress) external view returns (uint) {
        uint stakingDays = (block.timestamp - stakingStore[forAddress].dateCreated) / 86400;
        uint totalRewars = stakingDays * stakingStore[forAddress].amount;
        uint withdrawnRewards = withdrawnRewardsStore[forAddress];
        return totalRewars - withdrawnRewards;
    }

    function withdrawRewards(address forAddress, address rewardsTokenAddress) external {
        uint amountToWithdraw = this.getAvailableRewardsBalance(forAddress);
        if (amountToWithdraw > 0 ){
            IERC20 rewardsToken = IERC20(rewardsTokenAddress);
            rewardsToken.transfer(forAddress, amountToWithdraw);
            withdrawnRewardsStore[forAddress] += amountToWithdraw;
        }
    }

}
