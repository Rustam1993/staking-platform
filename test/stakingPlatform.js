const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");
const { ethers, network } = require("hardhat");

const _10_STAKE_ETH = ethers.utils.parseEther("10");
const _20_STAKE_ETH = ethers.utils.parseEther("20");
const _50_STAKE_ETH = ethers.utils.parseEther("50");
const _10000_STAKE_ETH = ethers.utils.parseEther("10000"); 

describe("Staking platform", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployOneYearLockFixture() {
    const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
    const ONE_GWEI = 1_000_000_000;

    // Contracts are deployed using the first signer/account by default
    const [owner, user1] = await ethers.getSigners();

    // rewards token
    const rewardsTokenFactory = await ethers.getContractFactory("DummyERC20", owner);
    const rewardsToken = await rewardsTokenFactory.deploy("rToken", "RT", ethers.constants.MaxUint256);

    // weth local deploy
    const wethFactory = await ethers.getContractFactory("WETH9", owner);
    const weth = await wethFactory.deploy();    
    
    // staking platform 
    const stakingPlatformFactory = await ethers.getContractFactory("StakingPlatform", owner);
    const stakingPlatform = await stakingPlatformFactory.deploy(weth.address, rewardsToken.address);

    return { stakingPlatform, owner, user1, weth, rewardsToken };
  }

  describe("Deployment", function () {

    it("Should set the right owner", async function () {
      const { stakingPlatform, owner } = await loadFixture(deployOneYearLockFixture);
      expect(await stakingPlatform.owner()).to.equal(owner.address);
    });

    it("It should stake 10 ETH for user1", async function() {
      const { stakingPlatform, owner, user1, weth } = await loadFixture(deployOneYearLockFixture);
      await stakingPlatform.connect(user1).stake({value: _10_STAKE_ETH})
      // check stakingStore
      let stakingStore = await stakingPlatform.connect(owner).stakingStore(user1.address)
      expect(stakingStore.totalAmount).to.be.equal(_10_STAKE_ETH)

      // check weth smart contract balance
      let wethBalance = await weth.connect(owner).totalSupply();
      expect(wethBalance).to.be.equal(_10_STAKE_ETH)

      // stake another 10 ETH 2 days later and calculate rewards
      const twoDays = 2 * 24 * 60 * 60;
  
      await network.provider.send("evm_increaseTime", [twoDays])

      await stakingPlatform.connect(user1).stake({value: _10_STAKE_ETH})
      stakingStore = await stakingPlatform.connect(owner).stakingStore(user1.address)
      expect(stakingStore.totalAmount).to.be.equal(_20_STAKE_ETH)

      // check weth smart contract balance
      wethBalance = await weth.connect(owner).totalSupply();
      expect(wethBalance).to.be.equal(_20_STAKE_ETH)      

      
      // User1 should have rewardsToken Stored in staking platform contract; 20
      const rewardsAmountForUser1 = await stakingPlatform.connect(owner).rewardsStore(user1.address)
      expect(rewardsAmountForUser1).to.be.equal(_20_STAKE_ETH)
    })

    it("User can't stake more than 50 eth", async function(){
      const { stakingPlatform, owner, user1 } = await loadFixture(deployOneYearLockFixture);
      await stakingPlatform.connect(user1).stake({value: _50_STAKE_ETH})

      // stake another 10 eth
      await expect(stakingPlatform.connect(user1).stake({ value: _10_STAKE_ETH })).to.be.revertedWith("Max staking amount per user is reached");
    })

    it("Staking platform can only have 10.000 ETH max", async function(){
      const { stakingPlatform, owner, user1 } = await loadFixture(deployOneYearLockFixture);
      await stakingPlatform.connect(user1).stake({value: _10000_STAKE_ETH})
      await expect(stakingPlatform.connect(user1).stake({ value: _10_STAKE_ETH })).to.be.revertedWith("Max staking amount per contract is reached");
    })

  });

});

