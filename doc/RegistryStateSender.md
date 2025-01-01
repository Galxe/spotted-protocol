# RegistryStateSender

| File | Type | Proxy |
| -------- | -------- | -------- |
| `RegistryStateSender.sol` | Singleton(mainnet) | No proxy |

`RegistryStateSender` is responsible for synchronizing operator state from the stake registry to other chains through Abridge. It enables cross-chain operator set management by collecting and transmitting operator data including weights and signing keys.

## High-level Concepts

1. Cross-chain operator state synchronization
2. Fee management for bridge transactions
3. Operator data collection and encoding

## Important Definitions

- _Constants_:
  - EXECUTE_GAS_LIMIT: 500,000 gas (for cross-chain message execution)

- _State Variables_:
```solidity
IECDSAStakeRegistry public immutable stakeRegistry;  // Source of operator data
IAbridge public immutable abridge;                   // Abridge interface
address public immutable receiver;                   // Destination contract(RegistryStateReceiver)
```

## Core Functions

### Operator State Synchronization
```solidity
function syncAllOperators() external payable
```

Collects and transmits all operator data to the destination chain through Abridge.

Effects:
- Collects operator addresses, weights, and signing keys
- Encodes data for cross-chain transmission
- Sends data through bridge with provided fee
- Emits bridge-specific events

Requirements:
- Sufficient ETH provided to cover bridge fee
- Bridge must be operational

### Operator Data Collection
```solidity
function getAllOperatorsData() public view returns (
    address[] memory operators,
    uint256[] memory weights,
    address[] memory signingKeys
)
```

Collects current operator data from the `ECDSAStakeRegistry`.

Returns:
- Arrays of operator addresses, weights, and signing keys
- Arrays are dynamically sized to actual operator count

Effects:
- Queries stake registry for operator data
- Filters for registered operators only
- Optimizes array sizes using assembly

### Fee Management

#### receive
```solidity
receive() external payable
```
Allows contract to receive ETH for bridge fees

#### withdraw
```solidity
function withdraw(address to) external onlyOwner
```

Withdraws accumulated bridge fees to specified address.

Effects:
- Transfers entire contract balance
- Emits FundsWithdrawn event

Requirements:
- Only owner can call
- Transfer must succeed

## Integration with External Systems

The contract integrates with:
- EigenLayer's ECDSAStakeRegistry for operator data
- Abridge for cross-chain message passing
- Destination chain receiver contract

## View Functions

Query functions for contract state:
```solidity
function getAllOperatorsData() external view returns (
    address[] memory,
    uint256[] memory,
    address[] memory
)
```

Returns current operator set data including:
- Operator addresses
- Operator weights
- Signing keys
