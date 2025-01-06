// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import {IEpochManager} from "../interfaces/IEpochManager.sol";
import {IRegistryStateSender} from "../interfaces/IRegistryStateSender.sol";

contract EpochManager is IEpochManager, OwnableUpgradeable {
    // constants (in blocks)
    uint256 public immutable EPOCH_LENGTH = 45_000; // ~7 days
    uint256 public immutable FREEZE_PERIOD = 6400; // ~1 day
    address public immutable REGISTRY_STATE_SENDER;

    // state variables
    uint256 public currentEpoch; // current epoch number
    uint256 public lastEpochBlock; // block number when last epoch started
    uint256 public nextEpochBlock; // block number when next epoch will start
    uint256 public lastUpdatedEpoch; // last epoch that was updated

    // mapping of actual block numbers for each epoch
    mapping(uint256 => uint256) public epochBlocks;

    // state updates for current epoch
    mapping(uint256 => StateUpdate[]) internal epochUpdates;

    // number of updates for each epoch
    mapping(uint256 => uint256) public epochUpdateCounts;

    constructor(
        address _registryStateSender
    ) {
        // initialize first epoch
        lastEpochBlock = block.number;
        nextEpochBlock = block.number + EPOCH_LENGTH;
        currentEpoch = 0;
        REGISTRY_STATE_SENDER = _registryStateSender;
    }

    // check if epoch can be advanced
    function canAdvanceEpoch() public view returns (bool) {
        return block.number >= nextEpochBlock;
    }

    // check if currently in freeze period
    function isInFreezePeriod() public view returns (bool) {
        uint256 currentBlock = block.number;
        uint256 epochEndBlock = nextEpochBlock;
        return currentBlock >= epochEndBlock - FREEZE_PERIOD;
    }

    // advance to next epoch
    function advanceEpoch() external {
        if (!canAdvanceEpoch()) revert EpochManager__EpochNotReady();

        // update block numbers
        lastEpochBlock = nextEpochBlock;
        nextEpochBlock = lastEpochBlock + EPOCH_LENGTH;

        // increment epoch number
        currentEpoch++;

        emit EpochAdvanced(currentEpoch, lastEpochBlock, nextEpochBlock);
    }

    // get remaining blocks until next epoch
    function blocksUntilNextEpoch() external view returns (uint256) {
        if (block.number >= nextEpochBlock) return 0;
        return nextEpochBlock - block.number;
    }

    // get remaining blocks until freeze period
    function blocksUntilFreezePeriod() external view returns (uint256) {
        uint256 freezeStart = nextEpochBlock - FREEZE_PERIOD;
        if (block.number >= freezeStart) return 0;
        return freezeStart - block.number;
    }

    // queue a state update
    function queueStateUpdate(MessageType updateType, bytes memory data) external {
        // ensure not in freeze period
        if (isInFreezePeriod()) revert EpochManager__StillInFreezePeriod();

        // add to current epoch's update list
        epochUpdates[currentEpoch].push(StateUpdate({updateType: updateType, data: data}));

        emit StateUpdateQueued(currentEpoch, updateType, data);
    }

    // get epoch interval details
    function getEpochInterval(
        uint256 epoch
    ) external view returns (uint256 startBlock, uint256 freezeBlock, uint256 endBlock) {
        // return actual block numbers if epoch is recorded
        if (epochBlocks[epoch] != 0) {
            startBlock = epochBlocks[epoch];
            endBlock = startBlock + EPOCH_LENGTH;
            freezeBlock = endBlock - FREEZE_PERIOD;
            return (startBlock, freezeBlock, endBlock);
        }

        // calculate theoretical block numbers
        startBlock = lastEpochBlock + ((epoch - currentEpoch) * EPOCH_LENGTH);
        endBlock = startBlock + EPOCH_LENGTH;
        freezeBlock = endBlock - FREEZE_PERIOD;
    }

    // validate freeze period configuration
    function _validateFreezePeriod(uint256 _epochLength, uint256 _freezePeriod) internal pure {
        if (_epochLength <= _freezePeriod) revert EpochManager__InvalidFreezePeriod();
    }

    // revert to previous epoch
    function revertEpoch(
        uint256 epoch
    ) external onlyOwner {
        if (epoch != currentEpoch) revert EpochManager__InvalidEpochRevert();

        // roll back to previous epoch
        currentEpoch--;
        nextEpochBlock = lastEpochBlock + EPOCH_LENGTH;
        lastEpochBlock = lastEpochBlock - EPOCH_LENGTH;

        emit EpochReverted(epoch);
    }

    // check if epoch can be updated
    function isUpdatable(
        uint256 targetEpoch
    ) public view returns (bool) {
        // can only update next epoch
        if (targetEpoch != currentEpoch + 1) return false;

        // cannot update during freeze period
        if (isInFreezePeriod()) return false;

        return true;
    }

    // calculate current epoch
    function getCurrentEpoch() public view returns (uint256) {
        return (block.number - lastEpochBlock) / EPOCH_LENGTH + currentEpoch;
    }

    // send state updates
    function sendStateUpdates(
        uint256 chainId
    ) external payable {
        // can only send during freeze period
        if (!isInFreezePeriod()) revert EpochManager__NotInFreezePeriod();

        StateUpdate[] storage updates = epochUpdates[currentEpoch];

        // only process if there are updates
        if (updates.length > 0) {
            // record update count
            epochUpdateCounts[currentEpoch] = updates.length;

            // send batch updates via RegistryStateSender
            IRegistryStateSender(REGISTRY_STATE_SENDER).sendBatchUpdates{value: msg.value}(
                currentEpoch, chainId, updates
            );

            emit StateUpdatesSent(currentEpoch, updates.length);
        }
    }
}
