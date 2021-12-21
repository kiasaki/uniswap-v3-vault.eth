## Uniswap V3 Vault

**PROTOTYPE, THIS IS NOT COMPLETE, DON'T DEPLOY IT**

_Some parts of the code wont work as intended, others just were never finished,
for example, adding liquidity to a pool in inbalanced amounts won't automatically
balance them, you'll need to do a swap beforehand for that._

### Description

This is a vault contract, conforming to ERC20, allowing users to deposit assets
that make up the underlying Uniswap V3 pool it adds liquidity to.

It will then invest all funds into a range around mid price. Rebalancing happens
periodically by the owner. At a later point, a keeper network can be employed to
have the rebalancing happen regularly, reliably and permisionlessly.

### Deploying

Make sure you configure the network you want to deploy to in the `hardhat.config.js` file first.

Run something like `npm run deploy -- --network ropsten`.

### Backstory

I saw a Gitcoin bounty asking for this, built most of it the day of, never
got an answer to my message / email :'(

So at least I'll put the code on GitHub for other people to look at and for me
to reference when building other projects.

### Other similar projects

[Visor](https://www.visor.finance/) seems like the most vocal Uni V3 vault project
out there to me.

But [Charm's Alpha Vault](https://alpha.charm.fi/) seems like the project that
put the most thought into the issue and actually has working code on it's github.
They have 2 vaults deployed at the moment w/ a 500k cap on them to avoid too much
capital being at risk while they are in alpha/beta. They also though of this cool
mechanism to reblance around a new mid price without swapping by placing the
capital in excess in a tighther (1/3 of range) single sided limit order. They
also avoid costing too much gas to investors by adding invested funds to the pool
only when rebalancing happens, not at deposit time.

### License

MIT
