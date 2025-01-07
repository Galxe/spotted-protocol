// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import {IEpochManager} from "../interfaces/IEpochManager.sol";
import {IRegistryStateSender} from "../interfaces/IRegistryStateSender.sol";

/// @title Epoch Manager
/// @author Spotted Team
/// @notice Manages epoch transitions and state updates for the AVS system
/// @dev Handles epoch advancement, grace periods, and state synchronization
contract EpochManager is IEpochManager, OwnableUpgradeable {
    /// @notice Length of each epoch in blocks (approximately 7 days)
    /// @dev Immutable after deployment
    uint256 public immutable EPOCH_LENGTH = 45000;

    /// @notice Grace period duration in blocks (approximately 1 day)
    /// @dev Immutable after deployment, must be less than EPOCH_LENGTH
    uint256 public immutable GRACE_PERIOD = 6400;

    /// @notice Address of the registry state sender contract
    /// @dev Immutable after deployment
    address public immutable REGISTRY_STATE_SENDER;

    /// @notice Current epoch number
    uint256 public currentEpoch;

    /// @notice Block number when the last epoch started
    uint256 public lastEpochBlock;

    /// @notice Block number when the next epoch will start
    uint256 public nextEpochBlock;

    /// @notice Last epoch that was updated
    uint256 public lastUpdatedEpoch;

    /// @notice Mapping of actual block numbers for each epoch
    mapping(uint256 => uint256) public epochBlocks;

    /// @notice State updates for each epoch
    mapping(uint256 => StateUpdate[]) internal epochUpdates;

    /// @notice Number of updates for each epoch
    mapping(uint256 => uint256) public epochUpdateCounts;

    /// @notice Initializes the contract with required parameters
    /// @param _registryStateSender Address of the registry state sender contract
    constructor(address _registryStateSender) {
        lastEpochBlock = block.number;
        nextEpochBlock = block.number + EPOCH_LENGTH;
        currentEpoch = 0;
        REGISTRY_STATE_SENDER = _registryStateSender;
    }

    /// @notice Sends state updates to specified chain
    /// @param chainId The ID of the target chain
    /// @dev Requires payment for cross-chain message fees
    function sendStateUpdates(uint256 chainId) external payable {
        uint256 targetEpoch = currentEpoch;
        StateUpdate[] storage updates = epochUpdates[targetEpoch];

        // only process if there are updates
        if (updates.length > 0) {
            // record update count
            epochUpdateCounts[targetEpoch] = updates.length;

            // send batch updates via RegistryStateSender
            IRegistryStateSender(REGISTRY_STATE_SENDER).sendBatchUpdates{value: msg.value}(
                targetEpoch,
                chainId,
                updates
            );

            emit StateUpdatesSent(targetEpoch, updates.length);
        }
    }

    /// @notice Advances to the next epoch
    /// @dev Can only be called when canAdvanceEpoch returns true
    function advanceEpoch() external {
        if (!canAdvanceEpoch()) revert EpochManager__EpochNotReady();

        lastEpochBlock = nextEpochBlock;
        nextEpochBlock = lastEpochBlock + EPOCH_LENGTH;
        currentEpoch++;

        emit EpochAdvanced(currentEpoch, lastEpochBlock, nextEpochBlock);
    }

    /// @notice Gets remaining blocks until next epoch
    /// @return uint256 Number of blocks until next epoch
    function blocksUntilNextEpoch() external view returns (uint256) {
        if (block.number >= nextEpochBlock) return 0;
        return nextEpochBlock - block.number;
    }

    /// @notice Gets remaining blocks until grace period
    /// @return uint256 Number of blocks until grace period starts
    function blocksUntilGracePeriod() external view returns (uint256) {
        uint256 graceStart = nextEpochBlock - GRACE_PERIOD;
        if (block.number >= graceStart) return 0;
        return graceStart - block.number;
    }

    /// @notice Gets effective epoch for state updates
    /// @return uint256 The epoch number where updates will take effect
    /// @dev Returns current epoch + 2 during grace period, current epoch + 1 otherwise
    function getEffectiveEpoch() public view returns (uint256) {
        if (isInGracePeriod()) {
            return currentEpoch + 2;
        }
        return currentEpoch + 1;
    }

    /// @notice Queues a state update
    /// @param updateType Type of update to queue
    /// @param data Encoded update data
    function queueStateUpdate(MessageType updateType, bytes memory data) external {
        uint256 targetEpoch = getEffectiveEpoch();
        
        epochUpdates[targetEpoch].push(StateUpdate({
            updateType: updateType,
            data: data
        }));

        emit StateUpdateQueued(targetEpoch, updateType, data);
    }

    /// @notice Gets epoch interval details
    /// @param epoch The epoch number to query
    /// @return startBlock Start block of the epoch
    /// @return graceBlock Block when grace period starts
    /// @return endBlock End block of the epoch
    function getEpochInterval(
        uint256 epoch
    ) external view returns (uint256 startBlock, uint256 graceBlock, uint256 endBlock) {
        if (epochBlocks[epoch] != 0) {
            startBlock = epochBlocks[epoch];
            endBlock = startBlock + EPOCH_LENGTH;
            graceBlock = endBlock - GRACE_PERIOD;
            return (startBlock, graceBlock, endBlock);
        }

        startBlock = lastEpochBlock + ((epoch - currentEpoch) * EPOCH_LENGTH);
        endBlock = startBlock + EPOCH_LENGTH;
        graceBlock = endBlock - GRACE_PERIOD;
    }

    /// @notice Validates period configuration
    /// @param _epochLength Length of epoch in blocks
    /// @param _lockPeriod Length of lock period in blocks
    /// @param _gracePeriod Length of grace period in blocks
    /// @dev Internal function to validate period lengths
    function _validatePeriods(
        uint256 _epochLength,
        uint256 _lockPeriod,
        uint256 _gracePeriod
    ) internal pure {
        if (_epochLength != _lockPeriod) revert EpochManager__InvalidPeriodLength();
        if (_gracePeriod >= _epochLength) revert EpochManager__InvalidGracePeriod();
    }

    /// @notice Reverts to previous epoch
    /// @param epoch The epoch number to revert from
    /// @dev Only callable by owner, must be current epoch
    function revertEpoch(uint256 epoch) external onlyOwner {
        if (epoch != currentEpoch) revert EpochManager__InvalidEpochRevert();

        currentEpoch--;
        nextEpochBlock = lastEpochBlock + EPOCH_LENGTH;
        lastEpochBlock = lastEpochBlock - EPOCH_LENGTH;

        emit EpochReverted(epoch);
    }

    /// @notice Checks if the epoch can be advanced
    /// @return bool True if current block number is greater than or equal to next epoch block
    function canAdvanceEpoch() public view returns (bool) {
        return block.number >= nextEpochBlock;
    }

    /// @notice Checks if currently in grace period
    /// @return bool True if current block is within grace period
    function isInGracePeriod() public view returns (bool) {
        uint256 currentBlock = block.number;
        uint256 epochEndBlock = nextEpochBlock;
        return currentBlock >= epochEndBlock - GRACE_PERIOD;
    }

    /// @notice Checks if epoch can be updated
    /// @param targetEpoch The epoch number to check
    /// @return bool True if epoch can be updated
    function isUpdatable(uint256 targetEpoch) public view returns (bool) {
        return targetEpoch == getEffectiveEpoch();
    }

    /// @notice Calculates current epoch based on block number
    /// @return uint256 The current epoch number
    function getCurrentEpoch() public view returns (uint256) {
        return (block.number - lastEpochBlock) / EPOCH_LENGTH + currentEpoch;
    }


}
