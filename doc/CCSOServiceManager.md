# SpottedServiceManager

| File | Type | Proxy |
| -------- | -------- | -------- |
| `SpottedServiceManager.sol` | Singleton | UUPS proxy |

`SpottedServiceManager` is responsible for managing cross-chain state oracle services and operator responses. It allows operators to respond to tasks and others to challenge potentially incorrect state claims. The service supports:
- Task response verification through ECDSA signatures (much cheaper than BLS)
- State challenge mechanism with bond requirement
- Tasks list and history

## High-level Concepts

1. Task Management
2. Response Verification
3. Challenge Resolution

## Important Definitions

- _Task_: A struct containing:
  - chainId: Target chain identifier
  - blockNumber: Block number to verify
  - stateValue: State value to verify
  - taskCreatedBlock: Block when task was created
- _Challenge Bond_: Amount of ETH required to submit a challenge (2 ETH)
- _Task Response_: Operator's signed response to a task, stored in operatorResponses[operator][taskNum]

## Task Response 
The task response process allows operators to submit their signed state claims for verification.

Methods:
`respondToTask`

```solidity
function respondToTask(
    Task calldata task,
    uint32 referenceTaskIndex,
    bytes memory signature
) external
```

submits a signed response to a task. The response is verified using ECDSA signatures and stored in the operator's response history.

Effects:
- Verifies operator's ECDSA signature
- Stores response in operatorResponses mapping
- Updates task hash if new
- Updates latest task number if needed
- Emits TaskResponded event

Requirements:
- Operator has not already responded to this task
- Task hash matches if already exists
- Valid ECDSA signature from operator
- Contract not paused

## State Challenge 
The challenge mechanism allows participants to dispute potentially incorrect state claims by operators.

Methods:
`submitStateChallenge`

```solidity
function submitStateChallenge(
    uint256 chainId,
    uint256 blockNumber,
    bytes32 claimedState,
    bytes memory proof,
    address operator
) external payable
```

Submits a challenge against an operator's state claim with required bond.

Effects:
- Verifies challenge bond amount
- Forwards challenge to state verifier
- Emits TaskChallenged event if successful

Requirements:
- Sufficient challenge bond (2 ETH)
- Valid state proof
- Contract not paused

## Task Query 
The service provides methods to query task responses and history.

Methods:
- `getTaskResponse`
- `getTaskHash`
- `latestTaskNum`

```solidity
function getTaskResponse(
    address operator,
    uint32 taskNum
) external view returns (bytes32)
```

Returns an operator's response for a specific task number.

Returns:
- The state value submitted by the operator
- Zero if no response exists

