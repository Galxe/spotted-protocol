// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IAVSRegistrar} from "eigenlayer-contracts/src/contracts/interfaces/IAVSRegistrar.sol";
import {IAllocationManager} from "eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";
import {IECDSAStakeRegistry} from "./IECDSAStakeRegistry.sol";

/// @title Spotted Registrar Errors Interface
/// @notice Defines all error cases in the Spotted registrar system
interface ISpottedRegistrarErrors {
    /// @notice Thrown when zero address is provided
    error SpottedRegistrar__ZeroAddress();
    
    /// @notice Thrown when caller is not allocation manager
    error SpottedRegistrar__OnlyAllocationManager();
    
    /// @notice Thrown when operator set IDs are invalid
    error SpottedRegistrar__InvalidOperatorSetIds();
}

/// @title Spotted Registrar Events Interface
/// @notice Defines all events emitted by the Spotted registrar system
interface ISpottedRegistrarEvents {
    /// @notice Emitted when allocation manager is updated
    /// @param newAllocationManager The new allocation manager address
    event AllocationManagerUpdated(address indexed newAllocationManager);
}

/// @title Spotted Registrar Interface
/// @author Spotted Team
/// @notice Interface for managing operator registration in the Spotted system
interface ISpottedRegistrar is 
    IAVSRegistrar,
    ISpottedRegistrarErrors,
    ISpottedRegistrarEvents 
{
    /* VIEW FUNCTIONS */

    /// @notice Gets the allocation manager contract
    /// @return The allocation manager interface
    function allocationManager() external view returns (IAllocationManager);

    /// @notice Gets the stake registry contract
    /// @return The stake registry interface
    function stakeRegistry() external view returns (IECDSAStakeRegistry);

    /* ADMIN FUNCTIONS */
    
    /// @notice Updates the allocation manager address
    /// @param _allocationManager The new allocation manager address
    function updateAllocationManager(address _allocationManager) external;
}