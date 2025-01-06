// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ECDSAStakeRegistryStorage, Quorum, StrategyParams} from "./ECDSAStakeRegistryStorage.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {IDelegationManager} from
    "eigenlayer-contracts/src/contracts/interfaces/IDelegationManager.sol";
import {ISignatureUtils} from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import {IServiceManager} from "../interfaces/IServiceManager.sol";

import {OwnableUpgradeable} from "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import {CheckpointsUpgradeable} from
    "@openzeppelin-upgrades/contracts/utils/CheckpointsUpgradeable.sol";
import {SignatureCheckerUpgradeable} from
    "@openzeppelin-upgrades/contracts/utils/cryptography/SignatureCheckerUpgradeable.sol";
import {IERC1271Upgradeable} from
    "@openzeppelin-upgrades/contracts/interfaces/IERC1271Upgradeable.sol";
import {EpochCheckpointsUpgradeable} from "../libraries/EpochCheckpointsUpgradeable.sol";
import {IEpochManager} from "../interfaces/IEpochManager.sol";

/// @title ECDSA Stake Registry
/// @dev THIS CONTRACT IS NOT AUDITED
/// @notice Manages operator registration and quorum updates for an AVS using ECDSA signatures.
contract ECDSAStakeRegistry is
    IERC1271Upgradeable,
    OwnableUpgradeable,
    ECDSAStakeRegistryStorage
{
    using SignatureCheckerUpgradeable for address;
    using EpochCheckpointsUpgradeable for EpochCheckpointsUpgradeable.History;

    /// @dev Constructor to create ECDSAStakeRegistry.
    /// @param _delegationManager Address of the DelegationManager contract that this registry interacts with.
    constructor(
        address _delegationManager,
        address _epochManager,
        address _serviceManager
    ) ECDSAStakeRegistryStorage(_delegationManager, _epochManager, _serviceManager) {
        // _disableInitializers();
    }

    /// @notice Initializes the contract with the given parameters.
    /// @param _thresholdWeight The threshold weight in basis points.
    /// @param _quorum The quorum struct containing the details of the quorum thresholds.
    function initialize(uint256 _thresholdWeight, Quorum memory _quorum) external initializer {
        __ECDSAStakeRegistry_init(_thresholdWeight, _quorum);
    }

    /// @notice Registers a new operator using a provided signature and signing key
    /// @param _operatorSignature Contains the operator's signature, salt, and expiry
    /// @param _signingKey The signing key to add to the operator's history
    function registerOperatorWithSignature(
        ISignatureUtils.SignatureWithSaltAndExpiry memory _operatorSignature,
        address _signingKey
    ) external {
        _registerOperatorWithSig(msg.sender, _operatorSignature, _signingKey);
        SERVICE_MANAGER.registerOperatorToAVS(msg.sender, _operatorSignature);

        // all the updates to send to other chains
        address newSigningKey = _signingKey;
        uint256 newWeight = _operatorWeightHistory[msg.sender].latest();
        uint256 newTotalWeight = _totalWeightHistory.latest();

        bytes memory data = abi.encode(msg.sender, newSigningKey, newWeight, newTotalWeight);

        EPOCH_MANAGER.queueStateUpdate(IEpochManager.MessageType.REGISTER, data);
    }

    /// @notice Deregisters an existing operator
    function deregisterOperator() external {
        _deregisterOperator(msg.sender);
        SERVICE_MANAGER.deregisterOperatorFromAVS(msg.sender);

        // all the updates to send to other chains
        uint256 newWeight = _operatorWeightHistory[msg.sender].latest();
        uint256 newTotalWeight = _totalWeightHistory.latest();

        bytes memory data = abi.encode(msg.sender, newWeight, newTotalWeight);

        EPOCH_MANAGER.queueStateUpdate(IEpochManager.MessageType.DEREGISTER, data);
    }

    /**
     * @notice Updates the signing key for an operator
     * @dev Only callable by the operator themselves
     * @param _newSigningKey The new signing key to set for the operator
     */
    function updateOperatorSigningKey(
        address _newSigningKey
    ) external {
        if (!_operatorRegistered[msg.sender]) {
            revert OperatorNotRegistered();
        }
        _updateOperatorSigningKey(msg.sender, _newSigningKey);

        bytes memory data = abi.encode(msg.sender, _newSigningKey);
        EPOCH_MANAGER.queueStateUpdate(IEpochManager.MessageType.UPDATE_SIGNING_KEY, data);
    }

    /**
     * @notice Updates the StakeRegistry's view of one or more operators' stakes adding a new entry in their history of stake checkpoints,
     * @dev Queries stakes from the Eigenlayer core DelegationManager contract
     * @param _operators A list of operator addresses to update
     */
    function updateOperators(
        address[] memory _operators
    ) external {
        _updateOperators(_operators);

        // get updated operators' state
        uint256 operatorsLength = _operators.length;
        uint256[] memory newWeights = new uint256[](operatorsLength);
        for (uint256 i = 0; i < operatorsLength;) {
            newWeights[i] = _operatorWeightHistory[_operators[i]].latest();
            unchecked {
                ++i;
            }
        }
        uint256 newTotalWeight = _totalWeightHistory.latest();

        // pack all state updates to be synced
        bytes memory data = abi.encode(
            _operators, // operators need to be updated
            newWeights, // new weights for each operator
            newTotalWeight // new total weight
        );

        EPOCH_MANAGER.queueStateUpdate(IEpochManager.MessageType.UPDATE_OPERATORS, data);
    }

    /**
     * @notice Updates the quorum configuration and the set of operators
     * @dev Only callable by the contract owner.
     * It first updates the quorum configuration and then updates the list of operators.
     * @param _quorum The new quorum configuration, including strategies and their new weights
     * @param _operators The list of operator addresses to update stakes for
     */
    function updateQuorumConfig(
        Quorum memory _quorum,
        address[] memory _operators
    ) external onlyOwner {
        _updateQuorumConfig(_quorum);
        _updateOperators(_operators);

        // get updated operators' state
        uint256[] memory newWeights = new uint256[](_operators.length);
        for (uint256 i = 0; i < _operators.length; i++) {
            newWeights[i] = _operatorWeightHistory[_operators[i]].latest();
        }
        uint256 newTotalWeight = _totalWeightHistory.latest();

        bytes memory data = abi.encode(
            _quorum, // new quorum config
            _operators, // operators need to be updated
            newWeights, // new weights for each operator
            newTotalWeight // new total weight
        );

        EPOCH_MANAGER.queueStateUpdate(IEpochManager.MessageType.UPDATE_QUORUM, data);
    }

    /// @notice Updates the weight an operator must have to join the operator set
    /// @dev Access controlled to the contract owner
    /// @param _newMinimumWeight The new weight an operator must have to join the operator set
    function updateMinimumWeight(
        uint256 _newMinimumWeight,
        address[] memory _operators
    ) external onlyOwner {
        _updateMinimumWeight(_newMinimumWeight);
        _updateOperators(_operators);

        // get updated operators' state
        uint256[] memory newWeights = new uint256[](_operators.length);
        for (uint256 i = 0; i < _operators.length; i++) {
            newWeights[i] = _operatorWeightHistory[_operators[i]].latest();
        }
        uint256 newTotalWeight = _totalWeightHistory.latest();

        bytes memory data = abi.encode(
            _newMinimumWeight, // new minimum weight
            _operators, // operators need to be updated
            newWeights, // new weights for each operator
            newTotalWeight // new total weight
        );

        EPOCH_MANAGER.queueStateUpdate(IEpochManager.MessageType.UPDATE_MIN_WEIGHT, data);
    }

    /**
     * @notice Sets a new cumulative threshold weight for message validation by operator set signatures.
     * @dev This function can only be invoked by the owner of the contract. It delegates the update to
     * an internal function `_updateStakeThreshold`.
     * @param _thresholdWeight The updated threshold weight required to validate a message. This is the
     * cumulative weight that must be met or exceeded by the sum of the stakes of the signatories for
     * a message to be deemed valid.
     */
    function updateStakeThreshold(
        uint256 _thresholdWeight
    ) external onlyOwner {
        _updateStakeThreshold(_thresholdWeight);

        bytes memory data = abi.encode(_thresholdWeight);

        EPOCH_MANAGER.queueStateUpdate(IEpochManager.MessageType.UPDATE_THRESHOLD, data);
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

    /// @notice Calculates the current weight of an operator based on their delegated stake in the strategies considered in the quorum
    /// @param _operator The address of the operator.
    /// @return uint256 - The current weight of the operator; returns 0 if below the threshold.
    /// @dev 需要query mainnet的delegation manager
    function getOperatorWeight(
        address _operator
    ) public view returns (uint256) {
        StrategyParams[] memory strategyParams = _quorum.strategies;
        uint256 weight;
        IStrategy[] memory strategies = new IStrategy[](strategyParams.length);
        for (uint256 i; i < strategyParams.length; i++) {
            strategies[i] = strategyParams[i].strategy;
        }
        uint256[] memory shares = DELEGATION_MANAGER.getOperatorShares(_operator, strategies);
        for (uint256 i; i < strategyParams.length; i++) {
            weight += shares[i] * strategyParams[i].multiplier;
        }
        weight = weight / BPS;

        if (weight >= _minimumWeight) {
            return weight;
        } else {
            return 0;
        }
    }

    /// @notice Initializes state for the StakeRegistry
    /// @param _thresholdWeight The threshold weight for the stake registry
    /// @param _quorum The quorum configuration for the stake registry
    function __ECDSAStakeRegistry_init(
        uint256 _thresholdWeight,
        Quorum memory _quorum
    ) internal onlyInitializing {
        _updateStakeThreshold(_thresholdWeight);
        _updateQuorumConfig(_quorum);
        __Ownable_init();
    }

    /// @notice Updates the set of operators for the first quorum.
    /// @param operatorsPerQuorum An array of operator address arrays, one for each quorum.
    /// @dev This interface maintains compatibility with avs-sync which handles multiquorums while this registry has a single quorum
    function updateOperatorsForQuorum(
        address[][] memory operatorsPerQuorum,
        bytes memory
    ) external {
        address[] memory operators = operatorsPerQuorum[0];
        uint256 operatorsLength = operators.length;
        _updateAllOperators(operators);

        uint256[] memory newWeights = new uint256[](operatorsLength);
        for (uint256 i = 0; i < operatorsLength;) {
            newWeights[i] = _operatorWeightHistory[operators[i]].latest();
            unchecked {
                ++i;
            }
        }
        uint256 newTotalWeight = _totalWeightHistory.latest();

        // 打包所有需要同步的状态
        bytes memory data = abi.encode(
            operators, // operators need to be updated
            newWeights, // new weights for each operator
            newTotalWeight // new total weight
        );

        EPOCH_MANAGER.queueStateUpdate(IEpochManager.MessageType.UPDATE_OPERATORS_FOR_QUORUM, data);
    }

    /// @dev Updates the list of operators if the provided list has the correct number of operators.
    /// Reverts if the provided list of operators does not match the expected total count of operators.
    /// @param _operators The list of operator addresses to update.
    function _updateAllOperators(
        address[] memory _operators
    ) internal {
        if (_operators.length != _totalOperators) {
            revert MustUpdateAllOperators();
        }
        _updateOperators(_operators);
    }

    /// @dev Updates the weights for a given list of operator addresses.
    /// When passing an operator that isn't registered, then 0 is added to their history
    /// @param _operators An array of addresses for which to update the weights.
    function _updateOperators(
        address[] memory _operators
    ) internal {
        int256 delta;
        for (uint256 i; i < _operators.length; i++) {
            delta += _updateOperatorWeight(_operators[i]);
        }
        _updateTotalWeight(delta);
    }

    /// @dev Updates the stake threshold weight and records the history.
    /// @param _thresholdWeight The new threshold weight to set and record in the history.
    function _updateStakeThreshold(
        uint256 _thresholdWeight
    ) internal {
        _thresholdWeightHistory.push(_thresholdWeight);
        emit ThresholdWeightUpdated(_thresholdWeight);
    }

    /// @dev Updates the weight an operator must have to join the operator set
    /// @param _newMinimumWeight The new weight an operator must have to join the operator set
    function _updateMinimumWeight(
        uint256 _newMinimumWeight
    ) internal {
        uint256 oldMinimumWeight = _minimumWeight;
        _minimumWeight = _newMinimumWeight;
        emit MinimumWeightUpdated(oldMinimumWeight, _newMinimumWeight);
    }

    /// @notice Updates the quorum configuration
    /// @dev Replaces the current quorum configuration with `_newQuorum` if valid.
    /// Reverts with `InvalidQuorum` if the new quorum configuration is not valid.
    /// Emits `QuorumUpdated` event with the old and new quorum configurations.
    /// @param _newQuorum The new quorum configuration to set.
    function _updateQuorumConfig(
        Quorum memory _newQuorum
    ) internal {
        if (!_isValidQuorum(_newQuorum)) {
            revert InvalidQuorum();
        }
        Quorum memory oldQuorum = _quorum;
        delete _quorum;
        for (uint256 i; i < _newQuorum.strategies.length; i++) {
            _quorum.strategies.push(_newQuorum.strategies[i]);
        }
        emit QuorumUpdated(oldQuorum, _newQuorum);
    }

    /// @dev Internal function to deregister an operator
    /// @param _operator The operator's address to deregister
    function _deregisterOperator(
        address _operator
    ) internal {
        if (!_operatorRegistered[_operator]) {
            revert OperatorNotRegistered();
        }
        _totalOperators--;
        delete _operatorRegistered[_operator];
        int256 delta = _updateOperatorWeight(_operator);
        _updateTotalWeight(delta);
        SERVICE_MANAGER.deregisterOperatorFromAVS(_operator);
        emit OperatorDeregistered(_operator, address(SERVICE_MANAGER));
    }

    /// @dev registers an operator through a provided signature
    /// @param _operatorSignature Contains the operator's signature, salt, and expiry
    /// @param _signingKey The signing key to add to the operator's history
    function _registerOperatorWithSig(
        address _operator,
        ISignatureUtils.SignatureWithSaltAndExpiry memory _operatorSignature,
        address _signingKey
    ) internal virtual {
        if (_operatorRegistered[_operator]) {
            revert OperatorAlreadyRegistered();
        }
        _totalOperators++;
        _operatorRegistered[_operator] = true;
        int256 delta = _updateOperatorWeight(_operator);
        _updateTotalWeight(delta);
        _updateOperatorSigningKey(_operator, _signingKey);
        SERVICE_MANAGER.registerOperatorToAVS(_operator, _operatorSignature);
        emit OperatorRegistered(_operator, address(SERVICE_MANAGER));
    }

    /// @dev Internal function to update an operator's signing key
    /// @param _operator The address of the operator to update the signing key for
    /// @param _newSigningKey The new signing key to set for the operator
    function _updateOperatorSigningKey(address _operator, address _newSigningKey) internal {
        address oldSigningKey = address(uint160(_operatorSigningKeyHistory[_operator].latest()));
        if (_newSigningKey == oldSigningKey) {
            return;
        }
        _operatorSigningKeyHistory[_operator].push(uint160(_newSigningKey));
        emit SigningKeyUpdate(_operator, _newSigningKey, oldSigningKey);
    }

    /// @notice Updates the weight of an operator and returns the previous and current weights.
    /// @param _operator The address of the operator to update the weight of.
    function _updateOperatorWeight(
        address _operator
    ) internal virtual returns (int256) {
        int256 delta;
        uint256 newWeight;
        uint256 oldWeight = _operatorWeightHistory[_operator].latest();
        if (!_operatorRegistered[_operator]) {
            delta -= int256(oldWeight);
            if (delta == 0) {
                return delta;
            }
            _operatorWeightHistory[_operator].push(0);
        } else {
            newWeight = getOperatorWeight(_operator);
            delta = int256(newWeight) - int256(oldWeight);
            if (delta == 0) {
                return delta;
            }
            _operatorWeightHistory[_operator].push(newWeight);
        }
        emit OperatorWeightUpdated(_operator, oldWeight, newWeight);
        return delta;
    }

    /// @dev Internal function to update the total weight of the stake
    /// @param delta The change in stake applied last total weight
    /// @return oldTotalWeight The weight before the update
    /// @return newTotalWeight The updated weight after applying the delta
    function _updateTotalWeight(
        int256 delta
    ) internal returns (uint256 oldTotalWeight, uint256 newTotalWeight) {
        oldTotalWeight = _totalWeightHistory.latest();
        int256 newWeight = int256(oldTotalWeight) + delta;
        newTotalWeight = uint256(newWeight);
        _totalWeightHistory.push(newTotalWeight);
        emit TotalWeightUpdated(oldTotalWeight, newTotalWeight);
    }

    /**
     * @dev Verifies that a specified quorum configuration is valid. A valid quorum has:
     *      1. Weights that sum to exactly 10,000 basis points, ensuring proportional representation.
     *      2. Unique strategies without duplicates to maintain quorum integrity.
     * @param _quorum The quorum configuration to be validated.
     * @return bool True if the quorum configuration is valid, otherwise false.
     */
    function _isValidQuorum(
        Quorum memory _quorum
    ) internal pure returns (bool) {
        StrategyParams[] memory strategies = _quorum.strategies;
        address lastStrategy;
        address currentStrategy;
        uint256 totalMultiplier;
        for (uint256 i; i < strategies.length; i++) {
            currentStrategy = address(strategies[i].strategy);
            if (lastStrategy >= currentStrategy) revert NotSorted();
            lastStrategy = currentStrategy;
            totalMultiplier += strategies[i].multiplier;
        }
        if (totalMultiplier != BPS) {
            return false;
        } else {
            return true;
        }
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

    /// @notice Retrieve the total stake weight at a specific block or the latest if not specified.
    /// @dev If the `_referenceEpoch` is the maximum value for uint32, the latest total weight is returned.
    /// @param _referenceEpoch The epoch number to retrieve the total stake weight from.
    /// @return The total stake weight at the given block or the latest if the given block is the max uint32 value.
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
        if (_referenceEpoch >= block.number) {
            revert InvalidReferenceEpoch();
        }
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
}
