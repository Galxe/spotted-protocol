// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/// @title State Manager Types Interface
/// @notice Defines types and structs used in the state management system
interface IStateManagerTypes {
    /// @notice Historical record of a value at a specific block
    struct History {
        uint256 value;    // slot 0: user-defined value
        uint64 blockNumber; // slot 1: [0-63] block number
        uint48 timestamp;  // slot 1: [64-111] unix timestamp
    }

    /// @notice Parameters for setting a value
    struct SetValueParams {
        uint256 key;      // The key to set
        uint256 value;    // The value to set
    }
}

/// @title State Manager Errors Interface
/// @notice Defines all error cases in the state management system
interface IStateManagerErrors {
    /// @notice Thrown when key does not exist
    error StateManager__KeyNotFound();
    /// @notice Thrown when block range is invalid
    error StateManager__InvalidBlockRange();
    /// @notice Thrown when block is not found
    error StateManager__BlockNotFound();
    /// @notice Thrown when index is out of bounds
    error StateManager__IndexOutOfBounds();
    /// @notice Thrown when no history is found
    error StateManager__NoHistoryFound();
    /// @notice Thrown when batch size exceeds limit
    error StateManager__BatchTooLarge();
}

/// @title State Manager Events Interface
/// @notice Defines all events emitted by the state management system
interface IStateManagerEvents {
    /// @notice Emitted when a new history entry is committed
    /// @param user The user address
    /// @param key The key being updated
    /// @param value The new value
    /// @param timestamp The block timestamp
    /// @param blockNumber The block number
    event HistoryCommitted(
        address indexed user,
        uint256 key,
        uint256 value,
        uint256 timestamp,
        uint256 blockNumber
    );
}

/// @title State Manager Interface
/// @author Spotted Team
/// @notice Interface for managing state history and value tracking
interface IStateManager is 
    IStateManagerTypes,
    IStateManagerErrors,
    IStateManagerEvents 
{
    /* STATE MANAGEMENT */

    /// @notice Sets a value for a specific key
    /// @param key The key to set the value for
    /// @param value The value to set
    function setValue(uint256 key, uint256 value) external;

    /// @notice Sets multiple values in a single transaction
    /// @param params Array of key-value pairs to set
    function batchSetValues(SetValueParams[] calldata params) external;

    /* BLOCK RANGE QUERIES */

    /// @notice Gets history between specified block numbers
    /// @param user The user address to query
    /// @param key The key to query
    /// @param fromBlock Start block number
    /// @param toBlock End block number
    /// @return Array of historical values
    function getHistoryBetweenBlockNumbers(
        address user,
        uint256 key,
        uint256 fromBlock,
        uint256 toBlock
    ) external view returns (History[] memory);

    /// @notice Gets history before or at a specified block number
    /// @param user The user address to query
    /// @param key The key to query
    /// @param blockNumber The block number to query before or at
    /// @return Array of historical values
    function getHistoryBeforeOrAtBlockNumber(
        address user,
        uint256 key,
        uint256 blockNumber
    ) external view returns (History[] memory);

    /// @notice Gets history after or at a specified block number
    /// @param user The user address to query
    /// @param key The key to query
    /// @param blockNumber The block number to query after or at
    /// @return Array of historical values
    function getHistoryAfterOrAtBlockNumber(
        address user,
        uint256 key,
        uint256 blockNumber
    ) external view returns (History[] memory);

    /* BLOCK SPECIFIC QUERIES */

    /// @notice Gets history at a specific block number
    /// @param user The user address to query
    /// @param key The key to query
    /// @param blockNumber The specific block number to query
    /// @return The historical value at the specified block
    function getHistoryAtBlock(
        address user,
        uint256 key,
        uint256 blockNumber
    ) external view returns (History memory);

    /* INDEX BASED QUERIES */

    /// @notice Gets history at a specific index
    /// @param user The user address to query
    /// @param key The key to query
    /// @param index The index in the history array
    /// @return The historical value at the specified index
    function getHistoryAt(
        address user,
        uint256 key,
        uint256 index
    ) external view returns (History memory);

    /* METADATA QUERIES */

    /// @notice Gets the total number of history entries for a user's key
    /// @param user The user address to query
    /// @param key The key to query
    /// @return The number of historical entries
    function getHistoryCount(
        address user,
        uint256 key
    ) external view returns (uint256);

    /* FULL HISTORY QUERIES */

    /// @notice Gets all history for a user's key
    /// @param user The user address to query
    /// @param key The key to query
    /// @return Array of all historical values
    function getHistory(
        address user,
        uint256 key
    ) external view returns (History[] memory);
}
