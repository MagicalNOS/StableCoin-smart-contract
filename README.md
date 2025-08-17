# DSC Engine - Decentralized Stable Coin

A decentralized, crypto-collateralized, low-volatility stablecoin system built on Ethereum.

## Overview

The DSC Engine is an **Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized** stablecoin protocol that allows users to mint DSC tokens by depositing approved cryptocurrency collateral. The system maintains stability through over-collateralization and liquidation mechanisms.

## Key Features

- **Over-collateralized**: Requires 200% collateralization ratio (50% liquidation threshold)
- **Decentralized**: No central authority controls the system
- **Crypto-backed**: Uses ETH and BTC as collateral
- **Price stability**: Pegged to USD through Chainlink price feeds
- **Liquidation protection**: Automatic liquidation when health factor drops below 1.0
- **Liquidation incentives**: 10% bonus for liquidators

## Architecture

### Core Contracts

1. **DSCEngine.sol** - Main protocol logic
2. **DecentralizedStableCoin.sol** - ERC20 stablecoin token

### Key Components

- **Collateral Management**: Deposit, withdraw, and track collateral
- **DSC Minting/Burning**: Mint DSC against collateral, burn to reduce debt
- **Health Factor**: Ensures adequate collateralization
- **Liquidation System**: Protects protocol from undercollateralized positions
- **Price Oracles**: Chainlink integration for real-time price data

## System Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| Liquidation Threshold | 50% | Minimum collateral ratio before liquidation |
| Liquidation Bonus | 10% | Bonus given to liquidators |
| Minimum Health Factor | 1.0 | Threshold below which positions can be liquidated |
| Supported Collateral | WETH, WBTC | Approved collateral tokens |

## Health Factor Calculation

The health factor determines if a position can be liquidated:

```
Health Factor = (Collateral Value × Liquidation Threshold) / Total DSC Minted
```

- **Health Factor > 1.0**: Position is safe
- **Health Factor < 1.0**: Position can be liquidated

## Usage Examples

Here are some common commands and usage patterns for working with this project's `Makefile`:

### Deploy Contracts

Deploy contracts to a network (default is local Anvil):

```sh
make deploy
```

Deploy contracts to a specific network, e.g., Sepolia:

```sh
make deploy ARGS="--network sepolia"
```

Deploy contracts to Fuji testnet:

```sh
make deploy ARGS="--network fuji"
```

You can also pass additional arguments to customize the deployment as needed.

---

### Fund Contracts

Send funds to contracts on a specific network:

```sh
make fund ARGS="--network sepolia"
```

---

### Run Tests

Run all tests:

```sh
make test
```

---

### Build & Format Code

Build the project:

```sh
make build
```

Format the solidity code:

```sh
make format
```

---

### Install or Update Dependencies

Install all contract dependencies:

```sh
make install
```

Update all contract dependencies:

```sh
make update
```

---

### Clean the Project

Remove build artifacts and reset modules:

```sh
make clean
make remove
```

## Security Features

### Reentrancy Protection
All key functions that modify state use OpenZeppelin's `ReentrancyGuard`.

### Input Validation
- Amount must be greater than zero
- Only approved collateral tokens accepted
- Array length matching in constructor

### Oracle Security
- Uses Chainlink price feeds for accurate pricing
- Implements stale price protection through `OracleLib`

### Access Control
- Only DSC Engine can mint/burn DSC tokens
- Users can only modify their own positions (except liquidation)

## Risk Considerations

1. **Oracle Risk**: Dependency on Chainlink price feeds
2. **Liquidation Risk**: Rapid price movements may cause liquidations
3. **Collateral Risk**: Limited to ETH and BTC exposure
4. **Smart Contract Risk**: Code vulnerabilities could affect funds

## Testing

This project uses **Foundry** for comprehensive testing, including unit tests, integration tests, and fuzz testing to ensure the security and reliability of the Decentralized Stablecoin (DSC) system.

### Test Structure

```
test/
├── unit/                   # Unit tests for individual contracts
├── integration/            # Integration tests for contract interactions
├── fuzz/                   # Fuzz tests using Handler contracts
├── mocks/                  # Mock contracts for testing
│   ├── ERC20Mock.sol
│   └── MockV3Aggregator.sol
└── Handler.sol             # Fuzz test handler
```

### Test Categories

#### 1. Unit Tests
- **DSCEngine.sol** - Core engine functionality
- **DecentralizedStableCoin.sol** - ERC20 stablecoin implementation
- **HelperConfig.sol** - Configuration and deployment helpers

#### 2. Integration Tests
- End-to-end workflows
- Cross-contract interactions
- System behavior under various scenarios

#### 3. Fuzz Testing
The project includes sophisticated fuzz testing using a custom `Handler` contract that:

##### Handler Functionality
- **Deposit Collateral**: Randomly deposits various collateral types
- **Mint DSC**: Mints stablecoins within safe collateralization ratios
- **Redeem Collateral**: Redeems collateral while maintaining health factors
- **User Management**: Tracks users with deposits for realistic testing scenarios

##### Fuzz Test Invariants
- Collateralization ratio always maintained above minimum threshold
- Total DSC supply backed by sufficient collateral
- Health factors remain above liquidation threshold
- No unauthorized minting or burning

### Test Configuration

#### Foundry Configuration (`foundry.toml`)
```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
fuzz = { runs = 256 }
invariant = { runs = 256, depth = 15 }

[profile.ci]
fuzz = { runs = 10000 }
invariant = { runs = 1000, depth = 20 }
```
## Known Issues and Risks

### 🚨 Critical Issue: Rapid Price Decline Risk

**Problem**: During rapid market downturns, the current liquidation mechanism may not respond quickly enough, potentially leading to:
- Undercollateralized positions remaining open
- System insolvency
- DSC price depegging from $1

**Root Causes**:
1. **Liquidation Delay**: Time gap between price drops and liquidator response
2. **Gas Competition**: High network congestion during market stress
3. **Liquidator Incentive Misalignment**: 10% bonus may be insufficient during extreme volatility
4. **Oracle Lag**: Price feed updates may lag behind market reality

## Potential Improvements

### 1. Dynamic Liquidation Parameters

### 2. Emergency Liquidation Mechanism

### 3. Automated Liquidation Bots

## License

This project is licensed under the MIT License.


