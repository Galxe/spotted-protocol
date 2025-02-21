// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../interfaces/IStateManager.sol";

/// @title State Manager
/// @author Spotted Team
/// @notice Manages state history and value tracking for users
/// @dev Implements value storage with historical tracking by block number and timestamp
contract StateManager is IStateManager {
    /// @notice Maximum number of values that can be set in a single batch transaction
    /// @dev Prevents excessive gas consumption in batch operations
    uint256 private constant MAX_BATCH_SIZE = 100;

    /// @notice Historical values stored per user and key
    /// @dev Maps user address to key to array of historical values
    mapping(address user => mapping(uint256 key => History[])) private histories;

    /// @notice Sets a value for a specific key
    /// @param key The key to set the value for
    /// @param value The value to set
    /// @dev Records history and emits HistoryCommitted event
    function setValue(uint256 key, uint256 value) external {
        // add history record
        History[] storage keyHistory = histories[msg.sender][key];

        keyHistory.push(
            History({
                value: value,
                blockNumber: uint64(block.number),
                timestamp: uint48(block.timestamp)
            })
        );

        emit HistoryCommitted(msg.sender, key, value, block.timestamp, block.number);
    }

    /// @notice Sets multiple values in a single transaction
    /// @param params Array of key-value pairs to set
    /// @dev Enforces MAX_BATCH_SIZE limit
    function batchSetValues(
        SetValueParams[] calldata params
    ) external {
        uint256 length = params.length;
        if (length > MAX_BATCH_SIZE) {
            revert StateManager__BatchTooLarge();
        }

        for (uint256 i = 0; i < length;) {
            SetValueParams calldata param = params[i];

            // add history record
            History[] storage keyHistory = histories[msg.sender][param.key];

            keyHistory.push(
                History({
                    value: param.value,
                    blockNumber: uint64(block.number),
                    timestamp: uint48(block.timestamp)
                })
            );

            emit HistoryCommitted(msg.sender, param.key, param.value, block.timestamp, block.number);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Internal binary search function
    /// @param history Array of historical values to search
    /// @param targetBlock Target block number to search for
    /// @return Index of the found position
    /// @dev Returns the last position less than or equal to target block
    function _binarySearch(
        History[] storage history,
        uint256 targetBlock
    ) private view returns (uint256) {
        if (history.length == 0) {
            return 0;
        }

        uint256 high = history.length;
        uint256 low = 0;

        while (low < high) {
            uint256 mid = Math.average(low, high);
            uint256 currentBlock = history[mid].blockNumber;

            if (currentBlock > targetBlock) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        // return the last position less than or equal to target
        return high == 0 ? 0 : high - 1;
    }

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
    ) external view returns (History[] memory) {
        if (fromBlock >= toBlock) {
            revert StateManager__InvalidBlockRange();
        }

        History[] storage keyHistory = histories[user][key];
        if (keyHistory.length == 0) {
            revert StateManager__NoHistoryFound();
        }

        // find the first position greater than or equal to fromBlock
        uint256 startIndex = _binarySearch(keyHistory, fromBlock);
        if (startIndex >= keyHistory.length) {
            startIndex = keyHistory.length - 1;
        }
        // if the block number at current position is less than fromBlock, move to next position
        if (keyHistory[startIndex].blockNumber < fromBlock && startIndex < keyHistory.length - 1) {
            startIndex++;
        }

        // find the last position less than or equal to toBlock
        uint256 endIndex = _binarySearch(keyHistory, toBlock);
        if (endIndex >= keyHistory.length) {
            endIndex = keyHistory.length - 1;
        }

        // check if the range is valid and contains records
        if (
            startIndex > endIndex || keyHistory[startIndex].blockNumber >= toBlock
                || keyHistory[endIndex].blockNumber < fromBlock
        ) {
            revert StateManager__NoHistoryFound();
        }

        // create result array
        uint256 count = endIndex - startIndex + 1;
        History[] memory result = new History[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = keyHistory[startIndex + i];
        }

        return result;
    }

    /// @notice Gets history before or at a specified block number
    /// @param user The user address to query
    /// @param key The key to query
    /// @param blockNumber The block number to query before or at
    /// @return Array of historical values before or at the specified block
    function getHistoryBeforeOrAtBlockNumber(
        address user,
        uint256 key,
        uint256 blockNumber
    ) external view returns (History[] memory) {
        History[] storage keyHistory = histories[user][key];
        if (keyHistory.length == 0) {
            revert StateManager__NoHistoryFound();
        }

        // find the end position using binary search
        uint256 endIndex = _binarySearch(keyHistory, blockNumber);
        if (endIndex == 0) {
            revert StateManager__NoHistoryFound();
        }

        // create result array
        History[] memory result = new History[](endIndex + 1);

        // copy result
        for (uint256 i = 0; i <= endIndex; i++) {
            result[i] = keyHistory[i];
        }

        return result;
    }

    /// @notice Gets history after or at a specified block number
    /// @param user The user address to query
    /// @param key The key to query
    /// @param blockNumber The block number to query after or at
    /// @return Array of historical values after or at the specified block
    function getHistoryAfterOrAtBlockNumber(
        address user,
        uint256 key,
        uint256 blockNumber
    ) external view returns (History[] memory) {
        History[] storage keyHistory = histories[user][key];
        if (keyHistory.length == 0) {
            revert StateManager__NoHistoryFound();
        }

        // find the end position using binary search
        uint256 index = _binarySearch(keyHistory, blockNumber);

        // if index is the last element, all elements are less than or equal to blockNumber
        if (index >= keyHistory.length - 1) {
            revert StateManager__NoHistoryFound();
        }

        // return from next position
        uint256 startIndex = index + 1;
        uint256 count = keyHistory.length - startIndex;

        History[] memory result = new History[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = keyHistory[startIndex + i];
        }

        return result;
    }

    /// @notice Gets history at a specific block number
    /// @param user The user address to query
    /// @param key The key to query
    /// @param blockNumber The specific block number to query
    /// @return History The historical value at the specified block
    function getHistoryAtBlock(
        address user,
        uint256 key,
        uint256 blockNumber
    ) external view returns (History memory) {
        History[] storage keyHistory = histories[user][key];
        if (keyHistory.length == 0) {
            revert StateManager__NoHistoryFound();
        }

        uint256 index = _binarySearch(keyHistory, blockNumber);
        // if index is valid and the block number at index is less than or equal to target
        if (index < keyHistory.length && keyHistory[index].blockNumber <= blockNumber) {
            return keyHistory[index];
        }
        // if no valid history found before or at the target block
        revert StateManager__BlockNotFound();
    }

    /// @notice Gets the total number of history entries for a user's key
    /// @param user The user address to query
    /// @param key The key to query
    /// @return uint256 The number of historical entries
    function getHistoryCount(address user, uint256 key) external view returns (uint256) {
        return histories[user][key].length;
    }

    /// @notice Gets history at a specific index
    /// @param user The user address to query
    /// @param key The key to query
    /// @param index The index in the history array
    /// @return History The historical value at the specified index
    function getHistoryAt(
        address user,
        uint256 key,
        uint256 index
    ) external view returns (History memory) {
        History[] storage keyHistory = histories[user][key];
        if (index >= keyHistory.length) {
            revert StateManager__IndexOutOfBounds();
        }
        return keyHistory[index];
    }

    /// @notice Gets all history for a user's key
    /// @param user The user address to query
    /// @param key The key to query
    /// @return Array of all historical values
    function getHistory(address user, uint256 key) external view returns (History[] memory) {
        return histories[user][key];
    }
}
