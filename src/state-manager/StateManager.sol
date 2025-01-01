// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../interfaces/IStateManager.sol";

contract StateManager is IStateManager {
    // constants
    uint256 private constant MAX_BATCH_SIZE = 100; // maximum batch size per transaction

    // current value storage: user -> key -> ValueInfo
    mapping(address user => mapping(uint256 key => ValueInfo)) private currentValues;

    // history storage grouped by key: user -> key -> history[]
    mapping(address user => mapping(uint256 key => History[])) private histories;

    // keys used by user
    mapping(address user => uint256[]) private userKeys;

    function setValue(uint256 key, uint256 value, StateType stateType) external {
        ValueInfo storage currentValue = currentValues[msg.sender][key];

        // state validation
        if (currentValue.exists) {
            // immutable check
            if (StateType(currentValue.stateType) == StateType.IMMUTABLE) {
                revert StateManager__ImmutableStateCannotBeModified();
            }

            // monotonic check
            if (
                StateType(currentValue.stateType) == StateType.MONOTONIC_INCREASING
                    && value <= currentValue.value
            ) {
                revert StateManager__ValueNotMonotonicIncreasing();
            }
            if (
                StateType(currentValue.stateType) == StateType.MONOTONIC_DECREASING
                    && value >= currentValue.value
            ) {
                revert StateManager__ValueNotMonotonicDecreasing();
            }
        }

        // record new key
        if (!currentValue.exists) {
            userKeys[msg.sender].push(key);
        }

        // update current value
        currentValue.value = value;
        currentValue.stateType = uint8(stateType);
        currentValue.exists = true;

        // add history record
        History[] storage keyHistory = histories[msg.sender][key];
        uint256 currentNonce = keyHistory.length;

        keyHistory.push(
            History({
                value: value,
                blockNumber: uint64(block.number),
                timestamp: uint32(block.timestamp),
                nonce: uint32(currentNonce),
                stateType: uint8(stateType)
            })
        );

        emit HistoryCommitted(
            msg.sender, key, value, block.timestamp, block.number, currentNonce, stateType
        );
    }

    function batchSetValues(
        SetValueParams[] calldata params
    ) external {
        uint256 length = params.length;
        if (length > MAX_BATCH_SIZE) {
            revert StateManager__BatchTooLarge();
        }

        for (uint256 i = 0; i < length; ++i) {
            SetValueParams calldata param = params[i];
            ValueInfo storage currentValue = currentValues[msg.sender][param.key];

            // state validation
            if (currentValue.exists) {
                // immutable check
                if (StateType(currentValue.stateType) == StateType.IMMUTABLE) {
                    revert StateManager__ImmutableStateCannotBeModified();
                }

                // monotonic check
                if (
                    StateType(currentValue.stateType) == StateType.MONOTONIC_INCREASING
                        && param.value <= currentValue.value
                ) {
                    revert StateManager__ValueNotMonotonicIncreasing();
                }
                if (
                    StateType(currentValue.stateType) == StateType.MONOTONIC_DECREASING
                        && param.value >= currentValue.value
                ) {
                    revert StateManager__ValueNotMonotonicDecreasing();
                }
            }

            // record new key
            if (!currentValue.exists) {
                userKeys[msg.sender].push(param.key);
            }

            // update current value
            currentValue.value = param.value;
            currentValue.stateType = uint8(param.stateType);
            currentValue.exists = true;

            // add history record
            History[] storage keyHistory = histories[msg.sender][param.key];
            uint256 currentNonce = keyHistory.length;

            keyHistory.push(
                History({
                    value: param.value,
                    blockNumber: uint64(block.number),
                    timestamp: uint32(block.timestamp),
                    nonce: uint32(currentNonce),
                    stateType: uint8(param.stateType)
                })
            );

            emit HistoryCommitted(
                msg.sender,
                param.key,
                param.value,
                block.timestamp,
                block.number,
                currentNonce,
                param.stateType
            );
        }
    }
    // get current value and state type

    function getCurrentValue(address user, uint256 key) external view returns (ValueInfo memory) {
        return currentValues[user][key];
    }

    function getUsedKeys(
        address user
    ) external view returns (uint256[] memory) {
        return userKeys[user];
    }

    // common binary search function
    function _binarySearch(
        History[] storage history,
        uint256 target,
        SearchType searchType
    ) private view returns (uint256) {
        if (history.length == 0) {
            return 0;
        }

        uint256 high = history.length;
        uint256 low = 0;

        while (low < high) {
            uint256 mid = Math.average(low, high);
            uint256 current = searchType == SearchType.BLOCK_NUMBER
                ? history[mid].blockNumber
                : history[mid].timestamp;

            if (current > target) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        // return the last position less than or equal to target
        return high == 0 ? 0 : high - 1;
    }

    // optimized getHistoryBetween using common binary search
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
        uint256 startIndex = _binarySearch(keyHistory, fromBlock, SearchType.BLOCK_NUMBER);
        if (startIndex >= keyHistory.length) {
            startIndex = keyHistory.length - 1;
        }
        // if the block number at current position is less than fromBlock, move to next position
        if (keyHistory[startIndex].blockNumber < fromBlock && startIndex < keyHistory.length - 1) {
            startIndex++;
        }

        // find the last position less than or equal to toBlock
        uint256 endIndex = _binarySearch(keyHistory, toBlock, SearchType.BLOCK_NUMBER);
        if (endIndex >= keyHistory.length) {
            endIndex = keyHistory.length - 1;
        }

        // check if the range is valid
        if (startIndex > endIndex || keyHistory[startIndex].blockNumber >= toBlock) {
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

    function getHistoryBetweenTimestamps(
        address user,
        uint256 key,
        uint256 fromTimestamp,
        uint256 toTimestamp
    ) external view returns (History[] memory) {
        if (fromTimestamp >= toTimestamp) {
            revert StateManager__InvalidTimeRange();
        }

        History[] storage keyHistory = histories[user][key];
        if (keyHistory.length == 0) {
            revert StateManager__NoHistoryFound();
        }

        // find the first position greater than or equal to fromTimestamp
        uint256 startIndex = _binarySearch(keyHistory, fromTimestamp, SearchType.TIMESTAMP);
        if (startIndex >= keyHistory.length) {
            startIndex = keyHistory.length - 1;
        }
        // if the timestamp at current position is less than fromTimestamp, move to next position
        if (keyHistory[startIndex].timestamp < fromTimestamp && startIndex < keyHistory.length - 1)
        {
            startIndex++;
        }

        // find the last position less than or equal to toTimestamp
        uint256 endIndex = _binarySearch(keyHistory, toTimestamp, SearchType.TIMESTAMP);
        if (endIndex >= keyHistory.length) {
            endIndex = keyHistory.length - 1;
        }

        // check if the range is valid
        if (startIndex > endIndex || keyHistory[startIndex].timestamp >= toTimestamp) {
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

    function getHistoryBeforeBlockNumber(
        address user,
        uint256 key,
        uint256 blockNumber
    ) external view returns (History[] memory) {
        History[] storage keyHistory = histories[user][key];
        if (keyHistory.length == 0) {
            revert StateManager__NoHistoryFound();
        }

        // find the end position using binary search
        uint256 endIndex = _binarySearch(keyHistory, blockNumber, SearchType.BLOCK_NUMBER);
        if (endIndex == 0) {
            revert StateManager__NoHistoryFound();
        }

        // create result array
        History[] memory result = new History[](endIndex);

        // copy result
        for (uint256 i = 0; i < endIndex; i++) {
            result[i] = keyHistory[i];
        }

        return result;
    }

    function getHistoryAfterBlockNumber(
        address user,
        uint256 key,
        uint256 blockNumber
    ) external view returns (History[] memory) {
        History[] storage keyHistory = histories[user][key];
        if (keyHistory.length == 0) {
            revert StateManager__NoHistoryFound();
        }

        // find the end position using binary search
        uint256 index = _binarySearch(keyHistory, blockNumber, SearchType.BLOCK_NUMBER);

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

    function getHistoryBeforeTimestamp(
        address user,
        uint256 key,
        uint256 timestamp
    ) external view returns (History[] memory) {
        History[] storage keyHistory = histories[user][key];
        if (keyHistory.length == 0) {
            revert StateManager__NoHistoryFound();
        }

        // find the end position using binary search
        uint256 endIndex = _binarySearch(keyHistory, timestamp, SearchType.TIMESTAMP);
        if (endIndex == 0) {
            revert StateManager__NoHistoryFound();
        }

        // create result array
        History[] memory result = new History[](endIndex);

        // copy result
        for (uint256 i = 0; i < endIndex; i++) {
            result[i] = keyHistory[i];
        }

        return result;
    }

    // 使用通用二分查找优化的getHistoryAfterTimestamp
    function getHistoryAfterTimestamp(
        address user,
        uint256 key,
        uint256 timestamp
    ) external view returns (History[] memory) {
        History[] storage keyHistory = histories[user][key];
        if (keyHistory.length == 0) {
            revert StateManager__NoHistoryFound();
        }

        // find the end position using binary search
        uint256 index = _binarySearch(keyHistory, timestamp, SearchType.TIMESTAMP);

        // if index is the last element, all elements are less than or equal to timestamp
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

    function getHistoryAtBlock(
        address user,
        uint256 key,
        uint256 blockNumber
    ) external view returns (History memory) {
        History[] storage keyHistory = histories[user][key];
        if (keyHistory.length == 0) {
            revert StateManager__NoHistoryFound();
        }

        uint256 index = _binarySearch(keyHistory, blockNumber, SearchType.BLOCK_NUMBER);
        // check if the found position is exactly equal to the target block number
        if (index >= keyHistory.length || keyHistory[index].blockNumber != blockNumber) {
            revert StateManager__BlockNotFound();
        }

        return keyHistory[index];
    }

    function getHistoryAtTimestamp(
        address user,
        uint256 key,
        uint256 timestamp
    ) external view returns (History memory) {
        History[] storage keyHistory = histories[user][key];
        if (keyHistory.length == 0) {
            revert StateManager__NoHistoryFound();
        }

        uint256 index = _binarySearch(keyHistory, timestamp, SearchType.TIMESTAMP);
        if (index >= keyHistory.length || keyHistory[index].timestamp != timestamp) {
            revert StateManager__TimestampNotFound();
        }

        return keyHistory[index];
    }

    function getHistoryCount(address user, uint256 key) external view returns (uint256) {
        return histories[user][key].length;
    }

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

    // get latest N history records
    function getLatestHistory(address user, uint256 n) external view returns (History[] memory) {
        uint256[] storage keys = userKeys[user];
        if (keys.length == 0) {
            revert StateManager__NoHistoryFound();
        }

        // calculate total history count
        uint256 totalHistoryCount = 0;
        for (uint256 i = 0; i < keys.length; i++) {
            totalHistoryCount += histories[user][keys[i]].length;
        }

        // determine actual return count
        uint256 count = n > totalHistoryCount ? totalHistoryCount : n;
        if (count == 0) {
            revert StateManager__NoHistoryFound();
        }

        History[] memory result = new History[](count);
        uint256 resultIndex = 0;

        // collect from latest records
        for (uint256 i = 0; i < keys.length && resultIndex < count; i++) {
            History[] storage keyHistory = histories[user][keys[i]];
            uint256 keyHistoryLength = keyHistory.length;

            for (uint256 j = 0; j < keyHistoryLength && resultIndex < count; j++) {
                result[resultIndex] = keyHistory[keyHistoryLength - 1 - j];
                resultIndex++;
            }
        }

        return result;
    }

    // check if the value is greater than input value at a specific block number for monotonic increasing state
    function checkIncreasingValueAtBlock(
        address user,
        uint256 key,
        uint256 blockNumber,
        uint256 checkValue
    ) external view returns (bool) {
        // check if the state type is correct
        ValueInfo memory currentValue = currentValues[user][key];
        if (!currentValue.exists || currentValue.stateType != uint8(StateType.MONOTONIC_INCREASING))
        {
            revert StateManager__InvalidStateType();
        }

        History[] storage keyHistory = histories[user][key];
        uint256 index = _binarySearch(keyHistory, blockNumber, SearchType.BLOCK_NUMBER);
        if (index > 0) {
            index = index - 1;
        }

        History memory record = keyHistory[index];
        return record.value > checkValue;
    }

    // check if the value is less than input value at a specific block number for monotonic decreasing state
    function checkDecreasingValueAtBlock(
        address user,
        uint256 key,
        uint256 blockNumber,
        uint256 checkValue
    ) external view returns (bool) {
        // check if the state type is correct
        ValueInfo memory currentValue = currentValues[user][key];
        if (!currentValue.exists || currentValue.stateType != uint8(StateType.MONOTONIC_DECREASING))
        {
            revert StateManager__InvalidStateType();
        }

        History[] storage keyHistory = histories[user][key];
        uint256 index = _binarySearch(keyHistory, blockNumber, SearchType.BLOCK_NUMBER);
        if (index > 0) {
            index = index - 1;
        }

        History memory record = keyHistory[index];
        return record.value < checkValue;
    }

    // check if the value is greater than input value at a specific timestamp for monotonic increasing state
    function checkIncreasingValueAtTimestamp(
        address user,
        uint256 key,
        uint256 timestamp,
        uint256 checkValue
    ) external view returns (bool) {
        // check if the state type is correct
        ValueInfo memory currentValue = currentValues[user][key];
        if (!currentValue.exists || currentValue.stateType != uint8(StateType.MONOTONIC_INCREASING))
        {
            revert StateManager__InvalidStateType();
        }

        History[] storage keyHistory = histories[user][key];
        uint256 index = _binarySearch(keyHistory, timestamp, SearchType.TIMESTAMP);
        if (index > 0) {
            index = index - 1;
        }

        History memory record = keyHistory[index];
        return record.value > checkValue;
    }

    // check if the value is less than input value at a specific timestamp for monotonic decreasing state
    function checkDecreasingValueAtTimestamp(
        address user,
        uint256 key,
        uint256 timestamp,
        uint256 checkValue
    ) external view returns (bool) {
        // check if the state type is correct
        ValueInfo memory currentValue = currentValues[user][key];
        if (!currentValue.exists || currentValue.stateType != uint8(StateType.MONOTONIC_DECREASING))
        {
            revert StateManager__InvalidStateType();
        }

        History[] storage keyHistory = histories[user][key];
        uint256 index = _binarySearch(keyHistory, timestamp, SearchType.TIMESTAMP);
        if (index > 0) {
            index = index - 1;
        }

        History memory record = keyHistory[index];
        return record.value < checkValue;
    }

    // batch get current values of multiple keys
    function getCurrentValues(
        address user,
        uint256[] calldata keys
    ) external view returns (ValueInfo[] memory values) {
        values = new ValueInfo[](keys.length);
        for (uint256 i = 0; i < keys.length; i++) {
            values[i] = currentValues[user][keys[i]];
        }
        return values;
    }

    // check state types of a group of keys
    function checkKeysStateTypes(
        address user,
        uint256[] calldata keys
    ) external view returns (StateType[] memory) {
        StateType[] memory types = new StateType[](keys.length);

        for (uint256 i = 0; i < keys.length; i++) {
            ValueInfo memory info = currentValues[user][keys[i]];
            types[i] = info.exists ? StateType(info.stateType) : StateType.IMMUTABLE;
        }

        return types;
    }
}
