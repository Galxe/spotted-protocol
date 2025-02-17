// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IStateManager} from "../../src/interfaces/IStateManager.sol";

contract MockStateManager is IStateManager {
    bool public shouldRevert;
    mapping(bytes32 => History) private histories;

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function setHistoryAtBlock(
        address user,
        uint256 key,
        uint256 blockNumber,
        uint256 value
    ) external {
        bytes32 historyKey = keccak256(abi.encodePacked(user, key, blockNumber));
        histories[historyKey] = History({
            value: value,
            blockNumber: uint64(blockNumber),
            timestamp: uint48(block.timestamp)
        });
    }

    function setValue(uint256 key, uint256 value) external {
        if (shouldRevert) revert("MockStateManager: setValue reverted");
    }

    function batchSetValues(SetValueParams[] calldata params) external {
        if (shouldRevert) revert("MockStateManager: batchSetValues reverted");
    }

    function getHistoryBetweenBlockNumbers(
        address user,
        uint256 key,
        uint256 fromBlock,
        uint256 toBlock
    ) external view returns (History[] memory) {
        if (shouldRevert) revert("MockStateManager: getHistoryBetweenBlockNumbers reverted");
        revert("Not implemented");
    }

    function getHistoryBeforeOrAtBlockNumber(
        address user,
        uint256 key,
        uint256 blockNumber
    ) external view returns (History[] memory) {
        if (shouldRevert) revert("MockStateManager: getHistoryBeforeOrAtBlockNumber reverted");
        revert("Not implemented");
    }

    function getHistoryAfterOrAtBlockNumber(
        address user,
        uint256 key,
        uint256 blockNumber
    ) external view returns (History[] memory) {
        if (shouldRevert) revert("MockStateManager: getHistoryAfterOrAtBlockNumber reverted");
        revert("Not implemented");
    }

    function getHistoryAtBlock(
        address user,
        uint256 key,
        uint256 blockNumber
    ) external view returns (History memory) {
        if (shouldRevert) revert("MockStateManager: getHistoryAtBlock reverted");
        bytes32 historyKey = keccak256(abi.encodePacked(user, key, blockNumber));
        return histories[historyKey];
    }

    function getHistoryCount(address user, uint256 key) external view returns (uint256) {
        if (shouldRevert) revert("MockStateManager: getHistoryCount reverted");
        return 0;
    }

    function getHistoryAt(
        address user,
        uint256 key,
        uint256 index
    ) external view returns (History memory) {
        if (shouldRevert) revert("MockStateManager: getHistoryAt reverted");
        revert("Not implemented");
    }

    function getHistory(address user, uint256 key) external view returns (History[] memory) {
        if (shouldRevert) revert("MockStateManager: getHistory reverted");
        revert("Not implemented");
    }
} 