// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {
    ECDSAStakeRegistryStorage, Quorum, StrategyParams
} from "../avs/ECDSAStakeRegistryStorage.sol";
interface IRegistryStateSender {

    enum MessageType {
        REGISTER,
        DEREGISTER,
        UPDATE_SIGNING_KEY,
        UPDATE_OPERATORS,
        UPDATE_QUORUM,
        UPDATE_MIN_WEIGHT,
        UPDATE_THRESHOLD,
        UPDATE_OPERATORS_QUORUM
    }

    function registerOperator(address operator, address signingKey) external;
    function updateOperatorSigningKey(address operator, address newSigningKey) external;
    function updateOperators(address[] memory operators) external;
    function deregisterOperator(address operator) external;
    function updateQuorumConfig(Quorum memory _quorum, address[] memory _operators) external;
    function updateMinimumWeight(uint256 _newMinimumWeight, address[] memory _operators) external;
    function updateStakeThreshold(uint256 _thresholdWeight) external;
    function updateOperatorsForQuorum(address[] memory operatorsPerQuorum) external;    
}
