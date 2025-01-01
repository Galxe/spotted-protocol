# MainChainVerifier

| File | Type | Proxy |
| -------- | -------- | -------- |
| `MainChainVerifier.sol` | Singleton(mainnet) | No proxy |

`MainChainVerifier` is responsible for receiving and storing state verification results from remote chains through Abridge. It maintains a record of verified states and manages remote verifier authorizations.

## High-level Concepts

1. Cross-chain state verification reception
2. Remote verifier authorization
3. Verified state storage
4. Bridge message handling

## Important Definitions

- _State Variables_:
```solidity
mapping(uint256 => mapping(address => mapping(uint256 => mapping(uint256 => Value)))) private verifiedStates; // chainId -> user -> key -> blockNumber -> Value
mapping(uint256 => address) public remoteVerifiers;    // chainId -> verifier address
mapping(address => bool) public isRemoteVerifier;      // verifier address -> is authorized
address public immutable disputeResolver;              // Dispute resolver contract
IAbridge public immutable abridge;                     // Bridge interface
```

- _Value Struct_:
```solidity
struct Value {
    uint256 value;    // Verified state value
    bool exist;       // Whether the state exists
}
```

## Access Control

The contract implements multi-layer access control:
- _Owner_: Can configure remote verifiers
- _Abridge_: Only bridge can deliver messages
- _Remote Verifiers_: Authorized to submit verification results

## Core Functions

### Remote Verifier Management
```solidity
function setRemoteVerifier(
    uint256 chainId,
    address verifier
) external onlyOwner
```

Configures authorized verifier for a specific chain.

Effects:
- Revokes old verifier permissions if exists
- Sets new verifier address
- Updates bridge route permissions
- Emits RemoteVerifierSet event

Requirements:
- Only owner can call
- Valid verifier address

### Message Handling
```solidity
function handleMessage(
    address from,
    bytes calldata message,
    bytes32 guid
) external returns (bytes4)
```

Processes verification results received from remote chains.

Effects:
- Decodes state verification data
- Stores verified state information
- Emits StateVerified event

Requirements:
- Must be called by bridge
- Sender must be authorized remote verifier
- Valid message format

### State Queries
```solidity
function getVerifiedState(
    uint256 chainId,
    address user,
    uint256 key,
    uint256 blockNumber
) external view returns (uint256 value, bool exist)
```

Retrieves verified state information.

Returns:
- Verified value
- Existence flag

## Integration with External Systems

The contract integrates with:
- Abridge for cross-chain message reception
- Remote chain verifiers
- Dispute resolution system (`StateDisputeResolver` will query this contract if a dispute is raised)
- State management system

Key interactions:
- Receives verification results through bridge
- Maintains verified state records
- Provides query interface for dispute resolution 