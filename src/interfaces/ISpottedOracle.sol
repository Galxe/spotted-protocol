// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ISpottedOracle {
    // Structs
    struct StateRequest {
        address requester;      // Who initiated the request
        address targetUser;     // User whose state we want to query
        uint256 key;           // State key
        uint256 blockNumber;   // Target block number
        uint256 timestamp;     // When the request was made
        uint256 deadlineTime;  // When the request expires
        bytes32 chainId;       // Target chain ID
        bool fulfilled;        // Whether the request has been fulfilled
        uint256 nonce;        // Request nonce for uniqueness
    }

    struct StateResponse {
        uint256 value;         // The state value
        uint64 blockNumber;    // Block number when the state was recorded
        uint32 timestamp;      // Timestamp when the state was recorded
        uint32 nonce;         // Response nonce
        uint8 stateType;      // Type of state value
        bytes[] signatures;    // Operator signatures
    }

    event StateRequestCreated(
        bytes32 indexed requestId,
        address indexed requester,
        address targetUser,
        uint256 key,
        uint256 blockNumber,
        bytes32 chainId
    );

    event StateRequestFulfilled(
        bytes32 indexed requestId,
        uint256 value,
        uint64 blockNumber,
        uint32 timestamp,
        uint32 nonce,
        uint8 stateType
    );

    error InvalidSignature();
    error RequestNotFound();
    error RequestAlreadyFulfilled();
    error RequestExpired();
    error InvalidDeadline();

    function requestStateProof(
        address targetUser,
        uint256 key,
        uint256 blockNumber,
        bytes32 chainId,
        uint256 deadline
    ) external returns (bytes32);

    function fulfillStateRequest(
        bytes32 requestId,
        StateResponse calldata response,
        bytes memory signatureData
    ) external;

    function getRequest(bytes32 requestId) external view returns (StateRequest memory);

    function getResponse(bytes32 requestId) external view returns (StateResponse memory);

    function stakeRegistry() external view returns (address);
} 