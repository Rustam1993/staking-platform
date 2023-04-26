const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");
const { ethers, network } = require("hardhat");

const _10_STAKE_ETH = ethers.utils.parseEther("10");
const _52_STAKE_ETH = ethers.utils.parseEther("52");
const _42_STAKE_ETH = ethers.utils.parseEther("42");
const _100000_STAKE_ETH = ethers.utils.parseEther("100000");

describe("Staking platform", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployOneYearLockFixture() {
    const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
    const ONE_GWEI = 1_000_000_000;

    // Contracts are deployed using the first signer/account by default
    const [owner, user1] = await ethers.getSigners();

    // weth local deploy
    const wethFactory = await ethers.getContractFactory("WETH", owner);
    const weth = await wethFactory.deploy();    
    
    // staking platform
    const stakingPlatformFactory = await ethers.getContractFactory("StakingPlatform", owner);
    const stakingPlatform = await stakingPlatformFactory.deploy(weth.address);

    // rewards token
    const rewardsTokenFactory = await ethers.getContractFactory("DummyERC20", owner);
    const rewardsToken = await rewardsTokenFactory.deploy("rToken", "RT", _100000_STAKE_ETH, stakingPlatform.address);    

    // mint WETH tokens for user1
    await weth.connect(user1).mint({value : _52_STAKE_ETH})

    return { stakingPlatform, owner, user1, weth, rewardsToken };
  }

  describe("Deployment", function () {

    it("Should set the right owner", async function () {
      const { stakingPlatform, owner } = await loadFixture(deployOneYearLockFixture);
      expect(await stakingPlatform.owner()).to.equal(owner.address);
    });

    it("It should stake 10 ETH for user1", async function() {
      const { stakingPlatform, owner, user1, weth } = await loadFixture(deployOneYearLockFixture);
      await weth.connect(user1).approve(stakingPlatform.address, _10_STAKE_ETH)
      await stakingPlatform.connect(user1).stake(_10_STAKE_ETH)

      // check stakingStore
      let stakingStore = await stakingPlatform.stakingStore(user1.address)
      expect(stakingStore.amount).to.be.equal(_10_STAKE_ETH)

      // check weth balance of staking platform
      let balance = await weth.balanceOf(stakingPlatform.address);
      expect(balance).to.be.equal(_10_STAKE_ETH)

      // check weth user balance
      let user1WethBalance = await weth.balanceOf(user1.address)
      expect(user1WethBalance).to.be.equal(_42_STAKE_ETH)
    })

    it("User can't stake more than 50 eth", async function(){
      const { stakingPlatform, user1 } = await loadFixture(deployOneYearLockFixture);
      await expect(stakingPlatform.connect(user1).stake(_52_STAKE_ETH)).to.be.revertedWith("Only 50 eth or less can be staked per user");
    })

    it("User can't unstake assets", async function(){
      const { stakingPlatform, user1, weth, rewardsToken } = await loadFixture(deployOneYearLockFixture);
      // user does not have any staked assets
      await expect(stakingPlatform.connect(user1).unStake(rewardsToken.address)).to.be.revertedWith("You have no staked weth");
      // stake 10 eth
      await weth.connect(user1).approve(stakingPlatform.address, _10_STAKE_ETH)
      await stakingPlatform.connect(user1).stake(_10_STAKE_ETH)
      
      // unstake right after staking before 90 days period
      await expect(stakingPlatform.connect(user1).unStake(rewardsToken.address)).to.be.revertedWith("You can unstake your assets after 90 days");
    })

    it("User can unstake assets", async function(){
      const { stakingPlatform, user1, owner, weth, rewardsToken } = await loadFixture(deployOneYearLockFixture);
      await weth.connect(user1).approve(stakingPlatform.address, _10_STAKE_ETH)
      await stakingPlatform.connect(user1).stake(_10_STAKE_ETH);

      let user1WethBalance = await weth.balanceOf(user1.address)
      expect(user1WethBalance).to.be.equal(_42_STAKE_ETH)

      let stakingStore = await stakingPlatform.stakingStore(user1.address)
      expect(stakingStore.amount).to.be.equal(_10_STAKE_ETH)
      
      const _91day = 91 * 24 * 60 * 60;
      await ethers.provider.send("evm_increaseTime", [_91day])
      await ethers.provider.send('evm_mine');

      // rewards amount after 91 day of staking should be ( 910 weth)
      let rewards = await stakingPlatform.connect(user1).getAvailableRewardsBalance(user1.address);
      expect(rewards).to.be.equal(ethers.utils.parseEther("910"))

      await stakingPlatform.connect(user1).unStake(rewardsToken.address);

      stakingStore = await stakingPlatform.stakingStore(user1.address)
      expect(stakingStore.amount).to.be.equal(0)

      user1WethBalance = await weth.balanceOf(user1.address)
      expect(user1WethBalance).to.be.equal(_52_STAKE_ETH)

      // check rewards token balance for user1
      let rewardsTokenUser1Balance = await rewardsToken.balanceOf(user1.address);
      expect(rewardsTokenUser1Balance).to.be.equal(ethers.utils.parseEther("910"))
    })

  });

});

