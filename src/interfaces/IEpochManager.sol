// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title Epoch Manager Errors Interface
/// @notice Defines all error cases in the epoch management system
interface IEpochManagerErrors {
    /// @notice Thrown when epoch length is invalid
    error EpochManager__InvalidEpochLength();
    /// @notice Thrown when grace period is invalid
    error EpochManager__InvalidGracePeriod();
    /// @notice Thrown when period length is invalid
    error EpochManager__InvalidPeriodLength();
    /// @notice Thrown when caller is not authorized
    error EpochManager__UnauthorizedAccess();
    /// @notice Thrown when epoch number is invalid
    error EpochManager__InvalidEpoch();
}

/// @title Epoch Manager Events Interface
/// @notice Defines all events emitted by the epoch management system
interface IEpochManagerEvents {
    /// @notice Emitted when a state snapshot is sent
    /// @param epochNumber The epoch number
    /// @param chainId The target chain ID
    /// @param operators The list of operators included in the snapshot
    event StateSnapshotSent(
        uint32 indexed epochNumber,
        uint256 indexed chainId,
        address[] operators
    );
}

/// @title Epoch Manager Interface
/// @author Spotted Team
/// @notice Interface for managing epochs and state snapshots
interface IEpochManager is 
    IEpochManagerErrors,
    IEpochManagerEvents 
{
    /* EPOCH MANAGEMENT */

    /// @notice Gets the current epoch number
    /// @return The current epoch number
    function getCurrentEpoch() external view returns (uint32);

    /// @notice Gets effective epoch for state updates
    /// @return The epoch number where updates will take effect
    function getEffectiveEpoch() external view returns (uint32);

    /// @notice Calculates the effective epoch for a given block number
    /// @param blockNumber The block number to calculate for
    /// @return The effective epoch number
    function getEffectiveEpochForBlock(uint64 blockNumber) external view returns (uint32);

    /* BLOCK MANAGEMENT */

    /// @notice Gets the start block of the current epoch
    /// @return The start block number
    function getCurrentEpochStartBlock() external view returns (uint64);

    /// @notice Gets the next epoch start block
    /// @return The next epoch start block number
    function getNextEpochStartBlock() external view returns (uint64);

    /// @notice Gets the start block for a given epoch
    /// @param epoch The epoch number to query
    /// @return The start block number for the epoch
    function getStartBlockForEpoch(uint32 epoch) external view returns (uint64);

    /* GRACE PERIOD MANAGEMENT */

    /// @notice Checks if currently in grace period
    /// @return Whether current block is in grace period
    function isInGracePeriod() external view returns (bool);

    /// @notice Gets remaining blocks until grace period
    /// @return Number of blocks until grace period starts
    function blocksUntilGracePeriod() external view returns (uint64);

    /// @notice Gets remaining blocks until next epoch
    /// @return Number of blocks until next epoch
    function blocksUntilNextEpoch() external view returns (uint64);

    /* INTERVAL QUERIES */

    /// @notice Gets epoch interval details
    /// @param epoch The epoch number to query
    /// @return startBlock Start block of the epoch
    /// @return graceBlock Block when grace period starts
    /// @return endBlock End block of the epoch
    function getEpochInterval(uint32 epoch) external view returns (
        uint64 startBlock,
        uint64 graceBlock,
        uint64 endBlock
    );

    /* STATE SNAPSHOT */

    /// @notice Takes and sends a state snapshot to target chain
    /// @param operators List of operators to include in snapshot
    /// @param epochNumber The epoch number for the snapshot
    /// @param chainId The target chain ID
    function snapshotAndSendState(
        address[] calldata operators,
        uint32 epochNumber,
        uint256 chainId
    ) external payable;

    /* CONSTANTS */

    /// @notice Gets the genesis block number
    /// @return The genesis block number
    function GENESIS_BLOCK() external view returns (uint64);

    /// @notice Gets the epoch length in blocks
    /// @return The epoch length
    function EPOCH_LENGTH() external view returns (uint64);

    /// @notice Gets the grace period length in blocks
    /// @return The grace period length
    function GRACE_PERIOD() external view returns (uint64);

    /// @notice Gets the registry state sender address
    /// @return The registry state sender address
    function REGISTRY_STATE_SENDER() external view returns (address);

    /// @notice Gets the stake registry address
    /// @return The stake registry address
    function STAKE_REGISTRY() external view returns (address);
}
