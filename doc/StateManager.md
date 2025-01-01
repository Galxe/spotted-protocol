
# StateManager

| File | Type | Proxy |
| -------- | -------- | -------- |
| `StateManager.sol` | Singleton | - |

`StateManager` is responsible for managing state transitions and history for users, and it allows operators and users to create, read, and update states. It supports two types of states:
- Immutable states: Once committed, these states cannot be modified
- Monotonic states: Each new state value must be strictly greater than the previous value

The primary goal of the `StateManager` is to provide a verifiable and queryable history of state changes that can be used to:
- Track user state transitions over time
- Verify state values at specific blocks
- Support efficient state queries and lookups

## High-level Concepts

1. State Commitment
2. State Queries
3. State Verification

## Important Definitions

- _State_: A struct containing:
  - value: The actual state value (bytes32)
  - timestamp: When the state was committed
  - blockNumber: Block number when committed
  - nonce: Monotonically increasing counter per user
  - stateType: IMMUTABLE or MONOTONIC
  - metadata: Optional associated data
- _State History_: The ordered sequence (array) of states for a user, stored in userStates[address][]. Each new state is appended to this array.
---
## State Commitment (Create)
The state commitment process allows users to record new states. For immutable states, the value cannot be changed once set. For monotonic states, each new value must be greater than the previous value.

Methods:
`commitState`

```solidity
function commitState(
    bytes32 value,
    StateType stateType,
    bytes calldata metadata
) external returns (uint256, uint256)
```

Commits a new state for the caller. The state is appended to the user's state history with a new nonce. For monotonic states, the value must be greater than the previous state value.

Effects:
Creates and stores a new State struct with:
- Current block number and timestamp
- Next sequential nonce for the user
- Provided value, type and metadata
- Emits StateCommitted event with state details
Returns the previous and new state values
Requirements:
- stateType must be either IMMUTABLE or MONOTONIC
- For MONOTONIC type, new value must be greater than previous value
- Previous state must exist if type is MONOTONIC

---

## State Queries (Read)
The `StateManager` provides several methods to query historical states. These methods support different query patterns like:
- Latest state value
- State at a specific block
- States within a block range
- Recent state changes

Methods:
- `latest`
- `getStateAtBlock`
- `getStateChangesBetween`
- `getLatestStates`

Returns the state value that was active at a specific block number. Uses binary search for efficient lookup.
Returns:
- The state value at the specified block
- 0 if no state existed at that block
Requirements:
- blockNumber must be less than current block
- User must have state history
---
## State Verification (Update)
It allows checking state validity and querying state proofs. 
Methods:
- `getStateSnapshots`
- `getStateByBlockNumber`

The verification flow:
1. Getting state snapshots for specific blocks
2. Verifying the snapshots against block roots
3. Confirming state transitions are valid
This enables secure state verification across different chains while maintaining the integrity of state history.

