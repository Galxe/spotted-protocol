// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/// @title Registry State Sender Types Interface
/// @notice Defines types and structs used in the registry state sending system
interface IRegistryStateSenderTypes {
    /// @notice Bridge configuration information
    struct BridgeInfo {
        address bridge;
        address receiver;
    }
}

/// @title Registry State Sender Errors Interface
/// @notice Defines all error cases in the registry state sending system
interface IRegistryStateSenderErrors {
    /// @notice Thrown when the message fee is insufficient
    error RegistryStateSender__InsufficientFee();
    /// @notice Thrown when bridge configuration is invalid
    error RegistryStateSender__InvalidBridgeInfo();
    /// @notice Thrown when adding a bridge that already exists
    error RegistryStateSender__BridgeAlreadyExists();
    /// @notice Thrown when target chain is not supported
    error RegistryStateSender__ChainNotSupported();
    /// @notice Thrown when sender is not authorized
    error RegistryStateSender__InvalidSender();
}

/// @title Registry State Sender Events Interface
/// @notice Defines all events emitted by the registry state sending system
interface IRegistryStateSenderEvents {
    /// @notice Emitted when bridge configuration is modified
    /// @param chainId The chain ID for which bridge was modified
    /// @param newBridge The new bridge address
    /// @param newReceiver The new receiver address
    event BridgeModified(
        uint256 indexed chainId,
        address newBridge,
        address newReceiver
    );

    /// @notice Emitted when state is sent to another chain
    /// @param epoch The epoch number
    /// @param chainId The target chain ID
    event StateSent(uint256 indexed epoch, uint256 indexed chainId);
}

/// @title Registry State Sender Interface
/// @author Spotted Team
/// @notice Interface for sending registry state updates across chains
interface IRegistryStateSender is 
    IRegistryStateSenderTypes,
    IRegistryStateSenderErrors,
    IRegistryStateSenderEvents 
{
    /* BRIDGE MANAGEMENT */

    /// @notice Adds a new bridge configuration
    /// @param _chainId The chain ID to add bridge for
    /// @param _bridge The bridge contract address
    /// @param _receiver The receiver contract address
    function addBridge(
        uint256 _chainId,
        address _bridge,
        address _receiver
    ) external;

    /// @notice Removes a bridge configuration
    /// @param _chainId The chain ID to remove bridge for
    function removeBridge(uint256 _chainId) external;

    /// @notice Modifies an existing bridge configuration
    /// @param _chainId The chain ID to modify bridge for
    /// @param _newBridge The new bridge contract address
    /// @param _newReceiver The new receiver contract address
    function modifyBridge(
        uint256 _chainId,
        address _newBridge,
        address _newReceiver
    ) external;

    /* STATE SENDING */

    /// @notice Sends state data to target chain
    /// @param epoch The epoch number
    /// @param chainId The target chain ID
    /// @param data The encoded state data
    function sendState(
        uint256 epoch,
        uint256 chainId,
        bytes memory data
    ) external payable;

    /* VIEW FUNCTIONS */

    /// @notice Gets bridge configuration for a chain
    /// @param chainId The chain ID to query
    /// @return Bridge configuration information
    function getBridgeInfoByChainId(
        uint256 chainId
    ) external view returns (BridgeInfo memory);

    /// @notice Gets the epoch manager contract address
    /// @return The epoch manager address
    function epochManager() external view returns (address);

    /// @notice Gets supported chain ID at index
    /// @param index The index to query
    /// @return The chain ID at that index
    function supportedChainIds(uint256 index) external view returns (uint256);
}
