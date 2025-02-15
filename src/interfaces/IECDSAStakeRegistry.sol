// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {ISignatureUtils} from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import {
    ECDSAStakeRegistryStorage, Quorum, StrategyParams
} from "../avs/ECDSAStakeRegistryStorage.sol";

interface IECDSAStakeRegistry {

    event OperatorRegistered(
        address indexed _operator,
        uint256 indexed blockNumber,
        address indexed _signingKey,
        uint256 timestamp,
        address _avs
    );

    /**
     * @notice Emitted when an operator is deregistered
     * @param operator The address of the deregistered operator
     * @param serviceManager The address of the service manager
     */
    event OperatorDeregistered(address indexed operator, address indexed serviceManager);

    /**
     * @notice Emitted when an operator's signing key is updated
     * @param operator The address of the operator
     * @param newSigningKey The new signing key
     * @param oldSigningKey The old signing key
     */
    event SigningKeyUpdate(
        address indexed operator, address newSigningKey, address oldSigningKey
    );

    /**
     * @notice Emitted when an operator's weight is updated
     * @param operator The address of the operator
     * @param oldWeight The old weight
     * @param newWeight The new weight
     */
    event OperatorWeightUpdated(address indexed operator, uint256 oldWeight, uint256 newWeight);

    /**
     * @notice Emitted when the total weight is updated
     * @param oldTotalWeight The old total weight
     * @param newTotalWeight The new total weight
     */
    event TotalWeightUpdated(uint256 oldTotalWeight, uint256 newTotalWeight);

    /**
     * @notice Emitted when the threshold weight is updated
     * @param newThresholdWeight The new threshold weight
     */
    event ThresholdWeightUpdated(uint256 newThresholdWeight);

    /**
     * @notice Emitted when the minimum weight is updated
     * @param oldMinimumWeight The old minimum weight
     * @param newMinimumWeight The new minimum weight
     */
    event MinimumWeightUpdated(uint256 oldMinimumWeight, uint256 newMinimumWeight);

    /**
     * @notice Emitted when the quorum configuration is updated
     * @param oldQuorum The old quorum configuration
     * @param newQuorum The new quorum configuration
     */
    event QuorumUpdated(Quorum oldQuorum, Quorum newQuorum);

    // Write Functions
    function initialize(
        uint256 _thresholdWeight,
        Quorum memory _quorum
    ) external;

    function registerOperatorWithSignature(
        ISignatureUtils.SignatureWithSaltAndExpiry memory _operatorSignature,
        address _signingKey
    ) external;

    function deregisterOperator() external;

    function updateOperatorSigningKey(
        address _newSigningKey
    ) external;

    function updateOperators(
        address[] memory _operators
    ) external;

    function updateQuorumConfig(Quorum memory _quorum, address[] memory _operators) external;

    function updateMinimumWeight(uint256 _newMinimumWeight, address[] memory _operators) external;

    function updateStakeThreshold(
        uint256 _thresholdWeight
    ) external;

    function updateOperatorsForQuorum(
        address[][] memory operatorsPerQuorum,
        bytes memory
    ) external;

    // View Functions
    function quorum() external view returns (Quorum memory);

    function minimumWeight() external view returns (uint256);

    function getLastestOperatorSigningKey(
        address _operator
    ) external view returns (address);

    function getOperatorSigningKeyAtEpoch(
        address _operator,
        uint32 _epochNumber
    ) external view returns (address);

    function getOperatorBySigningKey(
        address _signingKey
    ) external view returns (address);

    function operatorRegistered(
        address operator
    ) external view returns (bool);

    function getOperatorWeightAtEpoch(
        address operator,
        uint32 epochNumber
    ) external view returns (uint256);

    function getLastCheckpointOperatorWeight(
        address operator
    ) external view returns (uint256);

    function getLastCheckpointTotalWeight() external view returns (uint256);

    function getLastCheckpointThresholdWeight() external view returns (uint256);

    function getTotalWeightAtEpoch(
        uint32 _epochNumber
    ) external view returns (uint256);

    function getThresholdWeightAtEpoch(
        uint32 _epochNumber
    ) external view returns (uint256);

    function isValidSignature(
        bytes32 _dataHash,
        bytes memory _signatureData
    ) external view returns (bytes4);
}
