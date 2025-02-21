// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Initializable} from "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import {ECDSAServiceManagerBase} from "./ECDSAServiceManagerBase.sol";
import {ECDSAStakeRegistry} from "./ECDSAStakeRegistry.sol";
import {ECDSAUpgradeable} from
    "@openzeppelin-upgrades/contracts/utils/cryptography/ECDSAUpgradeable.sol";
import {IERC1271Upgradeable} from
    "@openzeppelin-upgrades/contracts/interfaces/IERC1271Upgradeable.sol";
import {PausableUpgradeable} from
    "@openzeppelin-upgrades/contracts/security/PausableUpgradeable.sol";
import {IPauserRegistry} from "@eigenlayer/contracts/interfaces/IPauserRegistry.sol";
import {ISignatureUtils} from "@eigenlayer/contracts/interfaces/ISignatureUtils.sol";
import "../interfaces/ISpottedServiceManager.sol";

/// @title SpottedServiceManager
/// @author Spotted Team
/// @notice Service manager for the Spotted Oracle AVS that handles operator registration
/// @dev Inherits from ECDSAServiceManagerBase and implements ISpottedServiceManager interface
contract SpottedServiceManager is Initializable, ECDSAServiceManagerBase, PausableUpgradeable {
    using ECDSAUpgradeable for bytes32;

    /// @notice Constructor that sets up the base service manager components
    /// @param _avsDirectory Address of the AVS directory contract (mainnet)
    /// @param _stakeRegistry Address of the stake registry contract (mainnet)
    /// @param _rewardsCoordinator Address of the rewards coordinator contract (mainnet)
    /// @param _delegationManager Address of the delegation manager contract (mainnet)
    constructor(
        address _avsDirectory,
        address _stakeRegistry,
        address _rewardsCoordinator,
        address _delegationManager,
        address _allocationManager,
        address _permissionController
    )
        ECDSAServiceManagerBase(
            _avsDirectory,
            _stakeRegistry,
            _rewardsCoordinator,
            _delegationManager,
            _allocationManager,
            _permissionController
        )
    {
        _disableInitializers();
    }

    /// @notice Initializes the contract with required addresses and configurations
    /// @param initialOwner Address that will own the contract
    /// @param initialRewardsInitiator Address that can submit rewards to the rewards coordinator
    /// @param pauserRegistry Address of the pauser registry contract
    function initialize(
        address initialOwner,
        address initialRewardsInitiator,
        IPauserRegistry pauserRegistry
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ECDSAServiceManagerBase_init(initialOwner, address(pauserRegistry));
        _setRewardsInitiator(initialRewardsInitiator);
    }

    /// @notice Generates a unique task ID from input parameters
    /// @param user Address of the user initiating the task
    /// @param chainId ID of the chain where the task is executed
    /// @param blockNumber Block number associated with the task
    /// @param key Task-specific key parameter
    /// @param value Task-specific value parameter
    /// @return bytes32 Unique identifier for the task
    function generateTaskId(
        address user,
        uint32 chainId,
        uint64 blockNumber,
        uint256 key,
        uint256 value
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(user, chainId, blockNumber, key, value));
    }
}
