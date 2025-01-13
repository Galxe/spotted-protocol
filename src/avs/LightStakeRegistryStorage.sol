// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {EpochCheckpointsUpgradeable} from "../libraries/EpochCheckpointsUpgradeable.sol";
import {
    LightStakeRegistryEventsAndErrors,
    Quorum,
    StrategyParams
} from "../interfaces/ILightStakeRegistryEventsAndErrors.sol";
import {IEpochManager} from "../interfaces/IEpochManager.sol";
import {IRegistryStateReceiver} from "../interfaces/IRegistryStateReceiver.sol";

abstract contract LightStakeRegistryStorage is LightStakeRegistryEventsAndErrors {
    IRegistryStateReceiver internal immutable REGISTRY_STATE_RECEIVER;
    /// @dev The total amount of multipliers to weigh stakes
    uint256 internal constant BPS = 10_000;

    /// @notice The size of the current operator set
    uint256 internal _totalOperators;

    /// @notice Stores the current quorum configuration
    Quorum internal _quorum;

    /// @notice Specifies the weight required to become an operator
    uint256 internal _minimumWeight;

    /// @notice Defines the duration after which the stake's weight expires.
    uint256 internal _stakeExpiry;

    /// @notice Maps an operator to their signing key history using checkpoints
    mapping(address => EpochCheckpointsUpgradeable.History) internal _operatorSigningKeyHistory;

    /// @notice Tracks the total stake history over time using checkpoints
    EpochCheckpointsUpgradeable.History internal _totalWeightHistory;

    /// @notice Tracks the threshold bps history using checkpoints
    EpochCheckpointsUpgradeable.History internal _thresholdWeightHistory;

    /// @notice Maps operator addresses to their respective stake histories using checkpoints
    mapping(address => EpochCheckpointsUpgradeable.History) internal _operatorWeightHistory;

    /// @notice Maps an operator to their registration status
    mapping(address => bool) internal _operatorRegistered;

    // slither-disable-next-line shadowing-state
    /// @dev Reserves storage slots for future upgrades
    // solhint-disable-next-line
    uint256[40] private __gap;

    constructor(address _registryStateReceiver) {
        REGISTRY_STATE_RECEIVER = IRegistryStateReceiver(_registryStateReceiver);
    }
}
