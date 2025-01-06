// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {ISignatureUtils} from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import {Quorum, StrategyParams} from "../interfaces/IECDSAStakeRegistryEventsAndErrors.sol";
import {IEpochManager} from "../interfaces/IEpochManager.sol";

interface ILightStakeRegistry {
    /**
     * @notice Emitted when an operator is registered
     * @param operator The address of the registered operator
     * @param serviceManager The address of the service manager
     */
    event OperatorRegistered(address indexed operator, address indexed serviceManager);

    /**
     * @notice Emitted when an operator is deregistered
     * @param operator The address of the deregistered operator
     * @param serviceManager The address of the service manager
     */
    event OperatorDeregistered(address indexed operator, address indexed serviceManager);

    /**
     * @notice Emitted when an operator's signing key is updated
     * @param operator The address of the operator
     * @param epochNumber The epoch number when the update occurred
     * @param newSigningKey The new signing key
     * @param oldSigningKey The old signing key
     */
    event SigningKeyUpdate(
        address indexed operator, uint32 epochNumber, address newSigningKey, address oldSigningKey
    );

    /**
     * @notice Emitted when the quorum configuration is updated
     * @param oldQuorum The old quorum configuration
     * @param newQuorum The new quorum configuration
     */
    event QuorumUpdated(Quorum oldQuorum, Quorum newQuorum);

    /**
     * @notice Emitted when the threshold weight is updated
     * @param newThresholdWeight The new threshold weight
     */
    event ThresholdWeightUpdated(uint256 newThresholdWeight);

    event OperatorsUpdated(address[] operators, uint256[] newWeights, uint256 newTotalWeight);

    // View Functions
    function quorum() external view returns (Quorum memory);

    function getLastestOperatorSigningKey(
        address _operator
    ) external view returns (address);

    function getOperatorSigningKeyAtEpoch(
        address _operator,
        uint32 _epochNumber
    ) external view returns (address);

    function getLastCheckpointOperatorWeight(
        address _operator
    ) external view returns (uint256);

    function getLastCheckpointTotalWeight() external view returns (uint256);

    function getLastCheckpointThresholdWeight() external view returns (uint256);

    function getOperatorWeightAtEpoch(
        address _operator,
        uint32 _epochNumber
    ) external view returns (uint256);

    function getTotalWeightAtEpoch(
        uint32 _epochNumber
    ) external view returns (uint256);

    function getLastCheckpointThresholdWeightAtEpoch(
        uint32 _epochNumber
    ) external view returns (uint256);

    function operatorRegistered(
        address _operator
    ) external view returns (bool);

    function minimumWeight() external view returns (uint256);

    function isValidSignature(
        bytes32 _dataHash,
        bytes memory _signatureData
    ) external view returns (bytes4);

    // State changing functions
    function processEpochUpdate(
        IEpochManager.StateUpdate[] memory updates
    ) external;
}
