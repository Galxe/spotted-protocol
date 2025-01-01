# Abridge

Adopted from Latch Team

## Abridge.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title BridgeReceiver
/// @notice Interface for contracts that can receive messages through the bridge
interface IAbridgeMessageHandler {
    /// @notice Handles incoming messages from the bridge.
    /// @param _from The address of the sender
    /// @param _msg The message data
    /// @return response The function selector to confirm successful handling
    function handleMessage(address _from, bytes calldata _msg, bytes32 guid) external returns (bytes4 response);
}

/// @title IAbridge
/// @notice Interface for the Abridge contract
interface IAbridge {
    /// @notice Emitted when a message is sent through the bridge
    event MessageSent(address indexed sender, address indexed receiver, bytes32 guid, uint256 fee);

    /// @notice Emitted when a message is received through the bridge
    event MessageReceived(address indexed sender, address indexed receiver, bytes32 guid);

    /// @notice Emitted when an authorized sender is updated
    event AuthorizedSenderUpdated(address indexed sender, bool authorized);

    /// @notice Emitted when a route is updated
    event RouteUpdated(address indexed receiver, address indexed sender, bool allowed);

    error InsufficientFee(uint256 _sent, uint256 _required);
    error UnauthorizedSender(address _sender);
    error DisallowedRoute(address _sender, address _receiver);
    error InvalidReceiverResponse(bytes4 _response);

    /// @notice Updates the route for a specific sender
    /// @param _sender Address of the sender
    /// @param _allowed Flag to allow or disallow the route
    function updateRoute(address _sender, bool _allowed) external;

    /// @notice Sends a message through the bridge
    /// @param _receiver Address of the receiver
    /// @param _executeGasLimit Gas limit for execution
    /// @param _msg The message to be sent
    /// @return _guid The unique identifier for the sent message
    function send(
        address _receiver,
        uint128 _executeGasLimit,
        bytes memory _msg
    ) external payable returns (bytes32 _guid);

    /// @notice The endpoint ID of the destination chain
    function eid() external view returns (uint32);

    /// @notice Checks if a sender is authorized
    /// @param sender The address of the sender to check
    /// @return authorized True if the sender is authorized, false otherwise
    function authorizedSenders(address sender) external view returns (bool authorized);

    /// @notice Estimates the fee for sending a message
    /// @param _receiver Address of the receiver
    /// @param _executeGasLimit Gas limit for execution
    /// @param _msg The message to be sent
    /// @return _token The token address for the fee (address(0) for native token)
    /// @return _fee The estimated fee amount
    function estimateFee(
        address _receiver,
        uint128 _executeGasLimit,
        bytes memory _msg
    ) external view returns (address _token, uint256 _fee);
}
```

## Interface

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title BridgeReceiver
/// @notice Interface for contracts that can receive messages through the bridge
interface IAbridgeMessageHandler {
    /// @notice Handles incoming messages from the bridge.
    /// @param _from The address of the sender
    /// @param _msg The message data
    /// @return response The function selector to confirm successful handling
    function handleMessage(
        address _from,
        bytes calldata _msg,
        bytes32 guid
    ) external returns (bytes4 response);
}

/// @title IAbridge
/// @notice Interface for the Abridge contract
interface IAbridge {
    /// @notice Emitted when a message is sent through the bridge
    event MessageSent(address indexed sender, address indexed receiver, bytes32 guid, uint256 fee);

    /// @notice Emitted when a message is received through the bridge
    event MessageReceived(address indexed sender, address indexed receiver, bytes32 guid);

    /// @notice Emitted when an authorized sender is updated
    event AuthorizedSenderUpdated(address indexed sender, bool authorized);

    /// @notice Emitted when a route is updated
    event RouteUpdated(address indexed receiver, address indexed sender, bool allowed);

    error InsufficientFee(uint256 _sent, uint256 _required);
    error UnauthorizedSender(address _sender);
    error DisallowedRoute(address _sender, address _receiver);
    error InvalidReceiverResponse(bytes4 _response);

    /// @notice Updates the route for a specific sender
    /// @param _sender Address of the sender
    /// @param _allowed Flag to allow or disallow the route
    function updateRoute(address _sender, bool _allowed) external;

    /// @notice Sends a message through the bridge
    /// @param _receiver Address of the receiver
    /// @param _executeGasLimit Gas limit for execution
    /// @param _msg The message to be sent
    /// @return _guid The unique identifier for the sent message
    function send(
        address _receiver,
        uint128 _executeGasLimit,
        bytes memory _msg
    ) external payable returns (bytes32 _guid);

    /// @notice The endpoint ID of the destination chain
    function eid() external view returns (uint32);

    /// @notice Checks if a sender is authorized
    /// @param sender The address of the sender to check
    /// @return authorized True if the sender is authorized, false otherwise
    function authorizedSenders(
        address sender
    ) external view returns (bool authorized);

    /// @notice Estimates the fee for sending a message
    /// @param _receiver Address of the receiver
    /// @param _executeGasLimit Gas limit for execution
    /// @param _msg The message to be sent
    /// @return _token The token address for the fee (address(0) for native token)
    /// @return _fee The estimated fee amount
    function estimateFee(
        address _receiver,
        uint128 _executeGasLimit,
        bytes memory _msg
    ) external view returns (address _token, uint256 _fee);
}
```

## RoutedData.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title RoutedData Library
/// @notice A library for encoding and decoding data with prepended "from" and "to" addresses
library RoutedData {
    /// @dev Error thrown when the data length is insufficient for decoding
    /// @param length The actual length of the data
    error InsufficientDataLength(uint64 length);

    /// @notice Encodes two addresses and data into a single byte array
    /// @param from The sender address to prepend
    /// @param to The recipient address to prepend
    /// @param data The data to encode
    /// @return A byte array containing the encoded addresses and data
    function encode(address from, address to, bytes memory data) internal pure returns (bytes memory) {
        // Prepend the two addresses to the data using abi.encodePacked
        return abi.encodePacked(from, to, data);
    }

    /// @notice Decodes a byte array into two addresses and the remaining data
    /// @param data The byte array to decode
    /// @return from The extracted sender address
    /// @return to The extracted recipient address
    /// @return remainingData The remaining data after extracting the addresses
    function decode(bytes memory data) internal pure returns (address from, address to, bytes memory remainingData) {
        if (data.length < 40) {
            revert InsufficientDataLength(uint64(data.length));
        }

        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Load the first 20 bytes (from address) from the start of data
            from := mload(add(data, 20))

            // Load the next 20 bytes (to address)
            to := mload(add(data, 40))

            // Set remainingData to point to the location after the first 40 bytes (2 addresses)
            remainingData := add(data, 40)

            // Update the length of remainingData (total length minus 40 bytes for the two addresses)
            mstore(remainingData, sub(mload(data), 40))
        }
    }
}
```