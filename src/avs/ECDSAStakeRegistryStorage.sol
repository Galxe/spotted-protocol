// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IDelegationManager} from
    "eigenlayer-contracts/src/contracts/interfaces/IDelegationManager.sol";
import {EpochCheckpointsUpgradeable} from "../libraries/EpochCheckpointsUpgradeable.sol";
import {
    ECDSAStakeRegistryEventsAndErrors,
    Quorum,
    StrategyParams
} from "../interfaces/IECDSAStakeRegistryEventsAndErrors.sol";
import {IEpochManager} from "../interfaces/IEpochManager.sol";
import {IServiceManager} from "../interfaces/IServiceManager.sol";

abstract contract ECDSAStakeRegistryStorage is ECDSAStakeRegistryEventsAndErrors {
    /// @notice Manages staking delegations through the DelegationManager interface
    IDelegationManager internal immutable DELEGATION_MANAGER;
    IEpochManager internal immutable EPOCH_MANAGER;
    IServiceManager internal immutable SERVICE_MANAGER;

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

    /// @notice Maps an operator to their signing key
    mapping(address => address) internal _operatorToSigningKey;

    /// @notice Maps an operator to their P2p key history using checkpoints
    mapping(address => EpochCheckpointsUpgradeable.History) internal _operatorP2pKeyHistory;

    /// @param _delegationManager Connects this registry with the DelegationManager
    constructor(address _delegationManager, address _epochManager, address _serviceManager) {
        DELEGATION_MANAGER = IDelegationManager(_delegationManager);
        EPOCH_MANAGER = IEpochManager(_epochManager);
        SERVICE_MANAGER = IServiceManager(_serviceManager);
    }

    // slither-disable-next-line shadowing-state
    /// @dev Reserves storage slots for future upgrades
    // solhint-disable-next-line
    uint256[40] private __gap;
}
