# StateDisputeResolver

| File | Type | Proxy |
| -------- | -------- | -------- |
| `StateDisputeResolver.sol` | Singleton | UUPS proxy |

`StateDisputeResolver` is responsible for handling challenges against operator state claims in the Spotted AVS. Built on EigenLayer's middleware, it enables secure dispute resolution through a challenge-response mechanism backed by EigenLayer's economic stake-slashing system.

## High-level Concepts

1. Challenge submission and resolution
2. Slash operator if challenge successful

## Important Definitions

- _State_: A struct containing:
```solidity
struct State {
    address user;        // user address
    uint32 chainId;      // chain ID where state exists
    uint64 blockNumber;  // block number of the state
    uint48 timestamp;    // timestamp of the state
    uint256 key;        // state key
    uint256 value;      // state value
}
```

- _Challenge_: A struct containing:
```solidity
struct Challenge {
    address challenger;    // address that submitted the challenge
    uint64 deadline;      // block number when challenge expires
    bool resolved;        // whether challenge has been resolved
    State state;          // state being challenged
    address[] operators;  // operators who signed the invalid state
    uint256 actualState; // actual state verified on source chain
}
```

- _Constants_:
  - UNVERIFIED: type(uint256).max (sentinel value for unverified states)
  - CHALLENGE_WINDOW: 7200 blocks (24 hours)
  - CHALLENGE_BOND: 1 ETH
  - CHALLENGE_PERIOD: 7200 blocks (24 hours)

## Access Control

The contract implements role-based access control:
- _Owner_: Can update configuration settings
- _ServiceManager_: Can interact with operator registration
- _MainChainVerifier_: Can verify cross-chain states
- _Anyone_: Can submit challenges with required bond and resolve challenges

## Core Functions

### Challenge Submission
```solidity
function submitChallenge(
    address operator,
    bytes32 taskId
) external payable
```

Submits a challenge against an operator's state claim with required bond.

Effects:
- Creates new challenge entry with deadline
- Records challenger address and bond
- Notifies `ServiceManager`
- Emits ChallengeSubmitted event

Requirements:
- Sufficient challenge bond (1 ETH)
- Operator must be registered
- Challenge not already submitted
- Valid challenge ID

### Challenge Resolution
```solidity
function resolveChallenge(
    address operator,
    bytes32 taskId
) external
```

Resolves a challenge after verification by querying `MainChainVerifier::getVerifiedState`.

Effects:
- Verifies challenge outcome
- Slashes operator if challenge successful
- Distributes challenge bond
- Updates challenge status
- Emits ChallengeResolved event

Requirements:
- Challenge must exist
- State must be verified
- Challenge not already resolved

### Slash Operator

#### _slashOperator
```solidity
function _slashOperator(address operator, bytes32 challengeId) private
```

Slashes operator if challenge successful.

Effects:
- Reduces operator's stake across all configured strategies
- Marks operator as slashed in state tracking
- Emits OperatorSlashed event
- Burns slashed tokens by sending to dead address

Requirements:
- Slashable strategies must be configured
- Operator must be registered
- Challenge must be verified and failed
- Operator not already slashed for this challenge

#### Configuration
Slashing can be configured through onlyOwner function:
```solidity
function setSlashableStrategies(IStrategy[] calldata strategies) external onlyOwner {
    // Update slashable strategies
    delete slashableStrategies;
    for (uint256 i = 0; i < strategies.length;) {
        slashableStrategies.push(strategies[i]);
        unchecked { ++i; }
    }
    emit SlashableStrategiesUpdated(strategies);
}
```

- `slashableStrategies`: Array of strategy contracts that can be slashed
- `slashAmount`: Fixed percentage to slash across all strategies (in wads, where 1 wad = 1e18)

### Integration with EigenLayer

The slashing mechanism integrates with EigenLayer's middleware through:
- `AllocationManager` for executing slashes
- Unique Stake model ensuring stake is only slashable by one AVS
- Strategy-based stake tracking and reduction
- Permanent burning of slashed tokens

## Configuration Functions

Administrative functions for managing resolver settings:

```solidity
function setOperatorSetId(uint32 newSetId) external
function setSlashableStrategies(IStrategy[] calldata strategies) external
function setSlashAmount(uint256 newAmount) external
function setStateManager(uint256 chainId, address stateManager) external
function setServiceManager(address _serviceManager) external
function setMainChainVerifier(address _verifier) external
```

Effects:
- Updates respective configuration settings
- Emits corresponding events

Requirements:
- Only owner can call
- Valid parameters (non-zero addresses, valid amounts)

## View Functions

Query functions for contract state:
```solidity
function getOperator(address operator) external view returns (OperatorState memory)
function getChallenge(bytes32 challengeId) external view returns (Challenge memory)
function currentOperatorSetId() external view returns (uint32)
function getStateManager(uint256 chainId) external view returns (address)
```

## Why AVS as Challenger?

### 1. Signature Completeness
```solidity
function submitChallenge(
    address[] calldata operators,
    bytes[] calldata signatures
) external payable onlyAVS {
    // AVS has complete access to all operator signatures
    // Can ensure all relevant signatures are included
}
```

### 2. Security Guarantees

1. **Signature Completeness**
   - AVS as service coordinator has access to all operator signatures
   - Ensures submission of complete signature sets without omission
   - Prevents unfair punishment due to selective submission

2. **Incentive Alignment**
   - AVS's primary goal is maintaining service quality and security
   - Punishing malicious behavior aligns with AVS interests
   - No incentive to submit incorrect or incomplete challenges

3. **Prevention of Abuse**
   - Operators cannot submit challenges directly, preventing malicious reports
   - Malicious users cannot exploit incomplete signature sets
   - Reduces invalid or malicious challenges



