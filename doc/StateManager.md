# StateManager

| File | Type | Proxy |
| -------- | -------- | -------- |
| `StateManager.sol` | Singleton(mainnet and supported chains) | No proxy |

`StateManager` is responsible for managing state transitions and history for users. Users can set arbitrary key-value pairs states in the contract. It supports immutable and monotonic (increasing/decreasing) states with comprehensive history tracking and querying capabilities.

## High-level Concepts

1. State Management
2. History Tracking
3. Binary Search Optimization
4. Batch Operations
5. State Validation

## Important Definitions

- _ValueInfo_: Current state information
```solidity
struct ValueInfo {
    uint256 value;      // Current value
    uint8 stateType;    // State type (IMMUTABLE, MONOTONIC_INCREASING, MONOTONIC_DECREASING)
    bool exists;        // Whether the state exists
}
```

- _History_: Historical state record
```solidity
struct History {
    uint256 value;      // State value
    uint64 blockNumber; // Block number when committed
    uint32 timestamp;   // Timestamp when committed
    uint32 nonce;       // Sequential number
    uint8 stateType;    // State type when committed
}
```

## Core State Management

### State Setting
```solidity
function setValue(uint256 key, uint256 value, StateType stateType) external
```

Sets or updates a state value with validation:
- Prevents modification of immutable states
- Enforces monotonic rules for increasing/decreasing states
- Records state history
- Tracks user keys

### Batch Operations
```solidity
function batchSetValues(SetValueParams[] calldata params) external
```

Processes multiple state updates in a single transaction:
- Maximum 100 updates per batch
- Same validation rules as single updates
- More gas efficient for multiple updates

## History Management

### Binary Search Optimization
The contract uses an optimized binary search algorithm for efficient history queries:
- Supports both block number and timestamp based searches
- O(log n) complexity for finding specific records
- Handles edge cases and bounds checking

### History Query Patterns

1. Range Queries:
- `getHistoryBetweenBlockNumbers`: Get history between block numbers
- `getHistoryBetweenTimestamps`: Get history between timestamps
- `getHistoryBeforeBlockNumber`: Get history before a block
- `getHistoryAfterBlockNumber`: Get history after a block
- `getHistoryBeforeTimestamp`: Get history before a timestamp
- `getHistoryAfterTimestamp`: Get history after a timestamp

2. Point Queries:
- `getHistoryAtBlock`: Get state at specific block
- `getHistoryAtTimestamp`: Get state at specific timestamp
- `getHistoryAt`: Get state at specific index

## State Validation

### Monotonic State Validation
Functions to verify monotonic properties:
- `checkIncreasingValueAtBlock`: Verify increasing state at block
- `checkDecreasingValueAtBlock`: Verify decreasing state at block
- `checkIncreasingValueAtTimestamp`: Verify increasing state at timestamp
- `checkDecreasingValueAtTimestamp`: Verify decreasing state at timestamp

## View Functions

### Current State Queries
- `getCurrentValue`: Get current state for a key
- `getCurrentValues`: Batch get current states for multiple keys
- `getUsedKeys`: Get all keys used by an address

### History Queries
- `getHistoryCount`: Get total history count for a key
- `getLatestHistory`: Get N most recent history records
- `checkKeysStateTypes`: Get state types for multiple keys

## Events

```solidity
event HistoryCommitted(
    address indexed user,
    uint256 indexed key,
    uint256 value,
    uint256 timestamp,
    uint256 blockNumber,
    uint256 nonce,
    StateType stateType
)
```

Emitted when:
- New state is committed
- Batch states are committed

