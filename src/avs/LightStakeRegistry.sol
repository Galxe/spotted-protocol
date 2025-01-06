// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {LightStakeRegistryStorage, Quorum, StrategyParams} from "./LightStakeRegistryStorage.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {IDelegationManager} from
    "eigenlayer-contracts/src/contracts/interfaces/IDelegationManager.sol";
import {ISignatureUtils} from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import {IServiceManager} from "../interfaces/IServiceManager.sol";

import {OwnableUpgradeable} from "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import {SignatureCheckerUpgradeable} from
    "@openzeppelin-upgrades/contracts/utils/cryptography/SignatureCheckerUpgradeable.sol";
import {IERC1271Upgradeable} from
    "@openzeppelin-upgrades/contracts/interfaces/IERC1271Upgradeable.sol";
import {ILightStakeRegistry} from "../interfaces/ILightStakeRegistry.sol";
import {EpochCheckpointsUpgradeable} from "../libraries/EpochCheckpointsUpgradeable.sol";
import {IEpochManager} from "../interfaces/IEpochManager.sol";

contract LightStakeRegistry is
    IERC1271Upgradeable,
    OwnableUpgradeable,
    LightStakeRegistryStorage
{
    using SignatureCheckerUpgradeable for address;
    using EpochCheckpointsUpgradeable for EpochCheckpointsUpgradeable.History;

    constructor(
        address _epochManager,
        address _registryStateReceiver
    ) LightStakeRegistryStorage(_epochManager, _registryStateReceiver) {
        // _disableInitializers();
    }

    modifier onlyStateReceiver() {
        require(msg.sender == address(REGISTRY_STATE_RECEIVER), "Invalid sender");
        _;
    }

    /// @notice Initializes the contract with the given parameters.
    /// @param _thresholdWeight The threshold weight in basis points.
    /// @param _initialQuorum The initial quorum struct containing the details of the quorum thresholds.
    function initialize(
        uint256 _thresholdWeight,
        Quorum memory _initialQuorum
    ) external initializer {
        __LightStakeRegistry_init(_thresholdWeight, _initialQuorum);
    }

    /// @notice Verifies if the provided signature data is valid for the given data hash.
    /// @param _dataHash The hash of the data that was signed.
    /// @param _signatureData Encoded signature data consisting of an array of operators, an array of signatures, and a reference block number.
    /// @return The function selector that indicates the signature is valid according to ERC1271 standard.
    function isValidSignature(
        bytes32 _dataHash,
        bytes memory _signatureData
    ) external view returns (bytes4) {
        (address[] memory operators, bytes[] memory signatures, uint32 referenceEpoch) =
            abi.decode(_signatureData, (address[], bytes[], uint32));
        _checkSignatures(_dataHash, operators, signatures, referenceEpoch);
        return IERC1271Upgradeable.isValidSignature.selector;
    }

    /// @notice Retrieves the current stake quorum details.
    /// @return Quorum - The current quorum of strategies and weights
    function quorum() external view returns (Quorum memory) {
        return _quorum;
    }

    /**
     * @notice Retrieves the latest signing key for a given operator.
     * @param _operator The address of the operator.
     * @return The latest signing key of the operator.
     */
    function getLastestOperatorSigningKey(
        address _operator
    ) external view returns (address) {
        return address(uint160(_operatorSigningKeyHistory[_operator].latest()));
    }

    /**
     * @notice Retrieves the latest signing key for a given operator at a specific block number.
     * @param _operator The address of the operator.
     * @param _epochNumber The epoch number to get the operator's signing key.
     * @return The signing key of the operator at the given epoch.
     */
    function getOperatorSigningKeyAtEpoch(
        address _operator,
        uint32 _epochNumber
    ) external view returns (address) {
        return address(uint160(_operatorSigningKeyHistory[_operator].getAtEpoch(_epochNumber)));
    }

    /// @notice Retrieves the last recorded weight for a given operator.
    /// @param _operator The address of the operator.
    /// @return uint256 - The latest weight of the operator.
    function getLastCheckpointOperatorWeight(
        address _operator
    ) external view returns (uint256) {
        return _operatorWeightHistory[_operator].latest();
    }

    /// @notice Retrieves the last recorded total weight across all operators.
    /// @return uint256 - The latest total weight.
    function getLastCheckpointTotalWeight() external view returns (uint256) {
        return _totalWeightHistory.latest();
    }

    /// @notice Retrieves the last recorded threshold weight
    /// @return uint256 - The latest threshold weight.
    function getLastCheckpointThresholdWeight() external view returns (uint256) {
        return _thresholdWeightHistory.latest();
    }

    /// @notice Retrieves the operator's weight at a specific epoch number.
    /// @param _operator The address of the operator.
    /// @param _epochNumber The epoch number to get the operator weight for the quorum
    /// @return uint256 - The weight of the operator at the given epoch.
    function getOperatorWeightAtEpoch(
        address _operator,
        uint32 _epochNumber
    ) external view returns (uint256) {
        return _operatorWeightHistory[_operator].getAtEpoch(_epochNumber);
    }

    /// @notice Retrieves the total weight at a specific epoch number.
    /// @param _epochNumber The epoch number to get the total weight for the quorum
    /// @return uint256 - The total weight at the given epoch.
    function getTotalWeightAtEpoch(
        uint32 _epochNumber
    ) external view returns (uint256) {
        return _totalWeightHistory.getAtEpoch(_epochNumber);
    }

    /// @notice Retrieves the threshold weight at a specific epoch number.
    /// @param _epochNumber The epoch number to get the threshold weight for the quorum
    /// @return uint256 - The threshold weight the given epoch.
    function getLastCheckpointThresholdWeightAtEpoch(
        uint32 _epochNumber
    ) external view returns (uint256) {
        return _thresholdWeightHistory.getAtEpoch(_epochNumber);
    }

    function operatorRegistered(
        address _operator
    ) external view returns (bool) {
        return _operatorRegistered[_operator];
    }

    /// @notice Returns the weight an operator must have to contribute to validating an AVS
    function minimumWeight() external view returns (uint256) {
        return _minimumWeight;
    }

    /// @notice Initializes state for the StakeRegistry
    /// @param _thresholdWeight The threshold weight in basis points.
    /// @param _initialQuorum The initial quorum struct containing the details of the quorum thresholds.
    function __LightStakeRegistry_init(
        uint256 _thresholdWeight,
        Quorum memory _initialQuorum
    ) internal onlyInitializing {
        _updateStakeThreshold(_thresholdWeight);
        _updateQuorumConfig(_initialQuorum);
        __Ownable_init();
    }

    /**
     * @notice Common logic to verify a batch of ECDSA signatures against a hash, using either last stake weight or at a specific block.
     * @param _dataHash The hash of the data the signers endorsed.
     * @param _operators A collection of addresses that endorsed the data hash.
     * @param _signatures A collection of signatures matching the signers.
     * @param _referenceEpoch The epoch number for evaluating stake weight; use max uint32 for latest weight.
     */
    function _checkSignatures(
        bytes32 _dataHash,
        address[] memory _operators,
        bytes[] memory _signatures,
        uint32 _referenceEpoch
    ) internal view {
        uint256 signersLength = _operators.length;
        address currentOperator;
        address lastOperator;
        address signer;
        uint256 signedWeight;

        _validateSignaturesLength(signersLength, _signatures.length);

        for (uint256 i; i < signersLength; i++) {
            currentOperator = _operators[i];
            signer = _getOperatorSigningKey(currentOperator, _referenceEpoch);

            _validateSortedSigners(lastOperator, currentOperator);
            _validateSignature(signer, _dataHash, _signatures[i]);

            lastOperator = currentOperator;
            uint256 operatorWeight = _getOperatorWeight(currentOperator, _referenceEpoch);
            signedWeight += operatorWeight;
        }

        _validateThresholdStake(signedWeight, _referenceEpoch);
    }

    /// @notice Validates that the number of signers equals the number of signatures, and neither is zero.
    /// @param _signersLength The number of signers.
    /// @param _signaturesLength The number of signatures.
    function _validateSignaturesLength(
        uint256 _signersLength,
        uint256 _signaturesLength
    ) internal pure {
        if (_signersLength != _signaturesLength) {
            revert LengthMismatch();
        }
        if (_signersLength == 0) {
            revert InvalidLength();
        }
    }

    /// @notice Ensures that signers are sorted in ascending order by address.
    /// @param _lastSigner The address of the last signer.
    /// @param _currentSigner The address of the current signer.
    function _validateSortedSigners(address _lastSigner, address _currentSigner) internal pure {
        if (_lastSigner >= _currentSigner) {
            revert NotSorted();
        }
    }

    /// @notice Validates a given signature against the signer's address and data hash.
    /// @param _signer The address of the signer to validate.
    /// @param _dataHash The hash of the data that is signed.
    /// @param _signature The signature to validate.
    function _validateSignature(
        address _signer,
        bytes32 _dataHash,
        bytes memory _signature
    ) internal view {
        if (!_signer.isValidSignatureNow(_dataHash, _signature)) {
            revert InvalidSignature();
        }
    }

    function _updateStakeThreshold(
        uint256 _thresholdWeight
    ) internal {
        _thresholdWeightHistory.push(_thresholdWeight);
        emit ThresholdWeightUpdated(_thresholdWeight);
    }

    /// @notice Updates the quorum configuration
    /// @dev Replaces the current quorum configuration with `_newQuorum` if valid.
    /// Reverts with `InvalidQuorum` if the new quorum configuration is not valid.
    /// Emits `QuorumUpdated` event with the old and new quorum configurations.
    /// @param _newQuorum The new quorum configuration to set.
    function _updateQuorumConfig(
        Quorum memory _newQuorum
    ) internal {
        // 获取当前的quorum配置作为oldQuorum
        Quorum memory oldQuorum = Quorum({strategies: _quorum.strategies});

        // 清除当前quorum配置
        delete _quorum.strategies;

        // 设置新的quorum配置
        for (uint256 i; i < _newQuorum.strategies.length; i++) {
            _quorum.strategies.push(_newQuorum.strategies[i]);
        }

        emit QuorumUpdated(oldQuorum, _newQuorum);
    }

    /// @notice Retrieves the operator weight for a signer, either at the last checkpoint or a specified block.
    /// @param _operator The operator to query their signing key history for
    /// @param _referenceEpoch The epoch number to query the operator's weight at, or the maximum uint32 value for the last checkpoint.
    /// @return The weight of the operator.
    function _getOperatorSigningKey(
        address _operator,
        uint32 _referenceEpoch
    ) internal view returns (address) {
        return address(uint160(_operatorSigningKeyHistory[_operator].getAtEpoch(_referenceEpoch)));
    }

    /// @notice Retrieves the operator weight for a signer, either at the last checkpoint or a specified block.
    /// @param _operator The operator to query their signing key history for
    /// @param _referenceEpoch The epoch number to query the operator's weight at, or the maximum uint32 value for the last checkpoint.
    /// @return The weight of the operator.
    function _getOperatorWeight(
        address _operator,
        uint32 _referenceEpoch
    ) internal view returns (uint256) {
        return _operatorWeightHistory[_operator].getAtEpoch(_referenceEpoch);
    }

    /// @notice Retrieve the total stake weight at a specific epoch or the latest if not specified.
    /// @param _referenceEpoch The epoch number to retrieve the total stake weight from.
    /// @return The total stake weight at the given epoch or the latest if the given epoch is the max uint32 value.
    function _getTotalWeight(
        uint32 _referenceEpoch
    ) internal view returns (uint256) {
        return _totalWeightHistory.getAtEpoch(_referenceEpoch);
    }

    /// @notice Retrieves the threshold stake for a given reference block.
    /// @param _referenceEpoch The epoch number to query the threshold stake for.
    /// If set to the maximum uint32 value, it retrieves the latest threshold stake.
    /// @return The threshold stake in basis points for the reference block.
    function _getThresholdStake(
        uint32 _referenceEpoch
    ) internal view returns (uint256) {
        return _thresholdWeightHistory.getAtEpoch(_referenceEpoch);
    }

    /// @notice Validates that the cumulative stake of signed messages meets or exceeds the required threshold.
    /// @param _signedWeight The cumulative weight of the signers that have signed the message.
    /// @param _referenceEpoch The epoch number to verify the stake threshold for
    function _validateThresholdStake(uint256 _signedWeight, uint32 _referenceEpoch) internal view {
        uint256 totalWeight = _getTotalWeight(_referenceEpoch);
        if (_signedWeight > totalWeight) {
            revert InvalidSignedWeight();
        }
        uint256 thresholdStake = _getThresholdStake(_referenceEpoch);
        if (thresholdStake > _signedWeight) {
            revert InsufficientSignedStake();
        }
    }

    function processEpochUpdate(
        uint256 epoch,
        IEpochManager.StateUpdate[] memory updates
    ) external onlyStateReceiver {
        require(epoch >= EPOCH_MANAGER.currentEpoch() + 1, "Invalid epoch");

        // 处理每个update
        for (uint256 i = 0; i < updates.length; i++) {
            IEpochManager.StateUpdate memory update = updates[i];

            // 根据消息类型调用对应的处理函数
            if (update.updateType == IEpochManager.MessageType.REGISTER) {
                _handleRegister(update.data);
            } else if (update.updateType == IEpochManager.MessageType.DEREGISTER) {
                _handleDeregister(update.data);
            } else if (update.updateType == IEpochManager.MessageType.UPDATE_SIGNING_KEY) {
                _handleUpdateSigningKey(update.data);
            } else if (update.updateType == IEpochManager.MessageType.UPDATE_OPERATORS) {
                _handleUpdateOperators(update.data);
            } else if (update.updateType == IEpochManager.MessageType.UPDATE_QUORUM) {
                _handleUpdateQuorum(update.data);
            } else if (update.updateType == IEpochManager.MessageType.UPDATE_MIN_WEIGHT) {
                _handleUpdateMinWeight(update.data);
            } else if (update.updateType == IEpochManager.MessageType.UPDATE_THRESHOLD) {
                _handleUpdateThreshold(update.data);
            } else if (update.updateType == IEpochManager.MessageType.UPDATE_OPERATORS_FOR_QUORUM) {
                _handleUpdateOperatorsForQuorum(update.data);
            } else {
                revert("Invalid message type");
            }
        }
    }

    // 处理注册操作
    function _handleRegister(
        bytes memory data
    ) internal {
        (address operator, address signingKey, uint256 newWeight, uint256 newTotalWeight) =
            abi.decode(data, (address, address, uint256, uint256));

        _totalOperators += 1;
        _operatorRegistered[operator] = true;
        _operatorSigningKeyHistory[operator].push(uint160(signingKey));
        _operatorWeightHistory[operator].push(newWeight);
        _totalWeightHistory.push(newTotalWeight);

        emit OperatorRegistered(operator);
    }

    function _handleDeregister(
        bytes memory data
    ) internal {
        (address operator, uint256 newWeight, uint256 newTotalWeight) =
            abi.decode(data, (address, uint256, uint256));

        _totalOperators -= 1;
        delete _operatorRegistered[operator];

        // 更新operator的weight和total weight
        _operatorWeightHistory[operator].push(newWeight);
        _totalWeightHistory.push(newTotalWeight);

        emit OperatorDeregistered(operator);
    }

    function _handleUpdateSigningKey(
        bytes memory data
    ) internal {
        (address operator, address newSigningKey) = abi.decode(data, (address, address));

        address oldSigningKey = address(uint160(_operatorSigningKeyHistory[operator].latest()));
        if (newSigningKey == oldSigningKey) {
            return;
        }
        _operatorSigningKeyHistory[operator].push(uint160(newSigningKey));

        emit SigningKeyUpdate(operator, newSigningKey, oldSigningKey);
    }

    function _handleUpdateOperators(
        bytes memory data
    ) internal {
        (address[] memory operators, uint256[] memory newWeights, uint256 newTotalWeight) =
            abi.decode(data, (address[], uint256[], uint256));
        uint256 operatorsLength = operators.length;
        // update each operator's weight
        for (uint256 i = 0; i < operatorsLength;) {
            _operatorWeightHistory[operators[i]].push(newWeights[i]);
            unchecked {
                ++i;
            }
        }

        // update total weight
        _totalWeightHistory.push(newTotalWeight);
    }

    function _handleUpdateQuorum(
        bytes memory data
    ) internal {
        (
            Quorum memory newQuorumConfig,
            address[] memory operators,
            uint256[] memory newWeights,
            uint256 newTotalWeight
        ) = abi.decode(data, (Quorum, address[], uint256[], uint256));

        // update quorum config using storage variable directly
        _updateQuorumConfig(newQuorumConfig);

        // update operators' weight
        for (uint256 i = 0; i < operators.length; i++) {
            _operatorWeightHistory[operators[i]].push(newWeights[i]);
        }

        // update total weight
        _totalWeightHistory.push(newTotalWeight);
    }

    function _handleUpdateMinWeight(
        bytes memory data
    ) internal {
        (
            uint256 newMinimumWeight,
            address[] memory operators,
            uint256[] memory newWeights,
            uint256 newTotalWeight
        ) = abi.decode(data, (uint256, address[], uint256[], uint256));

        // update minimum weight
        _minimumWeight = newMinimumWeight;

        // update operators' weight
        for (uint256 i = 0; i < operators.length; i++) {
            _operatorWeightHistory[operators[i]].push(newWeights[i]);
        }

        // update total weight
        _totalWeightHistory.push(newTotalWeight);
    }

    function _handleUpdateThreshold(
        bytes memory data
    ) internal {
        uint256 thresholdWeight = abi.decode(data, (uint256));

        // update threshold weight
        _thresholdWeightHistory.push(thresholdWeight);
    }

    function getThresholdWeightAtEpoch(
        uint32 _epoch
    ) external view returns (uint256) {
        return _thresholdWeightHistory.getAtEpoch(_epoch);
    }

    function _handleUpdateOperatorsForQuorum(
        bytes memory data
    ) internal {
        (address[] memory operators, uint256[] memory newWeights, uint256 newTotalWeight) =
            abi.decode(data, (address[], uint256[], uint256));

        uint256 operatorsLength = operators.length;
        for (uint256 i = 0; i < operatorsLength;) {
            _operatorWeightHistory[operators[i]].push(newWeights[i]);
            unchecked {
                ++i;
            }
        }

        _totalWeightHistory.push(newTotalWeight);

        emit OperatorsUpdated(operators, newWeights, newTotalWeight);
    }
}
