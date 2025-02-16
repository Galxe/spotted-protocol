// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IStateManager {
    // Errors
    error StateManager__KeyNotFound();
    error StateManager__InvalidBlockRange();
    error StateManager__BlockNotFound();
    error StateManager__IndexOutOfBounds();
    error StateManager__NoHistoryFound();
    error StateManager__BatchTooLarge();

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
        uint256 key,
        uint256 value,
        uint256 timestamp,
        uint256 blockNumber
    );

    // core functions
    function setValue(uint256 key, uint256 value) external;
    function batchSetValues(SetValueParams[] calldata params) external;

    // query functions
    function getHistoryBetweenBlockNumbers(
        address user,
        uint256 key,
        uint256 fromBlock,
        uint256 toBlock
    ) external view returns (History[] memory);
    
    function getHistoryBeforeOrAtBlockNumber(
        address user,
        uint256 key,
        uint256 blockNumber
    ) external view returns (History[] memory);
    
    function getHistoryAfterOrAtBlockNumber(
        address user,
        uint256 key,
        uint256 blockNumber
    ) external view returns (History[] memory);
    
    function getHistoryAtBlock(
        address user,
        uint256 key,
        uint256 blockNumber
    ) external view returns (History memory);
    
    function getHistoryCount(address user, uint256 key) external view returns (uint256);
    
    function getHistoryAt(
        address user,
        uint256 key,
        uint256 index
    ) external view returns (History memory);
    
    function getHistory(address user, uint256 key) external view returns (History[] memory);
}
