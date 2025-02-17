// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IEpochManager} from "../interfaces/IEpochManager.sol";
import {IRegistryStateSender} from "../interfaces/IRegistryStateSender.sol";

/// @title Epoch Manager
/// @author Spotted Team
/// @notice Manages epoch transitions and state updates for the AVS system
/// @dev Handles epoch advancement, grace periods, and state synchronization
contract EpochManager is IEpochManager, Ownable {
    /// @notice Genesis block number when contract was deployed
    /// @dev Immutable after deployment
    uint64 public immutable GENESIS_BLOCK;

    /// @notice Length of each epoch in blocks (approximately 7 days)
    /// @dev Immutable after deployment
    uint64 public immutable EPOCH_LENGTH = 45000;

    /// @notice Grace period duration in blocks (approximately 1 day)
    /// @dev Immutable after deployment, must be less than EPOCH_LENGTH
    uint64 public immutable GRACE_PERIOD = 6400;

    /// @notice Address of the registry state sender contract
    /// @dev Immutable after deployment
    address public immutable REGISTRY_STATE_SENDER;

    /// @notice Address of the stake registry contract
    /// @dev Immutable after deployment
    address public immutable STAKE_REGISTRY;

    /// @notice State updates for each epoch
    mapping(uint32 epochNumber => StateUpdate[] updates) internal epochUpdates;

    /// @notice Modifier to restrict access to only the stake registry
    /// @dev Reverts if caller is not the stake registry
    modifier onlyStakeRegistry() {
        if (msg.sender != STAKE_REGISTRY) {
            revert EpochManager__UnauthorizedAccess();
        }
        _;
    }

    /// @notice Initializes the contract with required parameters
    /// @param _registryStateSender Address of the registry state sender contract
    /// @param _stakeRegistry Address of the stake registry contract
    constructor(address _registryStateSender, address _stakeRegistry) Ownable() {
        GENESIS_BLOCK = uint64(block.number);
        REGISTRY_STATE_SENDER = _registryStateSender;
        STAKE_REGISTRY = _stakeRegistry;
    }

    /// @notice Queues a state update
    /// @param updateType Type of update to queue
    /// @param data Encoded update data
    function queueStateUpdate(MessageType updateType, bytes memory data) external onlyStakeRegistry {
        uint32 targetEpoch = getEffectiveEpoch();
        
        epochUpdates[targetEpoch].push(StateUpdate({
            updateType: updateType,
            data: data
        }));

        emit StateUpdateQueued(targetEpoch, updateType, data);
    }

    /// @notice Sends state updates to specified chain
    /// @param chainId The ID of the target chain
    /// @dev Requires payment for cross-chain message fees
    function sendStateUpdates(uint256 chainId) external payable {
        uint32 targetEpoch = getCurrentEpoch() + 1;
        StateUpdate[] storage updates = epochUpdates[targetEpoch];

        // only process if there are updates
        if (updates.length > 0) {

            // send batch updates via RegistryStateSender
            IRegistryStateSender(REGISTRY_STATE_SENDER).sendBatchUpdates{value: msg.value}(
                targetEpoch,
                chainId,
                updates
            );

            emit StateUpdatesSent(targetEpoch, updates.length);
        }
    }

    /// @notice Gets remaining blocks until next epoch
    /// @return uint64 Number of blocks until next epoch
    function blocksUntilNextEpoch() external view returns (uint64) {
        if (block.number >= getNextEpochStartBlock()) return 0;
        return getNextEpochStartBlock() - uint64(block.number);
    }

    /// @notice Gets remaining blocks until grace period
    /// @return uint64 Number of blocks until grace period starts
    function blocksUntilGracePeriod() external view returns (uint64) {
        uint64 graceStart = getNextEpochStartBlock() - GRACE_PERIOD;
        if (block.number >= graceStart) return 0;
        return graceStart - uint64(block.number);
    }


    /// @notice Gets epoch interval details
    /// @param epoch The epoch number to query
    /// @return startBlock Start block of the epoch
    /// @return graceBlock Block when grace period starts
    /// @return endBlock End block of the epoch
    function getEpochInterval(
        uint32 epoch
    ) external view returns (uint64 startBlock, uint64 graceBlock, uint64 endBlock) {
        startBlock = GENESIS_BLOCK + (epoch * EPOCH_LENGTH);
        endBlock = startBlock + EPOCH_LENGTH;
        graceBlock = endBlock - GRACE_PERIOD;
        return (startBlock, graceBlock, endBlock);
    }

    /// @notice Gets effective epoch for state updates
    /// @return uint32 The epoch number where updates will take effect
    /// @dev Returns current epoch + 2 during grace period, current epoch + 1 otherwise
    function getEffectiveEpoch() public view returns (uint32) {
        if (isInGracePeriod()) {
            return getCurrentEpoch() + 2;
        }
        return getCurrentEpoch() + 1;
    }

    /// @notice Calculates the effective epoch for a given block number, usually used to determine the epoch of a state update
    /// @param blockNumber The block number to calculate the effective epoch for
    /// @return uint32 The effective epoch number when changes will take effect
    /// @dev If the block is in a grace period, returns epoch + 2, otherwise returns epoch + 1
    function getEffectiveEpochForBlock(uint64 blockNumber) public view returns (uint32) {
        uint64 blocksSinceGenesis = blockNumber - GENESIS_BLOCK;
        uint32 absoluteEpoch = uint32(blocksSinceGenesis / EPOCH_LENGTH);
        
        uint64 epochStartBlock = GENESIS_BLOCK + (uint64(absoluteEpoch) * EPOCH_LENGTH);
        uint64 epochEndBlock = epochStartBlock + EPOCH_LENGTH;
        
        bool isGracePeriod = blockNumber >= (epochEndBlock - GRACE_PERIOD);
        
        return absoluteEpoch + (isGracePeriod ? 2 : 1);
    }

    /// @notice Checks if currently in grace period
    /// @return bool True if current block is within grace period
    function isInGracePeriod() public view returns (bool) {
        uint256 currentBlock = block.number;
        uint256 epochEndBlock = getNextEpochStartBlock();
        return currentBlock >= epochEndBlock - GRACE_PERIOD;
    }

    /// @notice Calculates current epoch based on block number
    /// @return uint32 The current epoch number
    function getCurrentEpoch() public view returns (uint32) {
        uint64 blocksSinceGenesis = uint64(block.number) - GENESIS_BLOCK;
        return uint32(blocksSinceGenesis / EPOCH_LENGTH);
    }

    /// @notice Gets the start block of the current epoch
    /// @return uint64 The start block of the current epoch
    function getCurrentEpochStartBlock() public view returns (uint64) {
        return GENESIS_BLOCK + (getCurrentEpoch() * EPOCH_LENGTH);
    }

    /// @notice Gets the next epoch start block
    /// @return uint64 The next epoch start block
    function getNextEpochStartBlock() public view returns (uint64) {
        return getCurrentEpochStartBlock() + EPOCH_LENGTH;
    }

    /// @notice Gets the start block for a given epoch number
    /// @param epoch The epoch number to query
    /// @return uint64 The start block of the specified epoch
    function getStartBlockForEpoch(uint32 epoch) public view returns (uint64) {
        return GENESIS_BLOCK + (epoch * EPOCH_LENGTH);
    }
}
