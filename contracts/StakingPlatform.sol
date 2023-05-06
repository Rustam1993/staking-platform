// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Weth.sol";

// Uncomment this line to use console.log
import "hardhat/console.sol";

/*
 * Summary:
 * - Read the comments below
 * TODO:
 * - fix the issue from the comments below
 * - add checkRewardsAccumulated for users to see the amount of rewards accumulated without claiming it.
 * - add functionality to work with ETH instead of WETH (OR Both)
 * - add functionaliity to add more ETH to the stake before 90 days limit. expires
 *
 */

contract StakingPlatform {
    address public owner;
    address payable public wethAddress;
    uint public totalSupply;

    // max staking per user
    uint public constant maxStakingAmountPerAddress = 50 ether;
    // max staking per contract
    uint public constant maxStakingAmountPerContract = 10000 ether;

    /*
     * needs a separate value for dateClaimed
     * dateCreated used only to keep track of the 90 day limit
     * dateClaimed will be used to keep track of the last timestamp of rewards claimed
     */
    struct Stake {
        uint dateCreated;
        uint amount;
    }

    // store
    mapping(address => Stake) public stakingStore;
    mapping(address => uint) public withdrawnRewards;

    /*
     * This doesn't allow users to add more to the stake
     */
    modifier firstTimeStakeOnly() {
        require(
            stakingStore[msg.sender].amount == 0,
            "You already have staked WETH"
        );
        _;
    }

    /*
     * address rewardsTokenAddress should be moved to the constructor instead
     * otherwise user can pass any address and it creates a security issue
     */
    constructor(address payable _wethAddress) {
        owner = msg.sender;
        wethAddress = _wethAddress;
    }

    // user needs to have WETH to stake it
    /*
     * This doesn't allow users to add more to the stake
     */
    function stake(uint amountOfWeth) public firstTimeStakeOnly {
        // checks
        /*
         * It's a good practise to add whether inout != 0. require(amountOfWeth > 0, "");
         *
         * in the check below we don't check an actual totalSupply if transaction happens
         * so we can technically go neyond maxStakingAmountPerContract
         * (totalSupply += amountOfWeth <= maxStakingAmountPerContract, ""),
         */

        require(
            totalSupply <= maxStakingAmountPerContract,
            "Max staking amount per contract is reached"
        );
        require(
            amountOfWeth <= 50 ether,
            "Only 50 eth or less can be staked per user"
        );

        // effects
        Stake memory newStake = Stake(block.timestamp, amountOfWeth);
        stakingStore[msg.sender] = newStake;
        totalSupply += amountOfWeth;

        // intefactions
        IERC20(wethAddress).transferFrom(
            msg.sender,
            address(this),
            amountOfWeth
        );
    }

    /*
     * needs reentrancy protection
     */
    /*
     * address rewardsTokenAddress should be moved to the constructor instead
     * otherwise user can pass any address and it creates a security issue
     */
    function unStake(address rewardsTokenAddress) external {
        // checks
        require(stakingStore[msg.sender].amount > 0, "You have no staked weth");
        require(
            block.timestamp - stakingStore[msg.sender].dateCreated >= 90 days,
            "You can unstake your assets after 90 days"
        );

        // effects
        uint stakingAmount = stakingStore[msg.sender].amount;
        uint stakingDays = (block.timestamp -
            stakingStore[msg.sender].dateCreated) / 86400;
        uint rewardsToWithdraw = (stakingAmount * stakingDays) -
            withdrawnRewards[msg.sender];

        stakingStore[msg.sender] = Stake(0, 0);
        totalSupply -= stakingAmount;

        // interactions
        /*
         * These two are a potential reentrancy issue
         * the received can be a contract that will essentially call this function again
         * and the transfer will happen again, but balances won't be updated
         * because each will call be within the stack of the initial call
         */
        /*
         * Also a good practice to use any kind safeTransfer because the receiver can be a contract
         * and if it doesn't implement ERC20 interface, you won't be able to do anything with the tokens
         */
        IERC20(rewardsTokenAddress).transfer(msg.sender, rewardsToWithdraw);
        IERC20(wethAddress).transfer(msg.sender, stakingAmount);
    }

    /*
     * this function doesn't implement any checks, even if the multi stake implementation
     * within one stake period wasn't added, it's still possible to claim rewards
     * for the stake that is not in the store
     */
    /*
     * needs a separate value for dateClaimed
     * dateCreated used only to keep track of the 90 day limit
     * dateClaimed will be used to keep track of the last timestamp of rewards claimed
     */
    /*
     * address rewardsTokenAddress should be moved to the constructor instead
     * otherwise user can pass any address and it creates a security issue
     */
    function claimRewards(address rewardsTokenAddress) external {
        uint stakingAmount = stakingStore[msg.sender].amount;
        /*
         * here you could add a check if based on seconds to a rate
         * 1 day = 1 token, so it will look something like this
         * uint stakingSeconds = block.timestamp - stakingStore[msg.sender].dateClaimed;
         * // Calculate the rewards based on seconds passed
         * uint256 rewardRatePerSecond = 1 * 10**18 / 86400; // 1 token per day in seconds, considering 18 decimals
         * uint256 rewardsToClaim = stakingAmount * stakingSeconds * rewardRatePerSecond;
         * this will alloow to claim more rewards based on seconds rather than full days
         * before the 90 day limit
         *
         */
        uint stakingDays = (block.timestamp -
            stakingStore[msg.sender].dateCreated) / 86400;
        withdrawnRewards[msg.sender] += stakingAmount * stakingDays;
        /*
         * ideally here it should update the stakingStore[msg.sender].dateClaimed
         * so it's a new mini cycle if the staking started later but doesn't affect the 90 day limit
         * this also can be used for multiple staking within one 90 day period
         * by updating mapping that keeps of readyToPay rewards and resetting the dateClaimed
         * stakingStore[msg.sender].dateClaimed = block.timestamp;
         */
        IERC20(rewardsTokenAddress).transfer(
            msg.sender,
            stakingAmount * stakingDays
        );
    }
}
