// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IRegistryStateSender} from "../interfaces/IRegistryStateSender.sol";
import {IAbridge} from "../interfaces/IAbridge.sol";
import {ECDSAStakeRegistryStorage, Quorum, StrategyParams} from "../avs/ECDSAStakeRegistryStorage.sol";
import {Ownable2Step, Ownable} from "@openzeppelin-v5.0.0/contracts/access/Ownable2Step.sol";

contract RegistryStateSender is IRegistryStateSender, Ownable2Step {
    IAbridge public immutable abridge;
    address public immutable receiver;

    // gas limit for cross chain message
    uint128 private constant EXECUTE_GAS_LIMIT = 500_000;

    error InsufficientFee();

    constructor(address _abridge, address _receiver, address _owner) Ownable(_owner) {
        abridge = IAbridge(_abridge);
        receiver = _receiver;
    }

    function registerOperator(address operator, address signingKey) external {
        bytes memory data = abi.encode(
            MessageType.REGISTER,
            operator,
            signingKey
        );
        _sendMessage(data);
    }

    function deregisterOperator(address operator) external {
        bytes memory data = abi.encode(
            MessageType.DEREGISTER,
            operator
        );
        _sendMessage(data);
    }

    function updateOperatorSigningKey(address operator, address newSigningKey) external {
        bytes memory data = abi.encode(
            MessageType.UPDATE_SIGNING_KEY,
            operator,
            newSigningKey
        );
        _sendMessage(data);
    }

    function updateOperators(address[] memory operators) external {
        bytes memory data = abi.encode(
            MessageType.UPDATE_OPERATORS,
            operators
        );
        _sendMessage(data);
    }

    function updateQuorumConfig(Quorum memory _quorum, address[] memory _operators) external {
        bytes memory data = abi.encode(
            MessageType.UPDATE_QUORUM,
            _quorum,
            _operators
        );
        _sendMessage(data);
    }

    function updateMinimumWeight(uint256 _newMinimumWeight, address[] memory _operators) external {
        bytes memory data = abi.encode(
            MessageType.UPDATE_MIN_WEIGHT,
            _newMinimumWeight,
            _operators
        );
        _sendMessage(data);
    }

    function updateStakeThreshold(uint256 _thresholdWeight) external {
        bytes memory data = abi.encode(
            MessageType.UPDATE_THRESHOLD,
            _thresholdWeight
        );
        _sendMessage(data);
    }

    function updateOperatorsForQuorum(address[] memory operatorsPerQuorum) external {
        bytes memory data = abi.encode(
            MessageType.UPDATE_OPERATORS_QUORUM,
            operatorsPerQuorum
        );
        _sendMessage(data);
    }

    function _sendMessage(bytes memory data) internal {
        (, uint256 fee) = abridge.estimateFee(receiver, EXECUTE_GAS_LIMIT, data);
        if (msg.value < fee) revert InsufficientFee();
        
        abridge.send{value: msg.value}(receiver, EXECUTE_GAS_LIMIT, data);
    }
}
