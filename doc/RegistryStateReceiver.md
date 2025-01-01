# RegistryStateReceiver

| File | Type | Proxy |
| -------- | -------- | -------- |
| `RegistryStateReceiver.sol` | Singleton(on support chains) | No proxy |

`RegistryStateReceiver` is responsible for receiving and processing operator state updates from the mainnet through Abridge. It maintains the synchronized operator state including weights and signing keys on the destination chain.

## High-level Concepts

1. Cross-chain operator state reception
2. Operator state management
3. Bridge message handling
4. Route access control

## Important Definitions

- _State Variables_:
```solidity
IAbridge public immutable abridge;                               // Bridge interface
address public immutable sender;                                 // Authorized sender address
mapping(address => uint256) public operatorWeights;             // Operator weight tracking
mapping(address => address) public operatorSigningKeys;         // Operator signing key tracking
```

- _Custom Errors_:
```solidity
error InvalidSender();       // Message not from authorized sender
error UpdateRouteFailed();   // Bridge route update failed
```

## Access Control

The contract implements dual-layer access control:
- _Owner_: Can update bridge route settings
- _Sender_: Only sender on mainnet can submit state updates
- _Bridge Contract_: Must be the caller of handleMessage

## Core Functions

### Message Handling
```solidity
function handleMessage(
    address from,
    bytes calldata message,
    bytes32 /*guid*/
) external returns (bytes4)
```

Processes operator state updates received through the bridge.

Effects:
- Decodes operator data from message
- Updates operator weights and signing keys
- Emits OperatorStateUpdated events for each operator

Requirements:
- Must be called by bridge contract
- Message must be from sender on mainnet
- Message must contain valid operator data

### Route Management
```solidity
function updateRoute(bool allowed) external onlyOwner
```

Updates the bridge route settings for the sender on mainnet.

Effects:
- Enables or disables message reception from sender
- Updates bridge configuration

Requirements:
- Only owner can call
- Bridge must successfully update route

### State Queries
```solidity
function getOperatorState(
    address operator
) external view returns (uint256 weight, address signingKey)
```

Retrieves complete state for a specific operator.

Returns:
- operator's current weight
- operator's current signing key

## Integration with External Systems

The contract integrates with:
- Abridge for cross-chain message reception
- RegistryStateSender on mainnet
- Local systems consuming operator state data

Key interactions:
- Receives encoded operator data through bridge
- Maintains synchronized operator state
- Provides query interface for local systems

## View Functions

Query functions for contract state:
```solidity
function getOperatorState(address operator) external view returns (
    uint256 weight,
    address signingKey
)
```

Returns operator's current state including:
- Current weight
- Current signing key

```solidity
function operatorWeights(address operator) external view returns (uint256)
function operatorSigningKeys(address operator) external view returns (address)
```

Individual state queries for:
- Operator's current weight
- Operator's current signing key
