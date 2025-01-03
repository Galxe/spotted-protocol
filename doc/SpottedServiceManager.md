# SpottedServiceManager

| File | Type | Proxy |
| -------- | -------- | -------- |
| `SpottedServiceManager.sol` | Singleton | UUPS proxy |

`SpottedServiceManager` is an Active Validator Set (AVS) service manager that enables cross-chain state verification through a quorum of operators. It's built upon EigenLayer and inherits from `ECDSAServiceManager`, which secures consensus through EigenLayer's economic stake-slashing mechanism. It allows operators to respond to tasks and others to challenge potentially incorrect state claims in an optimistic pattern. The service supports:
- Task response verification through ECDSA signatures (much cheaper than BLS)
- State challenge lifecycle
- Operator response history query
- Records of all responses

## High-level Concepts

1. Task response submission
2. Challenge lifecycle
3. Task query

## Important Definitions

- _Task_: A struct containing:
  - chainId: Target chain identifier
  - blockNumber: Block number to verify
  - value: State value to verify
```solidity
    struct Task {
        address user;
        uint32 chainId;
        uint64 blockNumber;
        uint32 taskCreatedBlock;
        uint256 key;
        uint256 value;
    }
```
- _TaskResponse_: A struct containing:
  - task: The original task data
  - responseBlock: Block number when response was submitted
  - challenged: Whether response has been challenged
  - resolved: Whether challenge has been resolved

```solidity
    struct TaskResponse {
        Task task;
        uint64 responseBlock;
        bool challenged;
        bool resolved;
    }
```

- _TaskId_: A bytes32 identifier for a task, generated from the task struct
```solidity
    keccak256(abi.encodePacked(
            user,
            chainId,
            blockNumber,
            key,
            value
        ))
```
- _Task Response Confirmer_: Authorized address that can submit task responses

## Access Control

The service implements role-based access control:

- _Owner_: Can set task response confirmers
- _Task Response Confirmer_: Can submit task responses
- _Dispute Resolver_: Can handle challenge submissions and resolutions

## Task Response
The task response process allows authorized confirmers to submit operator responses for verification.

Methods:
`respondToTask`

```solidity
function respondToTask(
    Task calldata task,
    bytes memory signatureData
) external
```

Submits signed responses from multiple operators for a task. The signatures are verified using ECDSA and responses are stored for each operator. Each task ID is generated deterministically from task parameters using keccak256. It uses `ECDSAStakeRegistry::isValidSignature` to verify the combined signatures.

Effects:
- Verifies task ID is correctly generated from task parameters
- Verifies quorum of operator signatures using ECDSAStakeRegistry
- Stores response for each signing operator with current block number
- Emits TaskResponded event with task ID, task data and confirmer address

Requirements:
- Caller must be a task response confirmer
- Task response confirmer will ensure that the task was not already responded to
- Contract must not be paused
- Task ID must match hash of task parameters
- No operator has already responded to this task (not resolved)
- Task hash must match if already exists in storage
- Valid operator signatures meeting quorum threshold
- Task parameters must be valid (non-zero address, valid chain ID, etc)

## Challenge Lifecycle

It records the full lifecycle of challenges against operator responses.

Methods:
`handleChallengeSubmission`
```solidity
function handleChallengeSubmission(
    address operator,
    bytes32 taskId
) external
```

This is called by `StateDisputeResolver` when a challenge is submitted, which marks the response as challenged.

`handleChallengeResolution`
```solidity
function handleChallengeResolution(
    address operator,
    bytes32 taskId,
    bool challengeSuccessful
) external
```

Also called by `StateDisputeResolver` when a challenge is resolved, which marks the response as resolved.

Effects:
- Marks response as challenged/resolved
- Records challenge outcome
- Emits ChallengeResolved event

Requirements:
- Caller must be the dispute resolver

## Task Query
The service provides methods to query task responses and history.

Methods:
- `getTaskResponse`

```solidity
function getTaskResponse(
    address operator,
    bytes32 taskId
) external view returns (TaskResponse memory)
```

Returns an operator's full response data for a specific task ID.

Returns:
- Empty struct if no response exists (condition:responseBlock is 0)
