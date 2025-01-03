// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IAbridgeMessageHandler} from "../interfaces/IAbridge.sol";
import {IAbridge} from "../interfaces/IAbridge.sol";
import {Ownable2Step, Ownable} from "@openzeppelin-v5.0.0/contracts/access/Ownable2Step.sol";
import {ILightStakeRegistry} from "../interfaces/ILightStakeRegistry.sol";
import {IRegistryStateReceiver} from "../interfaces/IRegistryStateReceiver.sol";
import {ECDSAStakeRegistryStorage, Quorum, StrategyParams} from "../avs/ECDSAStakeRegistryStorage.sol";

contract RegistryStateReceiver is IRegistryStateReceiver, Ownable2Step {
    IAbridge public immutable abridge;
    address public immutable sender;
    ILightStakeRegistry public immutable stakeRegistry;

    error InvalidSender();
    error UpdateRouteFailed();
    error InvalidMessageType();

    constructor(
        address _abridge, 
        address _sender, 
        address _stakeRegistry,
        address _owner
    ) Ownable(_owner) {
        abridge = IAbridge(_abridge);
        sender = _sender;
        stakeRegistry = ILightStakeRegistry(_stakeRegistry);
        abridge.updateRoute(sender, true);
    }

    function handleMessage(
        address from,
        bytes calldata message,
        bytes32 /*guid*/
    ) external returns (bytes4) {
        if (from != sender) revert InvalidSender();

        // Decode message type
        (MessageType msgType) = abi.decode(message[:32], (MessageType));
        bytes memory data = message[32:];

        if (msgType == MessageType.REGISTER) {
            (address operator) = abi.decode(data, (address));
            stakeRegistry.registerOperator(operator, address(0));
        } 
        else if (msgType == MessageType.DEREGISTER) {
            (address operator) = abi.decode(data, (address));
            stakeRegistry.deregisterOperator(operator);
        }
        else if (msgType == MessageType.UPDATE_SIGNING_KEY) {
            (address operator, address newKey) = abi.decode(data, (address, address));
            stakeRegistry.updateOperatorSigningKey(operator, newKey);
        }
        else if (msgType == MessageType.UPDATE_OPERATORS) {
            (address[] memory operators) = abi.decode(data, (address[]));
            stakeRegistry.updateOperators(operators);
        }
        else if (msgType == MessageType.UPDATE_QUORUM) {
            (Quorum memory quorum, address[] memory operators) = 
                abi.decode(data, (Quorum, address[]));
            stakeRegistry.updateQuorumConfig(quorum, operators);
        }
        else if (msgType == MessageType.UPDATE_MIN_WEIGHT) {
            (uint256 newMinWeight, address[] memory operators) = 
                abi.decode(data, (uint256, address[]));
            stakeRegistry.updateMinimumWeight(newMinWeight, operators);
        }
        else if (msgType == MessageType.UPDATE_THRESHOLD) {
            (uint256 thresholdWeight) = abi.decode(data, (uint256));
            stakeRegistry.updateStakeThreshold(thresholdWeight);
        }
        else if (msgType == MessageType.UPDATE_OPERATORS_QUORUM) {
            (address[][] memory operatorsPerQuorum) = abi.decode(data, (address[][]));
            stakeRegistry.updateOperatorsForQuorum(operatorsPerQuorum);
        }
        else {
            revert InvalidMessageType();
        }

        return IAbridgeMessageHandler.handleMessage.selector;
    }

    // update route settings
    function updateRoute(bool allowed) external onlyOwner {
        abridge.updateRoute(sender, allowed);
    }
}
