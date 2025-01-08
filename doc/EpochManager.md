# EpochManager

| File | Type | Proxy |
| -------- | -------- | -------- |
| `EpochManager.sol` | Singleton(mainnet) | UUPS proxy |

`EpochManager` manages epoch transitions and state updates for the AVS system. It handles epoch advancement, grace periods, and state synchronization across chains.

## Core Components

### Epoch Configuration
```solidity
uint256 public immutable EPOCH_LENGTH = 45000;    // ~7 days in blocks
uint256 public immutable GRACE_PERIOD = 6400;     // ~1 day in blocks
address public immutable REGISTRY_STATE_SENDER;    // State sender contract
```

### State Management
```solidity
uint256 public currentEpoch;                      // Current epoch number
uint256 public lastEpochBlock;                    // Block when last epoch started
uint256 public nextEpochBlock;                    // Block when next epoch starts
uint256 public lastUpdatedEpoch;                  // Last epoch that was updated

mapping(uint256 => uint256) public epochBlocks;   // Actual block numbers per epoch
mapping(uint256 => StateUpdate[]) internal epochUpdates;      // Updates per epoch
mapping(uint256 => uint256) public epochUpdateCounts;         // Update counts per epoch
```

## Key Features

### Epoch Management

**Epoch Advancement**
```solidity
function advanceEpoch() external
```
- Advances to next epoch when conditions are met
- Updates epoch boundaries
- Emits epoch transition events

**Epoch Reversion**
```solidity
function revertEpoch(uint256 epoch) external onlyOwner
```
- Allows reverting to previous epoch
- Updates epoch boundaries
- Only callable by owner

### State Updates

**Update Queueing**
```solidity
function queueStateUpdate(
    MessageType updateType,
    bytes memory data
) external
```
- Queues state updates for future epochs
- Handles grace period logic
- Maintains update history

**Cross-chain Updates**
```solidity
function sendStateUpdates(uint256 chainId) external payable
```
- Sends queued updates to other chains
- Handles batch processing
- Manages cross-chain messaging fees
- Detailed workflow can be found in [`Workflow.md`](./Workflow.md)

### Time Management

**Period Calculations**
```solidity
function blocksUntilNextEpoch() external view returns (uint256)
function blocksUntilGracePeriod() external view returns (uint256)
function isInGracePeriod() public view returns (bool)
```
- Calculates remaining blocks
- Manages grace periods
- Provides timing utilities

**Epoch Intervals**
```solidity
function getEpochInterval(uint256 epoch) external view returns (
    uint256 startBlock,
    uint256 graceBlock,
    uint256 endBlock
)
```
- Calculates epoch boundaries
- Determines grace period timing
- Provides interval information

### State Validation

**Update Validation**
```solidity
function isUpdatable(uint256 targetEpoch) public view returns (bool)
function _validatePeriods(
    uint256 _epochLength,
    uint256 _lockPeriod,
    uint256 _gracePeriod
) internal pure
```
- Validates update timing
- Enforces period constraints
- Maintains system integrity

## Events

```solidity
event EpochAdvanced(uint256 epoch, uint256 lastBlock, uint256 nextBlock)
event EpochReverted(uint256 epoch)
event StateUpdateQueued(uint256 epoch, MessageType updateType, bytes data)
event StateUpdatesSent(uint256 epoch, uint256 count)
```
