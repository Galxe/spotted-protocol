# RegistryStateSender

| File | Type | Proxy |
| -------- | -------- | -------- |
| `RegistryStateSender.sol` | Singleton(mainnet) | No proxy |

`RegistryStateSender` manages cross-chain state synchronization for the stake registry. It handles sending state updates to other chains through bridges, enabling multi-chain operator set management.

## Core Components

### Bridge Configuration
```solidity
struct BridgeInfo {
    address bridge;    // Bridge contract address
    address receiver;  // Receiver contract on target chain
}

mapping(uint256 => BridgeInfo) public chainToBridgeInfo;  // Chain ID to bridge info
uint256[] public supportedChainIds;                       // List of supported chains
```

### Constants
```solidity
uint128 public constant EXECUTE_GAS_LIMIT = 500_000;  // Cross-chain execution gas limit
address public immutable epochManager;                 // Epoch manager reference
```

## Key Features

### Bridge Management

**Bridge Configuration**
```solidity
function addBridge(
    uint256 _chainId,
    address _bridge,
    address _receiver
) external onlyOwner
```
- Adds new bridge configuration for a chain
- Validates bridge and receiver addresses
- Prevents duplicate bridge configurations
- Maintains list of supported chains

**Bridge Modification**
```solidity
function modifyBridge(
    uint256 _chainId,
    address _newBridge,
    address _newReceiver
) external onlyOwner
```
- Updates existing bridge configuration
- Validates new addresses
- Emits modification event

### State Synchronization

**Batch Updates**
```solidity
function sendBatchUpdates(
    uint256 epoch,
    uint256 chainId,
    IEpochManager.StateUpdate[] memory updates
) external payable onlyEpochManager
```
- Sends state updates to target chain
- Handles bridge fee estimation and payment
- Ensures sufficient fee provided
- Only callable by epoch manager

### Administrative Functions

**Bridge Removal**
```solidity
function removeBridge(uint256 _chainId) external onlyOwner
```
- Removes bridge configuration
- Updates supported chain list
- Validates chain support

### View Functions

**Bridge Information**
```solidity
function getBridgeInfoByChainId(uint256 chainId) external view returns (BridgeInfo memory)
function getSupportedChainIds() external view returns (uint256[] memory)
```
- Query bridge configurations
- Access supported chain list

## Integration Points

The contract integrates with:
1. **EpochManager**: Controls state update timing
2. **Bridge Contracts**: Handles cross-chain messaging
3. **Receiver Contracts**: Processes updates on target chains

## Security Features

1. **Access Control**
   - Owner-only bridge management
   - EpochManager-only update submission
   - Validated bridge configurations

2. **Fee Management**
   - Automatic fee estimation
   - Fee validation before sending
   - Protection against insufficient fees

3. **State Validation**
   - Bridge address validation
   - Chain support verification
   - Duplicate prevention

## Events

```solidity
event BridgeAdded(uint256 indexed chainId, address bridge, address receiver)
event BridgeRemoved(uint256 indexed chainId)
event BridgeModified(uint256 indexed chainId, address newBridge, address newReceiver)
event UpdatesSent(uint256 indexed chainId, uint256 epoch, uint256 updateCount)
```
