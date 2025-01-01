// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IStateManager {
    // custom errors
    error StateManager__ImmutableStateCannotBeModified();
    error StateManager__ValueNotMonotonicIncreasing();
    error StateManager__ValueNotMonotonicDecreasing();
    error StateManager__KeyNotFound();
    error StateManager__InvalidBlockRange();
    error StateManager__InvalidTimeRange();
    error StateManager__BlockNotFound();
    error StateManager__TimestampNotFound();
    error StateManager__IndexOutOfBounds();
    error StateManager__InvalidStateType();
    error StateManager__NoHistoryFound();
    error StateManager__BatchTooLarge();

    // state types
    enum StateType {
        IMMUTABLE,
        MONOTONIC_INCREASING,
        MONOTONIC_DECREASING
    }

    // search type for binary search
    enum SearchType {
        BLOCK_NUMBER,
        TIMESTAMP
    }

    // value info structure
    struct ValueInfo {
        uint256 value; // slot 0: user-defined value
        uint8 stateType; // slot 1: [0-7] state type
        bool exists; // slot 1: [8] whether exists
    }

    // history structure
    struct History {
        uint256 value; // slot 0: user-defined value
        uint64 blockNumber; // slot 1: [0-63] block number
        uint32 timestamp; // slot 1: [64-95] unix timestamp
        uint32 nonce; // slot 1: [96-127] operation sequence number
        uint8 stateType; // slot 1: [128-135] state type
    }

    // parameters for setting value
    struct SetValueParams {
        uint256 key;
        uint256 value;
        StateType stateType;
    }

    // events
    event HistoryCommitted(
        address indexed user,
        uint256 indexed key,
        uint256 value,
        uint256 timestamp,
        uint256 blockNumber,
        uint256 nonce,
        StateType stateType
    );

    // core functions
    function setValue(uint256 key, uint256 value, StateType stateType) external;
    function batchSetValues(
        SetValueParams[] calldata params
    ) external;

    // query functions
    function getCurrentValue(address user, uint256 key) external view returns (ValueInfo memory);
    function getHistoryBetweenBlockNumbers(
        address user,
        uint256 key,
        uint256 fromBlock,
        uint256 toBlock
    ) external view returns (History[] memory);
    function getHistoryBetweenTimestamps(
        address user,
        uint256 key,
        uint256 fromTimestamp,
        uint256 toTimestamp
    ) external view returns (History[] memory);
    function getHistoryBeforeBlockNumber(
        address user,
        uint256 key,
        uint256 blockNumber
    ) external view returns (History[] memory);
    function getHistoryAfterBlockNumber(
        address user,
        uint256 key,
        uint256 blockNumber
    ) external view returns (History[] memory);
    function getHistoryBeforeTimestamp(
        address user,
        uint256 key,
        uint256 timestamp
    ) external view returns (History[] memory);
    function getHistoryAfterTimestamp(
        address user,
        uint256 key,
        uint256 timestamp
    ) external view returns (History[] memory);
    function getHistoryAtBlock(
        address user,
        uint256 key,
        uint256 blockNumber
    ) external view returns (History memory);
    function getHistoryAtTimestamp(
        address user,
        uint256 key,
        uint256 timestamp
    ) external view returns (History memory);
    function getHistoryCount(address user, uint256 key) external view returns (uint256);
    function getHistoryAt(
        address user,
        uint256 key,
        uint256 index
    ) external view returns (History memory);
    function getLatestHistory(address user, uint256 n) external view returns (History[] memory);
    function getUsedKeys(
        address user
    ) external view returns (uint256[] memory);
    function checkIncreasingValueAtBlock(
        address user,
        uint256 key,
        uint256 blockNumber,
        uint256 checkValue
    ) external view returns (bool);
    function checkDecreasingValueAtBlock(
        address user,
        uint256 key,
        uint256 blockNumber,
        uint256 checkValue
    ) external view returns (bool);
    function checkIncreasingValueAtTimestamp(
        address user,
        uint256 key,
        uint256 timestamp,
        uint256 checkValue
    ) external view returns (bool);
    function checkDecreasingValueAtTimestamp(
        address user,
        uint256 key,
        uint256 timestamp,
        uint256 checkValue
    ) external view returns (bool);
    function getCurrentValues(
        address user,
        uint256[] calldata keys
    ) external view returns (ValueInfo[] memory values);
    function checkKeysStateTypes(
        address user,
        uint256[] calldata keys
    ) external view returns (StateType[] memory);
}
