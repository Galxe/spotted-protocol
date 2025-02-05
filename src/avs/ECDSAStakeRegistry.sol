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
/// @author Spotted Team
/// @notice Manages operator registration and stake tracking for the Spotted AVS
/// @dev Modified from Eigenlayer's ECDSAStakeRegistry.

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
        _disableInitializers();
    }

    /// @notice Initializes the contract with the given parameters.
    /// @param _thresholdWeight The threshold weight in basis points.
    /// @param quorumParams The quorum struct containing the details of the quorum thresholds.
    function initialize(
        uint256 _thresholdWeight,
        Quorum memory quorumParams
    ) external initializer {
        __ECDSAStakeRegistry_init(_thresholdWeight, quorumParams);
    }

    /// @notice Registers a new operator using a provided signature and signing key
    /// @param _operatorSignature Contains the operator's signature, salt, and expiry
    /// @param _signingKey The signing key to add to the operator's history
    function registerOperatorWithSignature(
        ISignatureUtils.SignatureWithSaltAndExpiry memory _operatorSignature,
        address _signingKey,
        address _p2pKey
    ) external {
        _registerOperatorWithSig(msg.sender, _operatorSignature, _signingKey, _p2pKey);

        // all the needed updated states to sync to other chains
        address newSigningKey = _signingKey;
        uint256 newWeight = _operatorWeightHistory[msg.sender].latest();
        uint256 newTotalWeight = _totalWeightHistory.latest();

        bytes memory data = abi.encode(msg.sender, newSigningKey, newWeight, newTotalWeight);

        EPOCH_MANAGER.queueStateUpdate(IEpochManager.MessageType.REGISTER, data);
    }

    /// @notice Deregisters an existing operator
    /// @dev Only callable by the operator themselves
    function deregisterOperator() external {
        _deregisterOperator(msg.sender);

        // all the needed updated states to sync to other chains
        uint256 newWeight = _operatorWeightHistory[msg.sender].latest();
        uint256 newTotalWeight = _totalWeightHistory.latest();

        bytes memory data = abi.encode(msg.sender, newWeight, newTotalWeight);

        EPOCH_MANAGER.queueStateUpdate(IEpochManager.MessageType.DEREGISTER, data);
    }

    /// @notice Updates the signing key for an operator
    /// @dev Only callable by the operator themselves
    /// @param _newSigningKey The new signing key to set for the operator
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

    /// @notice Updates the P2P key for an operator
    /// @dev Only callable by the operator themselves
    /// @param _newP2PKey The new P2P key to set for the operator
    function updateOperatorP2PKey(
        address _newP2PKey
    ) external {
        if (!_operatorRegistered[msg.sender]) {
            revert OperatorNotRegistered();
        }
        _updateOperatorP2PKey(msg.sender, _newP2PKey);

        bytes memory data = abi.encode(msg.sender, _newP2PKey);
        EPOCH_MANAGER.queueStateUpdate(IEpochManager.MessageType.UPDATE_P2P_KEY, data);
    }

    /// @notice Updates the StakeRegistry's view of one or more operators' stakes adding a new entry in their history of stake checkpoints,
    /// @dev Queries stakes from the Eigenlayer core DelegationManager contract
    /// @param _operators A list of operator addresses to update
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

    /// @notice Updates the quorum configuration and the set of operators
    /// @dev Only callable by the contract owner.
    /// It first updates the quorum configuration and then updates the list of operators.
    /// @param newQuorumConfig The new quorum configuration, including strategies and their new weights
    /// @param _operators The list of operator addresses to update stakes for
    function updateQuorumConfig(
        Quorum memory newQuorumConfig,
        address[] memory _operators
    ) external onlyOwner {
        _updateQuorumConfig(newQuorumConfig);
        _updateOperators(_operators);

        // get updated operators' state
        uint256[] memory newWeights = new uint256[](_operators.length);
        for (uint256 i = 0; i < _operators.length; i++) {
            newWeights[i] = _operatorWeightHistory[_operators[i]].latest();
        }
        uint256 newTotalWeight = _totalWeightHistory.latest();

        bytes memory data = abi.encode(
            newQuorumConfig, // new quorum config
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

    /// @notice Sets a new cumulative threshold weight for message validation by operator set signatures.
    /// @dev This function can only be invoked by the owner of the contract. It delegates the update to
    /// an internal function `_updateStakeThreshold`.
    /// @param _thresholdWeight The updated threshold weight required to validate a message. This is the
    /// cumulative weight that must be met or exceeded by the sum of the stakes of the signatories for
    /// a message to be deemed valid.
    function updateStakeThreshold(
        uint256 _thresholdWeight
    ) external onlyOwner {
        _updateStakeThreshold(_thresholdWeight);

        bytes memory data = abi.encode(_thresholdWeight);

        EPOCH_MANAGER.queueStateUpdate(IEpochManager.MessageType.UPDATE_THRESHOLD, data);
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

        bytes memory data = abi.encode(
            operators, // operators need to be updated
            newWeights, // new weights for each operator
            newTotalWeight // new total weight
        );

        EPOCH_MANAGER.queueStateUpdate(IEpochManager.MessageType.UPDATE_OPERATORS_FOR_QUORUM, data);
    }

    /// @notice Validates a signature against ERC1271 interface
    /// @dev Implements IERC1271Upgradeable interface for signature validation
    /// @param _signatureData Encoded data containing operators, signatures and reference epoch
    /// @param _dataHash Hash of the data that was signed
    /// @return bytes4 Magic value indicating if the signature is valid
    function isValidSignature(
        bytes32 _dataHash,
        bytes memory _signatureData
    ) external view returns (bytes4) {
        (address[] memory operators, bytes[] memory signatures, uint32 referenceEpoch) =
            abi.decode(_signatureData, (address[], bytes[], uint32));
        if (referenceEpoch > EPOCH_MANAGER.getCurrentEpoch()) {
            revert InvalidEpoch();
        }
        _checkSignatures(_dataHash, operators, signatures, referenceEpoch);
        return IERC1271Upgradeable.isValidSignature.selector;
    }

    /// @notice Gets the current quorum configuration
    /// @return Quorum Current quorum parameters including strategies and thresholds
    function quorum() external view returns (Quorum memory) {
        return _quorum;
    }

    /// @notice Gets the latest signing key for an operator
    /// @param _operator Address of the operator to query
    /// @return Latest signing key associated with the operator
    function getLastestOperatorSigningKey(
        address _operator
    ) external view returns (address) {
        return address(uint160(_operatorSigningKeyHistory[_operator].latest()));
    }

    /// @notice Gets the latest signing key for an operator
    /// @param _operator Address of the operator to query
    /// @return Latest signing key associated with the operator
    function getLastestOperatorP2PKey(
        address _operator
    ) external view returns (address) {
        return address(uint160(_operatorP2PKeyHistory[_operator].latest()));
    }


    /// @notice Gets an operator's signing key at a specific epoch
    /// @param _operator Address of the operator to query
    /// @param _epochNumber Epoch number to query the signing key for
    /// @return Signing key that was active at the specified epoch
    function getOperatorSigningKeyAtEpoch(
        address _operator,
        uint32 _epochNumber
    ) external view returns (address) {
        return address(uint160(_operatorSigningKeyHistory[_operator].getAtEpoch(_epochNumber)));
    }

    /// @notice Gets the latest recorded weight for an operator
    /// @param _operator Address of the operator to query
    /// @return Latest weight checkpoint for the operator
    function getLastCheckpointOperatorWeight(
        address _operator
    ) external view returns (uint256) {
        return _operatorWeightHistory[_operator].latest();
    }

    /// @notice Gets the latest total weight across all operators
    /// @return Latest total weight checkpoint
    function getLastCheckpointTotalWeight() external view returns (uint256) {
        return _totalWeightHistory.latest();
    }

    /// @notice Gets the latest threshold weight
    /// @return Latest threshold weight checkpoint
    function getLastCheckpointThresholdWeight() external view returns (uint256) {
        return _thresholdWeightHistory.latest();
    }

    /// @notice Gets an operator's weight at a specific epoch
    /// @param _operator Address of the operator to query
    /// @param _epochNumber Epoch number to query the weight for
    /// @return Weight that was active at the specified epoch
    function getOperatorWeightAtEpoch(
        address _operator,
        uint32 _epochNumber
    ) external view returns (uint256) {
        return _operatorWeightHistory[_operator].getAtEpoch(_epochNumber);
    }

    /// @notice Gets the total weight at a specific epoch
    /// @param _epochNumber Epoch number to query
    /// @return Total weight that was active at the specified epoch
    function getTotalWeightAtEpoch(
        uint32 _epochNumber
    ) external view returns (uint256) {
        return _totalWeightHistory.getAtEpoch(_epochNumber);
    }

    /// @notice Gets the threshold weight at a specific epoch
    /// @param _epochNumber Epoch number to query
    /// @return Threshold weight that was active at the specified epoch
    function getThresholdWeightAtEpoch(
        uint32 _epochNumber
    ) external view returns (uint256) {
        return _thresholdWeightHistory.getAtEpoch(_epochNumber);
    }

    /// @notice Checks if an operator is currently registered
    /// @param _operator Address of the operator to check
    /// @return True if operator is registered, false otherwise
    function operatorRegistered(
        address _operator
    ) external view returns (bool) {
        return _operatorRegistered[_operator];
    }

    /// @notice Gets the minimum weight requirement for operators
    /// @return Current minimum weight threshold
    function minimumWeight() external view returns (uint256) {
        return _minimumWeight;
    }

    /// @notice Calculates an operator's current weight based on their delegated stake
    /// @param _operator Address of the operator to calculate weight for
    /// @return Current weight of the operator (0 if below minimum threshold)
    /// @dev Queries mainnet delegation manager for current shares
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

    /// @notice External function to retrieve the threshold stake for a given reference epoch.
    /// @param _referenceEpoch The epoch number to query the threshold stake for.
    /// If set to the maximum uint32 value, it retrieves the latest threshold stake.
    /// @return The threshold stake in basis points for the reference epoch.
    function getThresholdStake(
        uint32 _referenceEpoch
    ) external view returns (uint256) {
        return _thresholdWeightHistory.getAtEpoch(_referenceEpoch);
    }

    /// @notice Initializes state for the StakeRegistry
    /// @param _thresholdWeight The threshold weight for the stake registry
    /// @param quorumParams The quorum configuration for the stake registry
    function __ECDSAStakeRegistry_init(
        uint256 _thresholdWeight,
        Quorum memory quorumParams
    ) internal onlyInitializing {
        _updateStakeThreshold(_thresholdWeight);
        _updateQuorumConfig(quorumParams);
        __Ownable_init();
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
        emit OperatorDeregistered(_operator, block.number, address(SERVICE_MANAGER));
    }

    /// @dev registers an operator through a provided signature
    /// @param _operatorSignature Contains the operator's signature, salt, and expiry
    /// @param _signingKey The signing key to add to the operator's history
    function _registerOperatorWithSig(
        address _operator,
        ISignatureUtils.SignatureWithSaltAndExpiry memory _operatorSignature,
        address _signingKey,
        address _p2pKey
    ) internal virtual {
        if (_operatorRegistered[_operator]) {
            revert OperatorAlreadyRegistered();
        }
        _totalOperators++;
        _operatorRegistered[_operator] = true;
        int256 delta = _updateOperatorWeight(_operator);
        _updateTotalWeight(delta);
        _updateOperatorSigningKey(_operator, _signingKey);
        _updateOperatorP2PKey(_operator, _p2pKey);
        SERVICE_MANAGER.registerOperatorToAVS(_operator, _operatorSignature);
        emit OperatorRegistered(
            _operator, block.number, _signingKey, block.timestamp, address(SERVICE_MANAGER)
        );
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

    /// @dev Internal function to update an operator's P2P key
    /// @param _operator The address of the operator to update the P2P key for
    /// @param _newP2PKey The new P2P key to set for the operator
    function _updateOperatorP2PKey(address _operator, address _newP2PKey) internal {
        address oldP2PKey = address(uint160(_operatorP2PKeyHistory[_operator].latest()));
        if (_newP2PKey == oldP2PKey) {
            return;
        }
        _operatorP2PKeyHistory[_operator].push(uint160(_newP2PKey));
        emit P2PKeyUpdate(_operator, _newP2PKey, oldP2PKey);
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

    /// @dev Verifies that a specified quorum configuration is valid. A valid quorum has:
    ///      1. Weights that sum to exactly 10,000 basis points, ensuring proportional representation.
    ///      2. Unique strategies without duplicates to maintain quorum integrity.
    /// @param quorumToValidate The quorum configuration to be validated.
    /// @return bool True if the quorum configuration is valid, otherwise false.
    function _isValidQuorum(
        Quorum memory quorumToValidate
    ) internal pure returns (bool) {
        StrategyParams[] memory strategies = quorumToValidate.strategies;
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

    /// @notice Common logic to verify a batch of ECDSA signatures against a hash, using either last stake weight or at a specific epoch.
    /// @param _dataHash The hash of the data the signers endorsed.
    /// @param _operators A collection of addresses that endorsed the data hash.
    /// @param _signatures A collection of signatures matching the signers.
    /// @param _referenceEpoch The epoch number for evaluating stake weight; use max uint32 for latest weight.
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

    /// @notice Retrieves the operator signing key for a signer, either at the last checkpoint or a specified epoch.
    /// @param _operator The operator to query their signing key history for
    /// @param _referenceEpoch The epoch number to query the operator's weight at, or the maximum uint32 value for the last checkpoint.
    /// @return The weight of the operator.
    function _getOperatorSigningKey(
        address _operator,
        uint32 _referenceEpoch
    ) internal view returns (address) {
        return address(uint160(_operatorSigningKeyHistory[_operator].getAtEpoch(_referenceEpoch)));
    }

    /// @notice Retrieves the operator weight for a signer, either at the last checkpoint or a specified epoch.
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
    /// @dev If the `_referenceEpoch` is the maximum value for uint32, the latest total weight is returned.
    /// @param _referenceEpoch The epoch number to retrieve the total stake weight from.
    /// @return The total stake weight at the given epoch or the latest if the given epoch is the max uint32 value.
    function _getTotalWeight(
        uint32 _referenceEpoch
    ) internal view returns (uint256) {
        return _totalWeightHistory.getAtEpoch(_referenceEpoch);
    }

    /// @notice Retrieves the threshold stake for a given reference epoch.
    /// @param _referenceEpoch The epoch number to query the threshold stake for.
    /// If set to the maximum uint32 value, it retrieves the latest threshold stake.
    /// @return The threshold stake in basis points for the reference epoch.
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
}
