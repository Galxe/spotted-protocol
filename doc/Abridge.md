# Abridge

We use Abridge as the abstraction layer to send messages between chains. Adopted from Latch Team

Below are the interfaces and implementations of Abridge.
## Abridge.sol

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";

import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import { OApp, Origin, MessagingReceipt, MessagingFee } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";

import { RoutedData } from "./RoutedData.sol";
import { IAbridge, IAbridgeMessageHandler } from "./IAbridge.sol";

/// @title Abridge (Abstract Bridge)
/// @author Latch team
/// @notice Abridge is a bridge abstraction that uses an underlying cross-chain bridge implementation
/// with message multiplexing and route management.
/// An Abridge is always paired with another Abridge on the destination chain.
/// Messages can only be sent from contract A on the source chain to contract B on the destination chain
/// if the route for receiving messages from A to B is enabled on the destination chain.
contract Abridge is Pausable, OApp, Ownable2Step, IAbridge {
    using SafeERC20 for IERC20;
    using OptionsBuilder for bytes;

    /// @notice Configuration for allowed senders for a specific receiver
    struct RouteConfig {
        mapping(address sender => bool allowed) allowed;
    }

    /// @notice Mapping of receiver addresses to their route configurations
    mapping(address receiver => RouteConfig config) private _routes;

    /// @notice Mapping of authorized sender addresses
    mapping(address sender => bool authorized) public authorizedSenders;

    /// @notice The endpoint ID of the destination chain
    uint32 public eid;

    /// @notice Internal error of failed to send rescued native token to the recipient.
    error FailedToSendRescuedFund(address _to, uint256 _amount);

    modifier onlyAuthorizedSender() {
        if (!authorizedSenders[msg.sender]) {
            revert UnauthorizedSender(msg.sender);
        }
        _;
    }

    /// @notice Constructs the Abridge contract
    /// @param _endpoint The address of the LayerZero endpoint
    /// @param _owner The address of the contract owner
    /// @param _dstEid The endpoint ID of the destination chain
    constructor(
        address _endpoint, // solhint-disable-line no-unused-vars
        address _owner, // solhint-disable-line no-unused-vars
        uint32 _dstEid
    ) OApp(_endpoint, _owner) Ownable(_owner) {
        eid = _dstEid;
    }

    /// @notice Fallback function to receive native tokens as gas fees
    receive() external payable {}

    /// @notice Pauses the contract
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Withdraws unexpectedly received tokens
    /// @param _token Address of the token to be withdrawn
    /// @param _to Address to receive the withdrawn tokens
    /// @param _amount Amount of tokens to be withdrawn
    function rescueWithdraw(address _token, address _to, uint256 _amount) external onlyOwner {
        if (_token == address(0)) {
            (bool sent, ) = _to.call{ value: _amount }("");
            if (!sent) {
                revert FailedToSendRescuedFund(_to, _amount);
            }
        } else {
            IERC20(_token).safeTransfer(_to, _amount);
        }
    }

    /// @notice Enables or disables a route for receiving messages from a sender
    /// @param _sender Address of the sender
    /// @param _authorized Flag to authorize or deauthorize the sender
    function updateAuthorizedSender(address _sender, bool _authorized) external onlyOwner whenNotPaused {
        authorizedSenders[_sender] = _authorized;
        emit AuthorizedSenderUpdated(_sender, _authorized);
    }

    /// @notice Updates the route for a specific sender by the owner
    /// @param _receiver Address of the receiver
    /// @param _sender Address of the sender
    /// @param _allowed Flag to allow or disallow the route
    function updateRouteByOwner(address _receiver, address _sender, bool _allowed) external onlyOwner {
        // NOTE: This function gives the owner of the Abridge contract too much power.
        // If you need a more self-sovereign solution, remove this function.
        _routes[_receiver].allowed[_sender] = _allowed;
        emit RouteUpdated(_receiver, _sender, _allowed);
    }

    /// @notice Updates the route for a specific sender
    /// @param _sender Address of the sender
    /// @param _allowed Flag to allow or disallow the route
    function updateRoute(address _sender, bool _allowed) external whenNotPaused {
        _routes[msg.sender].allowed[_sender] = _allowed;
        emit RouteUpdated(msg.sender, _sender, _allowed);
    }

    /// @notice Sends a message through the bridge
    /// @param _receiver Address of the receiver
    /// @param _executeGasLimit Gas limit for execution
    /// @param _msg The message to be sent
    /// @return _guid The unique identifier for the sent message
    function send(
        address _receiver,
        uint128 _executeGasLimit,
        bytes memory _msg
    ) external payable onlyAuthorizedSender whenNotPaused returns (bytes32 _guid) {
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(_executeGasLimit, 0);
        bytes memory rawMsg = RoutedData.encode(msg.sender, _receiver, _msg);
        MessagingFee memory fee = _quote(eid, rawMsg, options, false);
        if (msg.value < fee.nativeFee) {
            revert InsufficientFee(msg.value, fee.nativeFee);
        }
        // always provide all value received so that unused fee will be fully refunded to msg.sender
        fee.nativeFee = msg.value;
        MessagingReceipt memory receipt = _lzSend(eid, rawMsg, options, fee, msg.sender);
        emit MessageSent(msg.sender, _receiver, receipt.guid, fee.nativeFee);
        return receipt.guid;
    }

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
    ) external view returns (address _token, uint256 _fee) {
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(_executeGasLimit, 0);
        bytes memory rawMsg = RoutedData.encode(msg.sender, _receiver, _msg);
        MessagingFee memory fee = _quote(eid, rawMsg, options, false);
        return (address(0), fee.nativeFee);
    }

    /// @notice Transfers ownership of the contract to a new owner using a 2-step process
    /// @param newOwner The address of the new owner
    function transferOwnership(address newOwner) public override(Ownable, Ownable2Step) {
        // call ownable2step transferOwnership
        Ownable2Step.transferOwnership(newOwner);
    }

    /// @dev Internal function to implement lzReceive logic without
    /// needing to copy the basic parameter validation.
    /// @param _guid The unique identifier for the received LayerZero message
    /// @param _message The payload of the received message
    function _lzReceive(
        Origin calldata /*_origin*/,
        bytes32 _guid,
        bytes calldata _message,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal override whenNotPaused {
        (address from, address to, bytes memory rawMsg) = RoutedData.decode(_message);

        // Check if the route is allowed
        if (!_routes[to].allowed[from]) {
            revert DisallowedRoute(from, to);
        }

        // Call the receiver's handleMessage function and verify the response
        bytes4 res = IAbridgeMessageHandler(to).handleMessage(from, rawMsg, _guid);
        if (res != IAbridgeMessageHandler.handleMessage.selector) {
            revert InvalidReceiverResponse(res);
        }

        // Emit event for successful message processing
        emit MessageReceived(from, to, _guid);
    }

    /// @dev Internal function to transfer ownership of the contract to a new owner using a 2-step process.
    /// @param newOwner The address of the new owner
    function _transferOwnership(address newOwner) internal override(Ownable, Ownable2Step) {
        // Call Ownable2Step's _transferOwnership function
        Ownable2Step._transferOwnership(newOwner);
    }

    /// @dev Override this function to allow sending more msg.value to Abridge as redundant fee.
    /// @param _nativeFee The required fee amount in native cryptocurrency (e.g., Ether).
    /// @return nativeFee The validated fee amount that matches the required _nativeFee.
    function _payNative(uint256 _nativeFee) internal virtual override returns (uint256 nativeFee) {
        if (msg.value < _nativeFee) revert NotEnoughNative(msg.value);
        return _nativeFee;
    }
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