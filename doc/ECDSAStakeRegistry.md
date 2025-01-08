# ECDSAStakeRegistry

| File | Type | Proxy |
| -------- | -------- | -------- |
| `ECDSAStakeRegistry.sol` | Singleton | UUPS proxy |

`ECDSAStakeRegistry` manages operator registration, stake weights, and ECDSA signature verification for AVS. It maintains historical records of operator weights and signing keys while enforcing quorum rules for signature validation. It uses `EpochCheckpointsUpgradeable` to store historical records separately for each epoch.

## Core Components

### State Management
```solidity
mapping(address => bool) private _operatorRegistered; // Operator registration status
mapping(address => CheckpointsUpgradeable.History) private _operatorWeightHistory; // Operator weight history
mapping(address => CheckpointsUpgradeable.History) private _operatorSigningKeyHistory; // Operator signing key history
CheckpointsUpgradeable.History private _totalWeightHistory; // Total weight history
CheckpointsUpgradeable.History private _thresholdWeightHistory; // Threshold weight history
```

### Quorum Configuration
```solidity
struct Quorum {
    StrategyParams[] strategies;  // Ordered list of strategies and their weights
}

struct StrategyParams {
    IStrategy strategy;   // Strategy contract address
    uint96 multiplier;   // Weight multiplier in basis points
}
```

## Key Features

### Operator Management

**Registration**
```solidity
function registerOperatorWithSignature(
    ISignatureUtils.SignatureWithSaltAndExpiry memory _operatorSignature,
    address _signingKey
) external
```
- Registers new operators with their signing keys
- Validates operator signatures
- Updates operator weights
- Records registration in AVS directory

**Deregistration**
```solidity
function deregisterOperator() external
```
- Removes operator registration
- Updates total weight
- Cleans up operator records

### Weight Management

**Weight Calculation**
```solidity
function getOperatorWeight(address _operator) public view returns (uint256)
```
- Calculates operator weight based on delegated stakes
- Applies strategy multipliers
- Enforces minimum weight requirements

**Weight Updates**
```solidity
function updateOperators(address[] memory _operators) external
```
- Updates operator weights by querying `DelegationManager`
- Maintains weight history
- Updates total weight

### Configuration Management

**Quorum Updates**
```solidity
function updateQuorumConfig(
    Quorum memory _quorum,
    address[] memory _operators
) external onlyOwner
```
- Updates quorum configuration with new strategies and weights
- Updates affected operators' weights
- Maintains weight history for all affected operators
- Queues state update for cross-chain synchronization

**Minimum Weight Updates**
```solidity
function updateMinimumWeight(
    uint256 _newMinimumWeight,
    address[] memory _operators
) external onlyOwner
```
- Sets new minimum weight requirement for operators
- Updates all affected operators' weights
- Recalculates total weight
- Queues state update for cross-chain sync

**Stake Threshold Updates**
```solidity
function updateStakeThreshold(uint256 _thresholdWeight) external onlyOwner
```
- Updates cumulative threshold weight for signature validation
- Affects future signature validations
- Queues state update for cross-chain sync

**Operator Set Updates**
```solidity
function updateOperatorsForQuorum(
    address[][] memory operatorsPerQuorum,
    bytes memory
) external
```
- Updates operator set for the quorum
- Recalculates weights for all operators
- Updates total weight
- Maintains compatibility with multi-quorum systems

### Signature Verification

**Signature Validation**
```solidity
function _checkSignatures(
    bytes32 _dataHash,
    address[] memory _operators,
    bytes[] memory _signatures,
    uint32 _referenceBlock
) internal view
```
- Verifies ECDSA signatures
- Validates signer ordering
- Checks cumulative weight threshold
- Enforces quorum rules
- Supports historical state verification

**ERC1271 Support**
```solidity
function isValidSignature(
    bytes32 _dataHash,
    bytes memory _signatureData
) external view returns (bytes4)
```
- Implements ERC1271 interface for signature validation
- Decodes operator addresses, signatures, and reference epoch
- Validates signatures against current epoch
- Returns standard magic value for valid signatures

### Query Functions

**Quorum Information**
```solidity
function quorum() external view returns (Quorum memory)
```
- Returns current quorum configuration
- Includes strategy list and their weights

**Signing Key Queries**
```solidity
function getLastestOperatorSigningKey(address _operator) external view returns (address)
function getOperatorSigningKeyAtEpoch(address _operator, uint32 _epochNumber) external view returns (address)
```
- Get operator's current or historical signing keys
- Supports both latest and epoch-specific queries
- Returns address(0) for non-existent records

**Weight Checkpoints**
```solidity
function getLastCheckpointOperatorWeight(address _operator) external view returns (uint256)
function getLastCheckpointTotalWeight() external view returns (uint256)
function getLastCheckpointThresholdWeight() external view returns (uint256)
```
- Access latest weight checkpoints
- Includes individual operator weights
- Provides total and threshold weights

**Historical Weight Queries**
```solidity
function getOperatorWeightAtEpoch(address _operator, uint32 _epochNumber) external view returns (uint256)
function getTotalWeightAtEpoch(uint32 _epochNumber) external view returns (uint256)
function getLastCheckpointThresholdWeightAtEpoch(uint32 _epochNumber) external view returns (uint256)
```
- Retrieve historical weight data
- Support epoch-based queries
- Access operator, total, and threshold weights

**Status Checks**
```solidity
function operatorRegistered(address _operator) external view returns (bool)
function minimumWeight() external view returns (uint256)
```
- Check operator registration status
- Get current minimum weight requirement
- Support system state verification

**Weight Calculation**
```solidity
function getOperatorWeight(address _operator) public view returns (uint256)
```
- Calculates current operator weight
- Queries delegation manager for shares
- Applies strategy multipliers
- Enforces minimum weight threshold
- Returns 0 if below minimum weight

## Integration Points

The contract integrates with:
1. **DelegationManager**: For stake delegation
2. **ServiceManager**: For AVS registration
3. **Strategies**: For weight calculations
4. **EigenLayer Core**: For operator management 

## Events

```solidity
event OperatorRegistered(address indexed operator, address serviceManager)
event OperatorDeregistered(address indexed operator, address serviceManager)
event SigningKeyUpdate(address indexed operator, address newKey, address oldKey)
event QuorumUpdated(Quorum oldQuorum, Quorum newQuorum)
event OperatorWeightUpdated(address indexed operator, uint256 oldWeight, uint256 newWeight)
event TotalWeightUpdated(uint256 oldTotalWeight, uint256 newTotalWeight)
event ThresholdWeightUpdated(uint256 newThreshold)
event MinimumWeightUpdated(uint256 oldMinimumWeight, uint256 newMinimumWeight)
``` 