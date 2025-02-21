// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {IAllocationManager} from "eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";
import {IECDSAStakeRegistry} from "./IECDSAStakeRegistry.sol";

/// @title Slasher Types Interface
/// @notice Defines types used in the slashing system
interface ISlasherTypes {
    /// @notice Parameters for slashing an operator
    struct SlashParams {
        address operator;           // operator to slash
        uint32 operatorSetId;      // operator set ID
        IStrategy[] strategies;     // strategies to slash
        uint256[] wadsToSlash;     // amounts to slash per strategy
        string description;         // reason for slashing
    }
}

/// @title Slasher Errors Interface
/// @notice Defines all error cases in the slashing system
interface ISlasherErrors {
    /// @notice Thrown when caller is not state dispute resolver
    error Slasher__OnlyStateDisputeResolver();
    /// @notice Thrown when no strategies are configured
    error Slasher__NoStrategiesToSlash();
    /// @notice Thrown when slash amount is invalid
    error Slasher__InvalidSlashAmount();
    /// @notice Thrown when operator is not registered
    error Slasher__OperatorNotRegistered();
    /// @notice Thrown when address is invalid
    error Slasher__InvalidAddress();
}

/// @title Slasher Events Interface
/// @notice Defines all events emitted by the slashing system
interface ISlasherEvents {
    /// @notice Emitted when an operator is slashed
    event OperatorSlashed(address indexed operator);

    /// @notice Emitted when the allocation manager is updated
    event AllocationManagerUpdated(address indexed newAllocationManager);

    /// @notice Emitted when the slash amount is updated
    event SlashAmountUpdated(uint256 newAmount);
}

/// @title Slasher Interface
/// @author Spotted Team
/// @notice Interface for handling operator slashing
interface ISlasher is ISlasherTypes, ISlasherErrors, ISlasherEvents {
    /// @notice Slashes an operator
    /// @param operator The operator to slash
    function fulfillSlashingRequest(address operator) external;

    /// @notice Sets the allocation manager
    /// @param _allocationManager New allocation manager address
    function setAllocationManager(address _allocationManager) external;

    /// @notice Sets the slash amount
    /// @param newAmount New slash amount in WAD format
    function setSlashAmount(uint256 newAmount) external;

    /// @notice Gets the slashable strategies
    function getSlashableStrategies() external view returns (IStrategy[] memory);

}