const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");
const { ethers, network } = require("hardhat");

const _10_STAKE_ETH = ethers.utils.parseEther("10");
const _30_STAKE_ETH = ethers.utils.parseEther("30");
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

    // rewards token
    const rewardsTokenFactory = await ethers.getContractFactory("DummyERC20", owner);
    const rewardsToken = await rewardsTokenFactory.deploy("rToken", "RT");    
    
    // staking platform
    const stakingPlatformFactory = await ethers.getContractFactory("StakingPlatform", owner);
    const stakingPlatform = await stakingPlatformFactory.deploy(weth.address, rewardsToken.address);

  

    // mint WETH tokens for user1
    await weth.connect(user1).mint({value : _52_STAKE_ETH})

    // mint rewards token for admin
    await rewardsToken.connect(owner).adminMint(_100000_STAKE_ETH, stakingPlatform.address)

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
      await stakingPlatform.connect(user1).stakeWeth(_10_STAKE_ETH)

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
      await expect(stakingPlatform.connect(user1).stakeWeth(_52_STAKE_ETH)).to.be.revertedWith("Only 50 eth or less can be staked per user");
    })

    it("User can't unstake assets", async function(){
      const { stakingPlatform, user1, weth, rewardsToken } = await loadFixture(deployOneYearLockFixture);
      // user does not have any staked assets
      await expect(stakingPlatform.connect(user1).unStakeWeth()).to.be.revertedWith("You have no staked weth");
      // stake 10 eth
      await weth.connect(user1).approve(stakingPlatform.address, _10_STAKE_ETH)
      await stakingPlatform.connect(user1).stakeWeth(_10_STAKE_ETH)
      
      // unstake right after staking before 90 days period
      await expect(stakingPlatform.connect(user1).unStakeWeth()).to.be.revertedWith("You can unstake your assets after 90 days");
    })

    it("calculate rewards tests", async function(){
      const { stakingPlatform, user1, weth, rewardsToken } = await loadFixture(deployOneYearLockFixture);
      await weth.connect(user1).approve(stakingPlatform.address, _10_STAKE_ETH)
      await stakingPlatform.connect(user1).stakeWeth(_10_STAKE_ETH);

      const _24hrs = 1 * 24 * 60 * 60;
      const _36hrs = 1 * 36 * 60 * 60;
      const _15min = 1 * 1 * 15 * 60;
      const _10sec = 10;

      // rewards amount after 24hrs staking should be ( 10 weth)
      await ethers.provider.send("evm_increaseTime", [_24hrs])
      await ethers.provider.send('evm_mine');
      let rewards = await stakingPlatform.connect(user1).calculateRewards(user1.address);
      expect(rewards).to.be.equal(ethers.utils.parseEther("10"))
      await ethers.provider.send("evm_increaseTime", [_24hrs*(-1)])
      await ethers.provider.send('evm_mine');

      // rewards amount after 36hrs staking should be ( 10.5 weth)
      await ethers.provider.send("evm_increaseTime", [_36hrs])
      await ethers.provider.send('evm_mine');
      rewards = await stakingPlatform.connect(user1).calculateRewards(user1.address);
      expect(rewards).to.be.equal(ethers.utils.parseEther("10.5"))
      await ethers.provider.send("evm_increaseTime", [_36hrs*(-1)])
      await ethers.provider.send('evm_mine');

      // rewards amount after 15min staking should be (0.010416666666666666)
      await ethers.provider.send("evm_increaseTime", [_15min])
      await ethers.provider.send('evm_mine');
      rewards = await stakingPlatform.connect(user1).calculateRewards(user1.address);
      expect(rewards).to.be.equal(ethers.utils.parseEther("0.010416666666666666"))
      await ethers.provider.send("evm_increaseTime", [_15min*(-1)])
      await ethers.provider.send('evm_mine');      

      // rewards amount after 10sec staking should be (0.010416666666666666)
      await ethers.provider.send("evm_increaseTime", [_10sec])
      await ethers.provider.send('evm_mine');
      rewards = await stakingPlatform.connect(user1).calculateRewards(user1.address);
      expect(rewards).to.be.equal(ethers.utils.parseEther("0.00011574074074074"))
    })

    it("User can stake weth multiple times unless it's below or equal 50weth", async function(){
      const { stakingPlatform, user1, weth, rewardsToken } = await loadFixture(deployOneYearLockFixture);
      await weth.connect(user1).approve(stakingPlatform.address, _42_STAKE_ETH)
      await stakingPlatform.connect(user1).stakeWeth(_10_STAKE_ETH);
      await stakingPlatform.connect(user1).stakeWeth(_10_STAKE_ETH);
      await stakingPlatform.connect(user1).stakeWeth(_10_STAKE_ETH);

      stakingStore = await stakingPlatform.stakingStore(user1.address)
      expect(stakingStore.amount).to.be.equal(_30_STAKE_ETH)

      await expect(stakingPlatform.connect(user1).stakeWeth(_30_STAKE_ETH)).to.be.revertedWith("Only 50 eth or less can be staked per user");
    })

    it("potential rewards should be calculated and stored when user stakes more than once", async function(){
      const { stakingPlatform, user1, weth, rewardsToken } = await loadFixture(deployOneYearLockFixture);
      await weth.connect(user1).approve(stakingPlatform.address, _42_STAKE_ETH)
      await stakingPlatform.connect(user1).stakeWeth(_10_STAKE_ETH);
      // wait 1 day - rewards 10 tokens
      const _24hrs = 1 * 24 * 60 * 60;
      await ethers.provider.send("evm_increaseTime", [_24hrs])
      await ethers.provider.send('evm_mine');
      await stakingPlatform.connect(user1).stakeWeth(_10_STAKE_ETH);

      // 20 weth staked total, but available rewards after 24hrs only ~10weth
      let rewards = await stakingPlatform.connect(user1).calculateRewards(user1.address);
      expect(rewards).to.be.lessThan(ethers.utils.parseEther("10.1"))
    })

    it("user can unstake weth after 90 days", async function(){
      const { stakingPlatform, user1, weth, rewardsToken } = await loadFixture(deployOneYearLockFixture);
      await weth.connect(user1).approve(stakingPlatform.address, _42_STAKE_ETH)
      await stakingPlatform.connect(user1).stakeWeth(ethers.utils.parseEther("1"));
      
      const _91day = 91 * 24 * 60 * 60;
      await ethers.provider.send("evm_increaseTime", [_91day])
      await ethers.provider.send('evm_mine');

      await stakingPlatform.connect(user1).unStakeWeth();
      // check user's weth balance
      let balance = await weth.balanceOf(user1.address)
      expect(balance).to.be.equal(_52_STAKE_ETH)

      // check user's rewards token balance
      let rewardsBalance = await rewardsToken.balanceOf(user1.address);
      expect(rewardsBalance).to.be.lessThanOrEqual(ethers.utils.parseEther("91.1"))
    })

  });

});

