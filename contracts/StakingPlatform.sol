
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Weth.sol";

// Uncomment this line to use console.log
import "hardhat/console.sol";

contract StakingPlatform {
    
    address public owner;
    address public rewardsTokenAddress;
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
    constructor(address payable _wethAddress, address _rewardsTokenAddress) {
        owner = msg.sender;
        rewardsTokenAddress = _rewardsTokenAddress;
        wethAddress = _wethAddress;
    }

    function stake() public firstTimeStakeOnly payable {
        
        require(totalSupply <= maxStakingAmountPerContract, "Max staking amount per contract is reached");
        require(msg.value <= 50 ether, "Only 50 weth or less can be staked per user"); 
        
        (bool success, ) = wethAddress.call{value: msg.value}(abi.encodeWithSignature("deposit()"));
        require(success, "Failed to deposit weth");
                
        stakingStore[msg.sender].dateCreated = block.timestamp;
        stakingStore[msg.sender].amount += msg.value;
        totalSupply += msg.value;
    }

    function getAvailableRewardsBalance() external view returns (uint) {
        uint stakingDays = (block.timestamp - stakingStore[msg.sender].dateCreated) / 86400;
        uint totalRewars = stakingDays * stakingStore[msg.sender].amount;
        uint withdrawnRewards = withdrawnRewardsStore[msg.sender];
        return totalRewars - withdrawnRewards;
    }

    function withdrawRewards() external {
        uint amountToWithdraw = this.getAvailableRewardsBalance();
        require(amountToWithdraw > 0, "You have no available rewards");

        IERC20 rewardsToken = IERC20(rewardsTokenAddress);
        require(rewardsToken.balanceOf(address(this)) >= amountToWithdraw);
        rewardsToken.transfer(msg.sender, amountToWithdraw);
        withdrawnRewardsStore[msg.sender] += amountToWithdraw;
    }

    function unStake() external {
        require(stakingStore[msg.sender].amount > 0, "You have no staked weth");
        require(block.timestamp - stakingStore[msg.sender].dateCreated >= 90 days, "You can unstake your assets after 90 days");

        WETH9 weth = WETH9(wethAddress);
        weth.withdraw(stakingStore[msg.sender].amount);
        stakingStore[msg.sender].amount = 0;
        stakingStore[msg.sender].dateCreated = 0;
    }

}
