// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IEpochManager} from "../../src/interfaces/IEpochManager.sol";

abstract contract MockEpochManager is IEpochManager {
    uint32 private currentEpoch;
    uint64 private blockNumber;

    function setCurrentEpoch(uint32 _epoch) external {
        currentEpoch = _epoch;
    }

    function setBlockNumber(uint64 _blockNumber) external {
        blockNumber = _blockNumber;
    }

    function getCurrentEpoch() external view returns (uint32) {
        return currentEpoch;
    }

    function getEffectiveEpochForBlock(uint64 _blockNumber) external pure returns (uint32) {
        return uint32(_blockNumber / 45000); // Using same logic as EpochManager
    }

    // Unused interface functions
    function isInGracePeriod() external pure returns (bool) { return false; }
    function blocksUntilNextEpoch() external pure returns (uint64) { return 0; }
    function getStartBlockForEpoch(uint32) external pure returns (uint64) { return 0; }
    function blocksUntilGracePeriod() external pure returns (uint64) { return 0; }
    function getEffectiveEpoch() external pure returns (uint32) { return 0; }
    function getCurrentEpochBlock() external pure returns (uint64) { return 0; }
    function getNextEpochBlock() external pure returns (uint64) { return 0; }
    function getEpochInterval(uint32) external pure returns (uint64, uint64, uint64) { return (0,0,0); }
    function queueStateUpdate(MessageType, bytes memory) external {}
    function sendStateUpdates(uint256) external payable {}
} 