# Decentralized Stablecoin (DSC)

A decentralized, algorithmic stablecoin system built with Foundry. Similar to DAI but with no governance, no fees, and only backed by WETH and WBTC.

## About

This project implements a stablecoin with the following properties:

1. **Relative Stability**: Anchored/Pegged to $1.00 USD
   - Uses Chainlink Price Feeds for accurate pricing
   - Exchange ETH & BTC for stablecoin at $1.00

2. **Stability Mechanism**: Algorithmic (Decentralized)
   - Users can only mint stablecoins by providing sufficient collateral
   - 200% overcollateralization ratio required

3. **Collateral**: Exogenous (Crypto)
   - wETH (Wrapped Ether)
   - wBTC (Wrapped Bitcoin)

## Contracts

| Contract | Description |
|----------|-------------|
| `DSCEngine.sol` | Core engine handling collateral deposits, minting, redemption, and liquidation |
| `DecentralizedStableCoin.sol` | ERC20 stablecoin token controlled by DSCEngine |
| `OracleLib.sol` | Library for Chainlink price feed staleness checks |

## Getting Started

### Requirements

- [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- [Foundry](https://getfoundry.sh/)

### Installation

```bash
git clone https://github.com/SymmaTe/foundry-defi-stablecoin-f23.git
cd foundry-defi-stablecoin-f23
make install
```

### Build

```bash
make build
```

### Test

```bash
make test
```

### Deploy

```bash
# Local (Anvil)
make deployDSC

# Sepolia
make deployDSC ARGS="--network sepolia"

# Mainnet
make deployDSC ARGS="--network mainnet"
```

## Usage

### Deposit Collateral & Mint DSC

```solidity
// 1. Approve collateral token
IERC20(weth).approve(address(dscEngine), amount);

// 2. Deposit collateral and mint DSC in one transaction
dscEngine.depositCollateralAndMintDSC(weth, collateralAmount, dscToMint);
```

### Redeem Collateral & Burn DSC

```solidity
// 1. Approve DSC for burning
dsc.approve(address(dscEngine), dscAmount);

// 2. Burn DSC and redeem collateral
dscEngine.redeemCollateralForDSC(weth, collateralAmount, dscToBurn);
```

### Liquidation

If a user's health factor falls below 1, they can be liquidated:

```solidity
// Liquidator covers debt and receives collateral + 10% bonus
dscEngine.liquidate(weth, userToLiquidate, debtToCover);
```

## Key Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| Liquidation Threshold | 50% | Must maintain 200% collateralization |
| Liquidation Bonus | 10% | Bonus for liquidators |
| Min Health Factor | 1e18 | Health factor must stay above 1 |
| Oracle Timeout | 3 hours | Price feed staleness threshold |

## Deployments

### Sepolia Testnet

| Contract | Address |
|----------|---------|
| DecentralizedStableCoin | [`0x759F0c0694950324A1B305F1D719d56B24747a0D`](https://sepolia.etherscan.io/address/0x759F0c0694950324A1B305F1D719d56B24747a0D) |
| DSCEngine | [`0x4986aA7086AA207f1008ACCf919F6c54f673f83E`](https://sepolia.etherscan.io/address/0x4986aA7086AA207f1008ACCf919F6c54f673f83E) |

### Mainnet

| Contract | Address |
|----------|---------|
| DecentralizedStableCoin | - |
| DSCEngine | - |

## Security

- Reentrancy protection on all state-changing functions
- Oracle staleness checks to prevent stale price attacks
- Health factor checks before and after operations

## License

MIT
