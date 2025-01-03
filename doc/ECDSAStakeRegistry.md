# ECDSAStakeRegistry

| File | Type | Proxy |
| -------- | -------- | -------- |
| `ECDSAStakeRegistry.sol` | Singleton | UUPS proxy |

`ECDSAStakeRegistry` manages operator registration, stake weights, and ECDSA signature verification for AVS. It maintains historical records of operator weights and signing keys while enforcing quorum rules for signature validation.

## Core Components

### State Management
```solidity
mapping(address => bool) private _operatorRegistered;
mapping(address => CheckpointsUpgradeable.History) private _operatorWeightHistory;
mapping(address => CheckpointsUpgradeable.History) private _operatorSigningKeyHistory;
CheckpointsUpgradeable.History private _totalWeightHistory;
CheckpointsUpgradeable.History private _thresholdWeightHistory;
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
- Updates operator weights
- Maintains weight history
- Updates total weight

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

### Historical Tracking

**Weight History**
- Maintains checkpoints for operator weights
- Records total weight history
- Tracks threshold weight changes

**Signing Key History**
- Records operator signing key changes
- Provides historical key lookup
- Supports block-based queries


## Integration Points

The contract integrates with:
1. **DelegationManager**: For stake delegation
2. **ServiceManager**: For AVS registration
3. **Strategies**: For weight calculations
4. **EigenLayer Core**: For operator management 