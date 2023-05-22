# staking-platform
hardhat project with smart contract for staking platform. Run tests: `npm run test`

0. User needs to have available WETH tokens for staking
1. User can stake WETH(Wrapped ETH - ERC20 ETH) and max 50 WETH per person (total staked, not per transaction). And with total maximum for the contract of 10,000 ETH - including all users
2. Rewards for staking are paid in some other erc20
3. Minimum staking period is 90 days
4. User can unstake his/her tokens after 90 days hold
5. User can claim rewards without unstaking tokens
6. User can check for the rewards accumulated.
7. Calculate the rewards: each 24 hours of staking will reward the user by 1 erc20 reward token multiplied by the amount of WETH staked.
