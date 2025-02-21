// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IAbridgeMessageHandler} from "../interfaces/IAbridge.sol";
import {IAbridge} from "../interfaces/IAbridge.sol";
import {Ownable} from "@openzeppelin-v5.0.0/contracts/access/Ownable.sol";
import {ILightStakeRegistry} from "../interfaces/ILightStakeRegistry.sol";
import {IRegistryStateReceiver} from "../interfaces/IRegistryStateReceiver.sol";
import {
    ECDSAStakeRegistryStorage,
    IECDSAStakeRegistryTypes
} from "../avs/ECDSAStakeRegistryStorage.sol";
import {IEpochManager} from "../interfaces/IEpochManager.sol";

/// @title Registry State Receiver
/// @author Spotted Team
/// @notice Handles receiving and processing state updates from the bridge for the stake registry
/// @dev Acts as a bridge message handler for stake registry state synchronization
contract RegistryStateReceiver is IRegistryStateReceiver, Ownable {
    /// @notice The bridge contract used for cross-chain communication
    IAbridge public immutable abridge;

    /// @notice The authorized sender address on the source chain
    address public immutable sender;

    /// @notice The stake registry contract that receives state updates
    ILightStakeRegistry public immutable stakeRegistry;

    /// @notice Mapping to track processed messages
    mapping(bytes32 => bool) public processedMessages;
    /// @notice The current epoch number
    uint256 private currentUpdatingEpoch;

    /// @notice Retrieves the current epoch number
    /// @return The current epoch number
    function getCurrentUpdatingEpoch() external view returns (uint256) {
        return currentUpdatingEpoch;
    }

    /// @notice Ensures only the bridge contract can call certain functions
    /// @dev Reverts if caller is not the bridge contract
    modifier onlyAbridge() {
        if (msg.sender != address(abridge)) revert RegistryStateReceiver__InvalidSender();
        _;
    }

    /// @notice Initializes the contract with required addresses
    /// @param _abridge The address of the bridge contract
    /// @param _sender The authorized sender address on the source chain
    /// @param _stakeRegistry The address of the stake registry contract
    /// @param _owner The address of the contract owner
    /// @dev Sets up initial routing and ownership
    constructor(
        address _abridge,
        address _sender,
        address _stakeRegistry,
        address _owner
    ) Ownable(_owner) {
        abridge = IAbridge(_abridge);
        sender = _sender;
        stakeRegistry = ILightStakeRegistry(_stakeRegistry);

        // call updateRoute and check return value
        abridge.updateRoute(sender, true);
    }

    /// @notice Handles incoming messages from the bridge
    /// @param from The address that sent the message
    /// @param message The encoded message data
    /// *guid*: The unique identifier for the message
    /// @return bytes4 The function selector indicating successful message handling
    /// @dev Only processes messages from the authorized sender
    function handleMessage(
        address from,
        bytes calldata message,
        bytes32 guid
    ) external onlyAbridge returns (bytes4) {
        if (from != sender) revert RegistryStateReceiver__InvalidSender();
        if (processedMessages[guid]) revert RegistryStateReceiver__MessageAlreadyProcessed();

        (uint32 epochNumber, address[] memory operators,,,) = abi.decode(message, (uint32, address[], address[], uint256[], uint256));

        currentUpdatingEpoch = epochNumber;

        // send to LightStakeRegistry
        try stakeRegistry.processEpochUpdate(message) {
            processedMessages[guid] = true;
            emit UpdateProcessed(epochNumber, operators.length);
        } catch {
            revert RegistryStateReceiver__BatchUpdateFailed();
        }

        return IAbridgeMessageHandler.handleMessage.selector;
    }

    /// @notice Updates the routing settings for the sender
    /// @param allowed Whether the sender is allowed to send messages
    /// @dev Only callable by the contract owner
    function updateRoute(
        bool allowed
    ) external onlyOwner {
        // call updateRoute and check return value
        abridge.updateRoute(sender, allowed);
    }
}
