// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IAbridge} from "../../src/interfaces/IAbridge.sol";

contract MockAbridge is IAbridge {
    // Mock fee amount
    uint256 public constant MOCK_FEE = 0.01 ether;
    uint32 public constant MOCK_EID = 1;

    // Mapping to track authorized senders
    mapping(address => bool) public authorizedSenders;
    
    // Mapping to track allowed routes
    mapping(address => mapping(address => bool)) private routes;

    bool public shouldRevert;
    uint256 private fee;
    address private lastTarget;
    uint128 private lastGasLimit;
    bytes private lastMessage;

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function setFee(uint256 _fee) external {
        fee = _fee;
    }

    function lastSendCall() external view returns (address target, uint128 gasLimit, bytes memory message) {
        return (lastTarget, lastGasLimit, lastMessage);
    }

    function updateRoute(address _sender, bool _allowed) external {
        routes[msg.sender][_sender] = _allowed;
        emit RouteUpdated(msg.sender, _sender, _allowed);
    }

    function send(
        address _receiver,
        uint128 _executeGasLimit,
        bytes memory _msg
    ) external payable returns (bytes32 _guid) {
        if (msg.value < MOCK_FEE) {
            revert InsufficientFee(msg.value, MOCK_FEE);
        }

        if (!authorizedSenders[msg.sender]) {
            revert UnauthorizedSender(msg.sender);
        }

        if (!routes[_receiver][msg.sender]) {
            revert DisallowedRoute(msg.sender, _receiver);
        }

        // Store last call parameters
        lastTarget = _receiver;
        lastGasLimit = _executeGasLimit;
        lastMessage = _msg;

        _guid = keccak256(abi.encodePacked(msg.sender, _receiver, block.number));
        emit MessageSent(msg.sender, _receiver, _guid, msg.value);
        return _guid;
    }

    function eid() external pure returns (uint32) {
        return MOCK_EID;
    }

    function estimateFee(
        address /*_receiver*/,
        uint128 /*_executeGasLimit*/,
        bytes memory /*_msg*/
    ) external pure returns (address _token, uint256 _fee) {
        return (address(0), MOCK_FEE);
    }

    // Helper functions for testing
    function setAuthorizedSender(address sender, bool authorized) external {
        authorizedSenders[sender] = authorized;
        emit AuthorizedSenderUpdated(sender, authorized);
    }

    function setRoute(address receiver, address sender, bool allowed) external {
        routes[receiver][sender] = allowed;
        emit RouteUpdated(receiver, sender, allowed);
    }

    function emitMessageReceived(address sender, address receiver, bytes32 guid) external {
        emit MessageReceived(sender, receiver, guid);
    }
} 