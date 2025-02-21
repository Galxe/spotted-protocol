// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {IAbridgeMessageHandler} from "./IAbridge.sol";
import {IAbridge} from "./IAbridge.sol";
import {ILightStakeRegistry} from "./ILightStakeRegistry.sol";
import {IEpochManager} from "./IEpochManager.sol";

/// @title Registry State Receiver Errors Interface
/// @notice Defines all error cases in the registry state receiving system
interface IRegistryStateReceiverErrors {
    /// @notice Thrown when caller is not authorized
    error RegistryStateReceiver__InvalidSender();
    /// @notice Thrown when updating route fails
    error RegistryStateReceiver__UpdateRouteFailed();
    /// @notice Thrown when batch update fails
    error RegistryStateReceiver__BatchUpdateFailed();
    /// @notice Thrown when message has already been processed
    error RegistryStateReceiver__MessageAlreadyProcessed();
}

/// @title Registry State Receiver Events Interface
/// @notice Defines all events emitted by the registry state receiving system
interface IRegistryStateReceiverEvents {
    /// @notice Emitted when updates are successfully processed
    /// @param epoch The epoch number for the updates
    /// @param updatesCount The number of updates processed
    event UpdateProcessed(uint256 indexed epoch, uint256 updatesCount);
}

/// @title Registry State Receiver Interface
/// @author Spotted Team
/// @notice Interface for handling cross-chain state updates for the stake registry
interface IRegistryStateReceiver is 
    IRegistryStateReceiverErrors,
    IRegistryStateReceiverEvents,
    IAbridgeMessageHandler 
{
    /* MESSAGE HANDLING */

    /// @notice Handles incoming messages from the bridge
    /// @param from The address that sent the message
    /// @param message The encoded message data
    /// @param guid The unique identifier for the message
    /// @return bytes4 The function selector indicating successful message handling
    function handleMessage(
        address from,
        bytes calldata message,
        bytes32 guid
    ) external returns (bytes4);

    /* ROUTE MANAGEMENT */

    /// @notice Updates the routing settings for the sender
    /// @param allowed Whether the sender is allowed to send messages
    function updateRoute(bool allowed) external;

    /* VIEW FUNCTIONS */

    /// @notice Gets the bridge contract address
    /// @return The bridge contract interface
    function abridge() external view returns (IAbridge);

    /// @notice Gets the authorized sender address
    /// @return The sender address
    function sender() external view returns (address);

    /// @notice Gets the stake registry contract address
    /// @return The stake registry contract interface
    function stakeRegistry() external view returns (ILightStakeRegistry);

    /// @notice Checks if a message has been processed
    /// @param guid The message identifier to check
    /// @return Whether the message has been processed
    function processedMessages(bytes32 guid) external view returns (bool);

    /// @notice Gets the current epoch being updated
    /// @return The current updating epoch number
    function getCurrentUpdatingEpoch() external view returns (uint256);
}
