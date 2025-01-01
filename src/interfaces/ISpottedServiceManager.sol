// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ISignatureUtils} from "@eigenlayer/contracts/interfaces/ISignatureUtils.sol";

interface ISpottedServiceManager {
    // Custom errors
    error SpottedServiceManager__TaskAlreadyResponded();
    error SpottedServiceManager__TaskHashMismatch();
    error SpottedServiceManager__InvalidSignature();
    error SpottedServiceManager__TaskNotFound();
    error SpottedServiceManager__InvalidChallenge();
    error SpottedServiceManager__ChallengePeriodActive();
    error SpottedServiceManager__InsufficientChallengeBond();
    error SpottedServiceManager__TaskNotChallenged();
    error SpottedServiceManager__CallerNotDisputeResolver();
    error SpottedServiceManager__CallerNotStakeRegistry();
    error SpottedServiceManager__TaskAlreadyChallenged();
    error SpottedServiceManager__TaskAlreadyResolved();
    error SpottedServiceManager__CallerNotTaskResponseConfirmer();
    error SpottedServiceManager__InvalidAddress();
    error SpottedServiceManager__InvalidTaskId();
    // Events
    event TaskResponseConfirmerSet(address confirmer, bool status);
    event TaskResponded(bytes32 indexed taskId, Task task, address indexed operator);
    event TaskChallenged(address indexed operator, bytes32 indexed taskId);
    event ChallengeResolved(
        address indexed operator,
        bytes32 indexed taskId,
        bool challengeSuccessful
    );

    // Task struct
    struct Task {
        bytes32 taskId;
        address user;
        uint32 chainId;
        uint64 blockNumber;
        uint256 key;
        uint256 value;
    }

    struct TaskResponse {
        Task task;
        uint64 responseBlock;
        bool challenged;
        bool resolved;
    }

    // Core functions
    function respondToTask(
        Task calldata task,
        bytes memory signature
    ) external;

    function handleChallengeSubmission(
        address operator,
        bytes32 taskId
    ) external;

    function handleChallengeResolution(
        address operator,
        bytes32 taskId,
        bool challengeSuccessful
    ) external;

    // View functions
    function getTaskResponse(
        address operator,
        bytes32 taskId
    ) external view returns (TaskResponse memory);
}
