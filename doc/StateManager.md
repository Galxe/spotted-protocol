# StateManager

| File | Type | Proxy |
| -------- | -------- | -------- |
| `StateManager.sol` | Singleton | No proxy |

`StateManager` is responsible for managing state transitions and history for users. Users can set arbitrary key-value pairs states in the contract with comprehensive history tracking and querying capabilities. Then, the state can be queried to generate proof by AVS.

## Core Components

### State Storage
```solidity
mapping(address user => mapping(uint256 key => uint256 value)) private currentValues;
mapping(address user => mapping(uint256 key => History[])) private histories;
mapping(address user => uint256[]) private userKeys;
```

### Important Definitions

- _History_: Historical state record
```solidity
struct History {
    uint256 value;      // User-defined value
    uint64 blockNumber; // Block number when committed
    uint48 timestamp;   // Timestamp when committed
}
```

- _SetValueParams_: Parameters for batch value setting
```solidity
struct SetValueParams {
    uint256 key;   // Key to set
    uint256 value; // Value to set
}
```

### Constants
```solidity
uint256 private constant MAX_BATCH_SIZE = 100;  // Maximum batch size for setValue operations
```

## Core Functions

### State Setting
```solidity
function setValue(uint256 key, uint256 value) external
```
- Sets a single value for a key
- Records state history
- Tracks user keys
- Emits HistoryCommitted event

### Batch Operations
```solidity
function batchSetValues(SetValueParams[] calldata params) external
```
- Sets multiple values in one transaction
- Maximum 100 updates per batch
- Same validation and recording as single updates
- More gas efficient for multiple updates

## Query Functions

### Current State Queries
```solidity
// Gets the current value for a specific key of a user
function getCurrentValue(address user, uint256 key) external view returns (uint256)

// Gets current values for multiple keys of a user in a single call
function getCurrentValues(address user, uint256[] calldata keys) external view returns (uint256[] memory)

// Gets all keys that a user has ever used
function getUsedKeys(address user) external view returns (uint256[] memory)
```

### History Range Queries
```solidity
// Gets all history entries between two block numbers
function getHistoryBetweenBlockNumbers(address, uint256, uint256, uint256) external view returns (History[] memory)

// Gets all history entries between two timestamps
function getHistoryBetweenTimestamps(address, uint256, uint256, uint256) external view returns (History[] memory)

// Gets all history entries before a specific block number
function getHistoryBeforeBlockNumber(address, uint256, uint256) external view returns (History[] memory)

// Gets all history entries after a specific block number
function getHistoryAfterBlockNumber(address, uint256, uint256) external view returns (History[] memory)

// Gets all history entries before a specific timestamp
function getHistoryBeforeTimestamp(address, uint256, uint256) external view returns (History[] memory)

// Gets all history entries after a specific timestamp
function getHistoryAfterTimestamp(address, uint256, uint256) external view returns (History[] memory)
```

### Point Queries
```solidity
// Gets the history entry at an exact block number
function getHistoryAtBlock(address, uint256, uint256) external view returns (History memory)

// Gets the history entry at an exact timestamp
function getHistoryAtTimestamp(address, uint256, uint256) external view returns (History memory)

// Gets the history entry at a specific index in the history array
function getHistoryAt(address, uint256, uint256) external view returns (History memory)
```

### Aggregation Queries
```solidity
// Gets the total number of history entries for a user's key
function getHistoryCount(address user, uint256 key) external view returns (uint256)

// Gets the N most recent history entries across all keys for a user
function getLatestHistory(address user, uint256 n) external view returns (History[] memory)

// Gets all historical values for a specific key of a user
function getHistory(address user, uint256 key) external view returns (History[] memory)
```

## Implementation Details

### Binary Search Optimization
```solidity
function _binarySearch(History[] storage history, uint256 target, SearchType searchType) private view returns (uint256)
```
- Optimized binary search for history queries
- Supports both block number and timestamp searches
- O(log n) complexity for finding specific records
- Returns last position less than or equal to target

## Events

```solidity
event HistoryCommitted(
    address indexed user,
    uint256 indexed key,
    uint256 value,
    uint256 timestamp,
    uint256 blockNumber
)
```

## Error Handling

```solidity
error StateManager__BatchTooLarge();
error StateManager__NoHistoryFound();
error StateManager__InvalidBlockRange();
error StateManager__InvalidTimeRange();
error StateManager__BlockNotFound();
error StateManager__TimestampNotFound();
error StateManager__IndexOutOfBounds();
```

