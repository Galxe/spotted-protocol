// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IAbridgeMessageHandler} from "../interfaces/IAbridge.sol";
import {IAbridge} from "../interfaces/IAbridge.sol";
import {Ownable2Step, Ownable} from "@openzeppelin-v5.0.0/contracts/access/Ownable2Step.sol";

contract RegistryStateReceiver is IAbridgeMessageHandler, Ownable2Step {
    IAbridge public immutable abridge;
    address public immutable sender;

    // operator states
    mapping(address => uint256) public operatorWeights;
    mapping(address => address) public operatorSigningKeys;

    error InvalidSender();
    error UpdateRouteFailed();

    constructor(address _abridge, address _sender, address _owner) Ownable(_owner) {
        abridge = IAbridge(_abridge);
        sender = _sender;

        // Enable route from sender
        abridge.updateRoute(sender, true);
    }

    // update route settings
    function updateRoute(
        bool allowed
    ) external onlyOwner {
        abridge.updateRoute(sender, allowed);
    }

    function handleMessage(
        address from,
        bytes calldata message,
        bytes32 /*guid*/
    ) external returns (bytes4) {
        if (from != sender) revert InvalidSender();

        // decode operators data
        (address[] memory operators, uint256[] memory weights, address[] memory signingKeys) =
            abi.decode(message, (address[], uint256[], address[]));

        // update states
        uint256 operatorsLength = operators.length;
        for (uint256 i = 0; i < operatorsLength;) {
            address operator = operators[i];
            operatorWeights[operator] = weights[i];
            operatorSigningKeys[operator] = signingKeys[i];

            emit OperatorStateUpdated(operator, weights[i], signingKeys[i]);
            unchecked {
                ++i;
            }
        }

        return IAbridgeMessageHandler.handleMessage.selector;
    }

    // Get operator's complete state
    function getOperatorState(
        address operator
    ) external view returns (uint256 weight, address signingKey) {
        weight = operatorWeights[operator];
        signingKey = operatorSigningKeys[operator];
    }

    event OperatorStateUpdated(address indexed operator, uint256 weight, address signingKey);
}
