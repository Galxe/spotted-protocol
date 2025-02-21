// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC1271Upgradeable} from "@openzeppelin-upgrades/contracts/interfaces/IERC1271Upgradeable.sol";

interface ILightStakeRegistryErrors {
    /// @notice Thrown when length of signers and signatures mismatch
    error LightStakeRegistry__LengthMismatch();
    
    /// @notice Thrown when length is invalid (zero)
    error LightStakeRegistry__InvalidLength();
    
    /// @notice Thrown when signature is invalid
    error LightStakeRegistry__InvalidSignature();
    
    /// @notice Indicates the total signed stake fails to meet the required threshold
    error LightStakeRegistry__InsufficientSignedStake();
    
    /// @notice Indicates the system finds a list of items unsorted
    error LightStakeRegistry__NotSorted();
    
    /// @notice Thrown when the sender is not the state receiver
    error LightStakeRegistry__InvalidSender();
    
    /// @notice Thrown when the epoch is invalid
    error LightStakeRegistry__InvalidEpoch();
}

interface ILightStakeRegistry is ILightStakeRegistryErrors, IERC1271Upgradeable {
    /* INITIALIZATION */
    
    /// @notice Initializes the contract
    function initialize() external;

    /* STATE UPDATES */

    /// @notice Processes epoch update with state data
    /// @param data Encoded state data containing operator information
    function processEpochUpdate(bytes memory data) external;

    /* VIEW FUNCTIONS */

    /// @notice Gets operator's signing key at epoch
    /// @param operator The operator address
    /// @param epochNumber The epoch number
    /// @return The signing key at that epoch
    function getOperatorSigningKeyAtEpoch(
        address operator,
        uint32 epochNumber
    ) external view returns (address);

    /// @notice Gets operator's weight at epoch
    /// @param operator The operator address
    /// @param epochNumber The epoch number
    /// @return The operator's weight at that epoch
    function getOperatorWeightAtEpoch(
        address operator,
        uint32 epochNumber
    ) external view returns (uint256);

    /// @notice Gets threshold weight at epoch
    /// @param epochNumber The epoch number
    /// @return The threshold weight at that epoch
    function getThresholdWeightAtEpoch(
        uint32 epochNumber
    ) external view returns (uint256);
}
