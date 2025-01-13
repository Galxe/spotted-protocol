// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IEpochManager {
    enum MessageType {
        REGISTER,
        DEREGISTER,
        UPDATE_SIGNING_KEY,
        UPDATE_OPERATORS,
        UPDATE_QUORUM,
        UPDATE_MIN_WEIGHT,
        UPDATE_THRESHOLD,
        UPDATE_OPERATORS_QUORUM,
        BATCH_UPDATE,
        UPDATE_OPERATORS_FOR_QUORUM
    }

    struct StateUpdate {
        MessageType updateType;
        bytes data;
    }

    error EpochManager__InvalidEpochLength();
    error EpochManager__InvalidGracePeriod();
    error EpochManager__InvalidPeriodLength();
    error EpochManager__UpdateAlreadyProcessed();
    error EpochManager__UpdateNotAllowed();
    error EpochManager__InvalidEpochForUpdate();

    event StateUpdateQueued(uint32 indexed epoch, MessageType updateType, bytes data);
    event StateUpdatesSent(uint32 indexed epoch, uint256 updatesCount);

    // view functions
    function isInGracePeriod() external view returns (bool);
    function blocksUntilNextEpoch() external view returns (uint64);
    function blocksUntilGracePeriod() external view returns (uint64);
    function getEffectiveEpoch() external view returns (uint32);
    function getCurrentEpoch() external view returns (uint32);
    function getCurrentEpochBlock() external view returns (uint64);
    function getNextEpochBlock() external view returns (uint64);
    function getEpochInterval(
        uint32 epoch
    ) external view returns (uint64 startBlock, uint64 graceBlock, uint64 endBlock);
    function getEffectiveEpochForBlock(uint64 blockNumber) external view returns (uint32);

    // state modification functions
    function queueStateUpdate(MessageType updateType, bytes memory data) external;
    function sendStateUpdates(uint256 chainId) external payable;
}
