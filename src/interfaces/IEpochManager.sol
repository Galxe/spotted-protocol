// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IEpochManager {
    // 消息类型枚举
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

    // 状态更新结构
    struct StateUpdate {
        MessageType updateType;
        bytes data;
    }

    // 错误定义
    error EpochManager__InvalidEpochLength();
    error EpochManager__InvalidFreezePeriod();
    error EpochManager__EpochNotReady();
    error EpochManager__StillInFreezePeriod();
    error EpochManager__UpdateAlreadyProcessed();
    error EpochManager__UpdateNotAllowed();
    error EpochManager__InvalidEpochForUpdate();
    error EpochManager__NotInFreezePeriod();
    error EpochManager__InvalidEpochRevert();

    // 事件定义
    event EpochAdvanced(uint256 indexed epoch, uint256 lastEpochBlock, uint256 nextEpochBlock);

    event StateUpdateQueued(uint256 indexed epoch, MessageType updateType, bytes data);

    event StateUpdatesSent(uint256 indexed epoch, uint256 updatesCount);

    event EpochReverted(uint256 indexed epoch);

    // 视图函数
    function canAdvanceEpoch() external view returns (bool);
    function isInFreezePeriod() external view returns (bool);
    function blocksUntilNextEpoch() external view returns (uint256);
    function blocksUntilFreezePeriod() external view returns (uint256);
    function getCurrentEpoch() external view returns (uint256);
    function isUpdatable(
        uint256 targetEpoch
    ) external view returns (bool);
    function getEpochInterval(
        uint256 epoch
    ) external view returns (uint256 startBlock, uint256 freezeBlock, uint256 endBlock);
    function currentEpoch() external view returns (uint256);

    // 常量
    function EPOCH_LENGTH() external view returns (uint256);
    function FREEZE_PERIOD() external view returns (uint256);
    function REGISTRY_STATE_SENDER() external view returns (address);

    // 状态变量
    function lastEpochBlock() external view returns (uint256);
    function nextEpochBlock() external view returns (uint256);
    function lastUpdatedEpoch() external view returns (uint256);
    function epochBlocks(
        uint256 epoch
    ) external view returns (uint256);
    function epochUpdateCounts(
        uint256 epoch
    ) external view returns (uint256);

    // 状态修改函数
    function advanceEpoch() external;
    function revertEpoch(
        uint256 epoch
    ) external;
    function queueStateUpdate(MessageType updateType, bytes memory data) external;
    function sendStateUpdates(
        uint256 chainId
    ) external payable;
}
