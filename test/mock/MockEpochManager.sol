// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IEpochManager} from "../../src/interfaces/IEpochManager.sol";

contract MockEpochManager is IEpochManager {
    uint32 private currentEpoch;
    uint64 private blockNumber;

    // Test helper functions
    function setCurrentEpoch(uint32 _epoch) external {
        currentEpoch = _epoch;
    }

    function setBlockNumber(uint64 _blockNumber) external {
        blockNumber = _blockNumber;
    }

    // Core functions
    function getCurrentEpoch() external view returns (uint32) {
        return currentEpoch;
    }

    function getEffectiveEpochForBlock(uint64 _blockNumber) external pure returns (uint32) {
        return uint32(_blockNumber / 45_000);
    }

    // Minimal implementations
    function isInGracePeriod() external pure returns (bool) {
        return false;
    }

    function blocksUntilNextEpoch() external pure returns (uint64) {
        return 0;
    }

    function getStartBlockForEpoch(uint32) external pure returns (uint64) {
        return 0;
    }

    function blocksUntilGracePeriod() external pure returns (uint64) {
        return 0;
    }

    function getEffectiveEpoch() external pure returns (uint32) {
        return 0;
    }

    function getCurrentEpochStartBlock() external pure returns (uint64) {
        return 0;
    }

    function getNextEpochStartBlock() external pure returns (uint64) {
        return 0;
    }

    function getEpochInterval(uint32) external pure returns (uint64, uint64, uint64) {
        return (0, 0, 0);
    }

    function snapshotAndSendState(
        address[] calldata operators,
        uint32 epochNumber,
        uint256 chainId
    ) external payable {
        emit StateSnapshotSent(epochNumber, chainId, operators);
    }

    // Constants
    function GENESIS_BLOCK() external pure returns (uint64) {
        return 0;
    }

    function EPOCH_LENGTH() external pure returns (uint64) {
        return 45_000;
    }

    function GRACE_PERIOD() external pure returns (uint64) {
        return 6400;
    }

    function REGISTRY_STATE_SENDER() external pure returns (address) {
        return address(1);
    }

    function STAKE_REGISTRY() external pure returns (address) {
        return address(2);
    }
}
