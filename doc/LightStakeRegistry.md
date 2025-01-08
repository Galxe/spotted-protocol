# LightStakeRegistry

| File | Type | Proxy |
| -------- | -------- | -------- |
| `LightStakeRegistry.sol` | Singleton(on support chains) | UUPS proxy |

`LightStakeRegistry` is a lightweight cross-chain state synchronization contract that receives and processes state updates from the main chain's `EpochManager`. It primarily serves to validate operator signatures on sidechains by maintaining operator states (weights, signing keys, etc.) for each epoch.

## Core Components

### State Management
```solidity
mapping(address => bool) private _operatorRegistered;                  // Operator registration status
mapping(address => EpochCheckpoints.History) private _operatorWeightHistory;      // Operator weight history
mapping(address => EpochCheckpoints.History) private _operatorSigningKeyHistory;  // Operator signing key history
EpochCheckpoints.History private _totalWeightHistory;                 // Total weight history
EpochCheckpoints.History private _thresholdWeightHistory;            // Threshold weight history
```

### Configuration
```solidity
uint256 private _minimumWeight;           // Minimum weight requirement
uint256 private _totalOperators;          // Total number of operators
Quorum private _quorum;                   // Quorum configuration
IEpochManager public immutable EPOCH_MANAGER;  // Epoch manager reference
```

## Key Features

### State Update Processing

**Update Reception**
```solidity
function processEpochUpdate(
    uint256 epoch,
    IEpochManager.StateUpdate[] memory updates
) external onlyStateReceiver
```
This function is the core entry point for receiving state updates from the main chain:
- Only callable by the designated state receiver contract
- Processes updates for a future epoch (must be greater than current epoch + 1)
- Handles different types of updates through specialized internal functions
- Updates are processed atomically to maintain state consistency
- Emits appropriate events for each successful update

### Signature Verification

**ECDSA Verification**
```solidity
function isValidSignature(
    bytes32 _dataHash,
    bytes memory _signatureData
) external view returns (bytes4)
```
Key signature validation function that:
- Decodes operator addresses, signatures, and reference epoch from signature data
- Verifies each operator's weight at the reference epoch
- Ensures cumulative weight meets threshold requirements
- Validates ECDSA signatures against stored signing keys
- Returns ERC1271 magic value (0x1626ba7e) for valid signatures
- Reverts with specific errors for invalid signatures

### Historical State Access

**Weight Queries**
```solidity
function getOperatorWeightAtEpoch(address _operator, uint32 _epochNumber) external view
function getTotalWeightAtEpoch(uint32 _epochNumber) external view
function getThresholdWeightAtEpoch(uint32 _epochNumber) external view
```
These functions provide critical historical state access:
- Allow querying operator weights at any past epoch
- Support verification of historical signatures
- Enable validation of past quorum decisions
- Return zero for non-existent records
- Use efficient checkpoint-based storage

**Signing Key Queries**
```solidity
function getOperatorSigningKeyAtEpoch(address _operator, uint32 _epochNumber) external view
function getLastestOperatorSigningKey(address _operator) external view
```
Essential functions for signature verification:
- Retrieve operator's signing key for specific epoch
- Support both historical and current key lookups
- Enable validation across different epochs
- Return zero address if no key is set

## Update Types

### Supported Updates
Each update type serves a specific purpose in maintaining the registry state:

1. **REGISTER** 
   - Adds new operator to the registry
   - Sets initial signing key and weight
   - Updates total operator count

2. **DEREGISTER** 
   - Removes operator from active set
   - Cleans up operator state
   - Adjusts total weight

3. **UPDATE_SIGNING_KEY** 
   - Updates operator's signing key
   - Maintains key history for future reference
   - Critical for signature validation

4. **UPDATE_OPERATORS** 
   - Batch updates operator weights
   - Updates total weight
   - Maintains weight history

5. **UPDATE_QUORUM** 
   - Modifies quorum configuration
   - Updates affected operator weights
   - Adjusts threshold requirements

6. **UPDATE_MIN_WEIGHT** 
   - Changes minimum weight requirement
   - Updates affected operator states
   - Maintains system integrity

7. **UPDATE_THRESHOLD** 
   - Modifies threshold weight
   - Updates threshold history
   - Affects signature validation

8. **UPDATE_OPERATORS_FOR_QUORUM** 
   - Updates specific quorum operators
   - Maintains quorum-specific weights
   - Updates total weight for quorum

## Integration Points

The contract integrates with:
1. **EpochManager** - Receives main chain state updates
2. **AVS System** - Provides signature verification services
3. **Cross-chain Infrastructure** - Handles cross-chain messaging

## Events

```solidity
event OperatorRegistered(address indexed operator)
event OperatorDeregistered(address indexed operator)
event SigningKeyUpdate(address indexed operator, address newKey, address oldKey)
event QuorumUpdated(Quorum oldQuorum, Quorum newQuorum)
event ThresholdWeightUpdated(uint256 newThreshold)
event OperatorsUpdated(address[] operators, uint256[] weights, uint256 totalWeight)
```

