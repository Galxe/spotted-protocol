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

    // search type for binary search
    enum SearchType {
        BLOCK_NUMBER,
        TIMESTAMP
    }

    // history structure
    struct History {
        uint256 value; // slot 0: user-defined value
        uint64 blockNumber; // slot 1: [0-63] block number
        uint48 timestamp; // slot 1: [64-111] unix timestamp
    }

    // parameters for setting value
    struct SetValueParams {
        uint256 key;
        uint256 value;
    }

    // events
    event HistoryCommitted(
        address indexed user,
        uint256 indexed key,
        uint256 value,
        uint256 timestamp,
        uint256 blockNumber
    );

    // core functions
    function setValue(uint256 key, uint256 value) external;
    function batchSetValues(
        SetValueParams[] calldata params
    ) external;

    // query functions
    function getCurrentValue(address user, uint256 key) external view returns (uint256);
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
    function getCurrentValues(
        address user,
        uint256[] calldata keys
    ) external view returns (uint256[] memory values);
}
