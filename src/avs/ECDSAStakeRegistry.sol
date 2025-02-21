// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {
    ECDSAStakeRegistryStorage, IECDSAStakeRegistryTypes
} from "./ECDSAStakeRegistryStorage.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {IDelegationManager} from
    "eigenlayer-contracts/src/contracts/interfaces/IDelegationManager.sol";
import {ISignatureUtils} from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import {IServiceManager} from "../interfaces/ISpottedServiceManager.sol";
import {OwnableUpgradeable} from "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import {CheckpointsUpgradeable} from
    "@openzeppelin-upgrades/contracts/utils/CheckpointsUpgradeable.sol";
import {SignatureCheckerUpgradeable} from
    "@openzeppelin-upgrades/contracts/utils/cryptography/SignatureCheckerUpgradeable.sol";
import {IERC1271Upgradeable} from
    "@openzeppelin-upgrades/contracts/interfaces/IERC1271Upgradeable.sol";
import {IEpochManager} from "../interfaces/IEpochManager.sol";
import {IAllocationManager} from
    "eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";
import {
    OperatorSetLib,
    OperatorSet
} from "eigenlayer-contracts/src/contracts/libraries/OperatorSetLib.sol";
import {IAVSDirectoryTypes} from "eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";

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
    using OperatorSetLib for OperatorSet;

    /// @dev Constructor to create ECDSAStakeRegistry.
    /// @param _delegationManager Address of the DelegationManager contract that this registry interacts with.
    constructor(
        address _delegationManager,
        address _epochManager,
        address _allocationManager,
        address _avsRegistrar,
        address _avsDirectory
    )
        ECDSAStakeRegistryStorage(
            _delegationManager,
            _epochManager,
            _allocationManager,
            _avsRegistrar,
            _avsDirectory
        )
    {
        _disableInitializers();
    }

    modifier onlyAVSRegistrar() {
        if (msg.sender != address(avsRegistrar)) {
            revert ECDSAStakeRegistry__InvalidSender();
        }
        _;
    }
    /// @notice Initializes the contract with the given parameters.
    /// @param _thresholdWeight The threshold weight in basis points.
    /// @param quorumParams The quorum struct containing the details of the quorum thresholds.

    function initialize(
        address _serviceManager,
        uint256 _thresholdWeight,
        Quorum memory quorumParams
    ) external initializer {
        __ECDSAStakeRegistry_init(_serviceManager, _thresholdWeight, quorumParams);
    }

    function disableM2QuorumRegistration() external onlyOwner {
        if (isM2QuorumRegistrationDisabled) {
            revert ECDSAStakeRegistry__M2QuorumRegistrationIsDisabled();
        }

        isM2QuorumRegistrationDisabled = true;
        emit M2QuorumRegistrationDisabled();
    }

    /// @notice Registers a new operator using a provided signature and signing key
    /// @param _operatorSignature Contains the operator's signature, salt, and expiry
    /// @param _signingKey The signing key to add to the operator's history
    function registerOperatorOnAVSDirectory(
        ISignatureUtils.SignatureWithSaltAndExpiry memory _operatorSignature,
        address _signingKey,
        address _p2pKey
    ) external {
        if (isM2QuorumRegistrationDisabled) {
            revert ECDSAStakeRegistry__M2QuorumRegistrationIsDisabled();
        }
        if (operatorRegisteredOnAVSDirectory(msg.sender)) {
            revert ECDSAStakeRegistry__OperatorAlreadyRegistered();
        }
        _registerOperatorWithSig(msg.sender, _operatorSignature, _signingKey, _p2pKey);

        // emit event if operator is not registered on current operator set (first time registration)
        if (!operatorRegisteredOnCurrentOperatorSet(msg.sender)) {
            emit OperatorRegistered(
                msg.sender, block.number, _p2pKey, _signingKey, address(_serviceManager)
            );
        }
    }

    /// @notice Deregisters an existing operator
    /// @dev Only callable by the operator themselves
    function deregisterOperatorOnAVSDirectory() external {
        if (!operatorRegisteredOnAVSDirectory(msg.sender)) {
            revert ECDSAStakeRegistry__OperatorNotRegistered();
        }

        _deregisterOperator(msg.sender);

        if (!operatorRegisteredOnCurrentOperatorSet(msg.sender)) {
            emit OperatorDeregistered(msg.sender, block.number, address(_serviceManager));
        }
    }

    function onOperatorSetRegistered(
        address operator,
        address signingKey,
        address p2pKey
    ) external onlyAVSRegistrar {
        // Update operator weight
        _updateOperatorWeight(operator);

        // Update signing key and p2p key
        _updateOperatorSigningKey(operator, signingKey);
        _updateOperatorP2pKey(operator, p2pKey);

        if (!operatorRegisteredOnAVSDirectory(operator)) {  
            emit OperatorRegistered(
                operator, block.number, p2pKey, signingKey, address(_serviceManager)
            );
        }
    }

    function onOperatorSetDeregistered(
        address operator
    ) external onlyAVSRegistrar {
        // Update weights
        _updateOperatorWeight(operator);

        // Emit event
        if (!operatorRegisteredOnAVSDirectory(operator)) {
            emit OperatorDeregistered(operator, block.number, address(_serviceManager));
        }
    }

    /// @notice Updates the signing key for an operator
    /// @dev Only callable by the operator themselves
    /// @param _newSigningKey The new signing key to set for the operator
    function updateOperatorSigningKey(
        address _newSigningKey
    ) external {
        if (!operatorRegistered(msg.sender)) {
            revert ECDSAStakeRegistry__OperatorNotRegistered();
        }
        _updateOperatorSigningKey(msg.sender, _newSigningKey);
    }

    /// @notice Updates the P2p key for an operator
    /// @dev Only callable by the operator themselves
    /// @param _newP2pKey The new P2p key to set for the operator
    function updateOperatorP2pKey(
        address _newP2pKey
    ) external {
        if (!operatorRegistered(msg.sender)) {
            revert ECDSAStakeRegistry__OperatorNotRegistered();
        }
        _updateOperatorP2pKey(msg.sender, _newP2pKey);
    }

    /// @notice Updates the StakeRegistry's view of one or more operators' stakes adding a new entry in their history of stake checkpoints,
    /// @dev Queries stakes from the Eigenlayer core DelegationManager contract
    /// @param _operators A list of operator addresses to update
    function updateOperators(
        address[] memory _operators
    ) external {
        _updateOperators(_operators);
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
    }

    function setCurrentOperatorSetId(
        uint32 _id
    ) external onlyOwner {
        currentOperatorSetId = _id;
    }

    function setAllocationManager(
        address _allocationManager
    ) external onlyOwner {
        allocationManager = IAllocationManager(_allocationManager);
    }
    function setAVSRegistrar(
        address _avsRegistrar
    ) external onlyOwner {
        avsRegistrar = _avsRegistrar;
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
            revert ECDSAStakeRegistry__InvalidEpoch();
        }
        _checkSignatures(_dataHash, operators, signatures, referenceEpoch);
        return IERC1271Upgradeable.isValidSignature.selector;
    }

    /// @notice Gets the current quorum configuration
    /// @return Quorum Current quorum parameters including strategies and thresholds
    function quorum() external view returns (Quorum memory) {
        return _quorum;
    }

    function getCurrentOperatorSetId() external view returns (uint32) {
        return currentOperatorSetId;
    }

    /// @notice Gets an operator's signing key at a specific epoch
    /// @param _operator Address of the operator to query
    /// @param _referenceEpoch Epoch number to query the signing key for
    /// @return Signing key that was active at the specified epoch
    function getOperatorSigningKeyAtEpoch(
        address _operator,
        uint32 _referenceEpoch
    ) external view returns (address) {
        return address(uint160(_operatorSigningKeyAtEpoch[_referenceEpoch][_operator]));
    }

    /// @notice Gets the latest P2p key for an operator
    /// @param _operator Address of the operator to query
    /// @return Latest P2p key for the operator
    function getOperatorP2pKeyAtEpoch(
        address _operator,
        uint32 _referenceEpoch
    ) external view returns (address) {
        return address(uint160(_operatorP2pKeyAtEpoch[_referenceEpoch][_operator]));
    }

    /// @notice Gets an operator's weight at a specific epoch
    /// @param _operator Address of the operator to query
    /// @param _referenceEpoch Epoch number to query the weight for
    /// @return Weight that was active at the specified epoch
    function getOperatorWeightAtEpoch(
        address _operator,
        uint32 _referenceEpoch
    ) external view returns (uint256) {
        return _operatorWeightAtEpoch[_referenceEpoch][_operator];
    }

    /// @notice Gets the threshold weight at a specific epoch
    /// @param _referenceEpoch Epoch number to query
    /// @return Threshold weight that was active at the specified epoch
    function getThresholdWeightAtEpoch(
        uint32 _referenceEpoch
    ) external view returns (uint256) {
        return _thresholdWeightAtEpoch[_referenceEpoch];
    }

    /// @notice Gets the operator address associated with a given signing key
    /// @param _signingKey The signing key to query
    /// @return The operator address associated with the signing key
    function getOperatorBySigningKey(
        address _signingKey
    ) external view returns (address) {
        return _signingKeyToOperator[_signingKey];
    }

    /// @notice Gets the minimum weight requirement for operators
    /// @return Current minimum weight threshold
    function minimumWeight() external view returns (uint256) {
        return _minimumWeight;
    }

    function operatorRegisteredOnAVSDirectory(
        address operator
    ) public view returns (bool) {
        return AVS_DIRECTORY.avsOperatorStatus(address(_serviceManager), operator)
            == IAVSDirectoryTypes.OperatorAVSRegistrationStatus.REGISTERED;
    }

    function operatorRegisteredOnCurrentOperatorSet(
        address operator
    ) public view returns (bool) {
        if (address(allocationManager) == address(0)) {
            return false;
        }
        OperatorSet memory operatorSet =
            OperatorSet({avs: address(_serviceManager), id: currentOperatorSetId});
        return allocationManager.isMemberOfOperatorSet(operator, operatorSet);
    }

    function operatorRegistered(
        address operator
    ) public view returns (bool) {
        return operatorRegisteredOnAVSDirectory(operator)
            || operatorRegisteredOnCurrentOperatorSet(operator);
    }


    /// @notice Calculates an operator's current weight based on their delegated stake
    /// @param _operator Address of the operator to calculate weight for
    /// @return Current weight of the operator (0 if below minimum threshold)
    /// @dev Queries mainnet delegation manager for current shares
    function getOperatorWeight(
        address _operator
    ) public view returns (uint256) {
        uint256 quorumWeight = getQuorumWeight(_operator);
        uint256 operatorSetWeight = getOperatorSetWeight(_operator);

        return quorumWeight + operatorSetWeight;
    }

    /// @notice Calculates operator's weight in the quorum
    /// @dev Weight calculation:
    ///      1. Get operator's shares for each strategy
    ///      2. Multiply shares by strategy multiplier
    ///      3. Sum up weighted shares and divide by BPS
    ///      4. Return 0 if below minimum weight
    /// @param operator The operator address to calculate weight for
    /// @return The operator's weight in quorum, or 0 if below minimum
    function getQuorumWeight(
        address operator
    ) public view returns (uint256) {
        // Get strategy params from quorum
        StrategyParams[] memory strategyParams = _quorum.strategies;
        uint256 weight;

        // Create strategy array for batch shares query
        IStrategy[] memory strategies = new IStrategy[](strategyParams.length);
        for (uint256 i; i < strategyParams.length; i++) {
            strategies[i] = strategyParams[i].strategy;
        }

        // Get operator's shares for all strategies
        uint256[] memory shares = DELEGATION_MANAGER.getOperatorShares(operator, strategies);

        // Calculate weighted sum of shares
        for (uint256 i; i < strategyParams.length; i++) {
            weight += shares[i] * strategyParams[i].multiplier;
        }
        // Divide by BPS to get final weight
        weight = weight / BPS;

        // Return 0 if below minimum weight
        if (weight >= _minimumWeight) {
            return weight;
        } else {
            return 0;
        }
    }

    /// @notice Calculates operator's available weight in current operator set
    /// @dev Weight calculation:
    ///      1. Check operator set membership
    ///      2. Get shares and allocation for each strategy
    ///      3. Calculate available proportion (currentMagnitude/maxMagnitude)
    ///      4. Sum up available shares weighted by proportion
    /// @param operator The operator address to calculate weight for
    /// @return The operator's available weight in set, or 0 if below minimum
    function getOperatorSetWeight(
        address operator
    ) public view returns (uint256) {
        // Return 0 if allocation manager not set
        if (address(allocationManager) == address(0)) {
            return 0;
        }

        // Create operator set struct
        OperatorSet memory operatorSet =
            OperatorSet({avs: address(_serviceManager), id: currentOperatorSetId});

        // Check operator set membership
        if (!allocationManager.isMemberOfOperatorSet(operator, operatorSet)) {
            return 0;
        }

        // Get strategies from operator set
        IStrategy[] memory strategies = allocationManager.getStrategiesInOperatorSet(operatorSet);
        if (strategies.length == 0) {
            return 0;
        }

        // Get operator's shares for all strategies
        uint256[] memory shares = DELEGATION_MANAGER.getOperatorShares(operator, strategies);

        uint256 weight;

        // Calculate available weight for each strategy
        for (uint256 i = 0; i < strategies.length; i++) {
            // Get allocation and max magnitude
            IAllocationManager.Allocation memory allocation =
                allocationManager.getAllocation(operator, operatorSet, strategies[i]);
            uint64 maxMagnitude = allocationManager.getMaxMagnitude(operator, strategies[i]);

            if (maxMagnitude == 0) {
                continue;
            }

            // Calculate available proportion
            uint256 slashableProportion = uint256(allocation.currentMagnitude) * WAD / maxMagnitude;

            // Add weighted shares to total
            weight += shares[i] * slashableProportion / WAD;
        }

        // Return 0 if below minimum weight
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
        return _thresholdWeightAtEpoch[_referenceEpoch];
    }

    /// @notice Initializes state for the StakeRegistry
    /// @param _thresholdWeight The threshold weight for the stake registry
    /// @param quorumParams The quorum configuration for the stake registry
    function __ECDSAStakeRegistry_init(
        address _serviceManagerAddress,
        uint256 _thresholdWeight,
        Quorum memory quorumParams
    ) internal onlyInitializing {
        _serviceManager = _serviceManagerAddress;
        _updateStakeThreshold(_thresholdWeight);
        _updateQuorumConfig(quorumParams);
        __Ownable_init();
    }

    /// @dev Updates the weights for a given list of operator addresses.
    /// When passing an operator that isn't registered, then 0 is added to their history
    /// @param _operators An array of addresses for which to update the weights.
    function _updateOperators(
        address[] memory _operators
    ) internal {
        for (uint256 i; i < _operators.length; i++) {
            _updateOperatorWeight(_operators[i]);
        }
    }

    /// @dev Updates the stake threshold weight and records the history.
    /// @param _thresholdWeight The new threshold weight to set and record in the history.
    function _updateStakeThreshold(
        uint256 _thresholdWeight
    ) internal {
        uint32 effectiveEpoch = IEpochManager(EPOCH_MANAGER).getEffectiveEpoch();
        _thresholdWeightAtEpoch[effectiveEpoch] = _thresholdWeight;
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
            revert ECDSAStakeRegistry__InvalidQuorum();
        }
        Quorum memory oldQuorum = _quorum;
        delete _quorum;
        for (uint256 i; i < _newQuorum.strategies.length; i++) {
            _quorum.strategies.push(_newQuorum.strategies[i]);
        }
        emit QuorumUpdated(oldQuorum, _newQuorum);
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
        _updateOperatorWeight(_operator);
        _updateOperatorSigningKey(_operator, _signingKey);
        _updateOperatorP2pKey(_operator, _p2pKey);
        IServiceManager(_serviceManager).registerOperatorToAVS(_operator, _operatorSignature);
    }

    /// @dev Internal function to deregister an operator
    /// @param _operator The operator's address to deregister
    function _deregisterOperator(
        address _operator
    ) internal {
        _updateOperatorWeight(_operator);
        IServiceManager(_serviceManager).deregisterOperatorFromAVS(_operator);
    }

    /// @dev Internal function to update an operator's signing key
    /// @param _operator The address of the operator to update the signing key for
    /// @param _newSigningKey The new signing key to set for the operator
    function _updateOperatorSigningKey(address _operator, address _newSigningKey) internal {
        uint32 effectiveEpoch = IEpochManager(EPOCH_MANAGER).getEffectiveEpoch();
        address oldSigningKey = _operatorSigningKeyAtEpoch[effectiveEpoch][_operator];

        // if the signing key is already set in this epoch, then return
        if (oldSigningKey != address(0) || _newSigningKey == oldSigningKey) {
            return;
        }
        _operatorSigningKeyAtEpoch[effectiveEpoch][_operator] = _newSigningKey;

        // if the signing key is already set for another operator, then revert
        if (_signingKeyToOperator[_newSigningKey] != address(0) && _signingKeyToOperator[_newSigningKey] != _operator) {
            revert ECDSAStakeRegistry__SigningKeyAlreadySet();
        }
        _signingKeyToOperator[_newSigningKey] = _operator;

        emit SigningKeyUpdate(_operator, _newSigningKey, oldSigningKey);
    }

    /// @dev Internal function to update an operator's P2p key
    /// @param _operator The address of the operator to update the P2p key for
    /// @param _newP2pKey The new P2p key to set for the operator
    function _updateOperatorP2pKey(address _operator, address _newP2pKey) internal {
        uint32 effectiveEpoch = IEpochManager(EPOCH_MANAGER).getEffectiveEpoch();

        // if p2p key is set for this epoch, or the new p2p key is the same as the old one, then return
        address oldP2pKey = _operatorP2pKeyAtEpoch[effectiveEpoch][_operator];
        if (oldP2pKey != address(0) || _newP2pKey == oldP2pKey) {
            return;
        }

        _operatorP2pKeyAtEpoch[effectiveEpoch][_operator] = _newP2pKey;
        emit P2pKeyUpdate(_operator, _newP2pKey, oldP2pKey);
    }

    /// @notice Updates the weight of an operator and returns the previous and current weights.
    /// @param _operator The address of the operator to update the weight of.
    function _updateOperatorWeight(
        address _operator
    ) internal virtual {
        uint32 effectiveEpoch = IEpochManager(EPOCH_MANAGER).getEffectiveEpoch();
        uint256 newWeight = getOperatorWeight(_operator);
        _operatorWeightAtEpoch[effectiveEpoch][_operator] = newWeight;
        emit OperatorWeightUpdated(_operator, newWeight);
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
            if (lastStrategy >= currentStrategy) revert ECDSAStakeRegistry__NotSorted();
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
            signer = _getOperatorSigningKeyAtEpoch(currentOperator, _referenceEpoch);

            _validateSortedSigners(lastOperator, currentOperator);
            _validateSignature(signer, _dataHash, _signatures[i]);

            lastOperator = currentOperator;
            uint256 operatorWeight = _getOperatorWeightAtEpoch(currentOperator, _referenceEpoch);
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
            revert ECDSAStakeRegistry__LengthMismatch();
        }
        if (_signersLength == 0) {
            revert ECDSAStakeRegistry__InvalidLength();
        }
    }

    /// @notice Ensures that signers are sorted in ascending order by address.
    /// @param _lastSigner The address of the last signer.
    /// @param _currentSigner The address of the current signer.
    function _validateSortedSigners(address _lastSigner, address _currentSigner) internal pure {
        if (_lastSigner >= _currentSigner) {
            revert ECDSAStakeRegistry__NotSorted();
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
            revert ECDSAStakeRegistry__InvalidSignature();
        }
    }

    /// @notice Retrieves the operator signing key for a signer, either at the last checkpoint or a specified epoch.
    /// @param _operator The operator to query their signing key history for
    /// @param _referenceEpoch The epoch number to query the operator's weight at, or the maximum uint32 value for the last checkpoint.
    /// @return The weight of the operator.
    function _getOperatorSigningKeyAtEpoch(
        address _operator,
        uint32 _referenceEpoch
    ) internal view returns (address) {
        return _operatorSigningKeyAtEpoch[_referenceEpoch][_operator];
    }

    /// @notice Retrieves the operator weight for a signer, either at the last checkpoint or a specified epoch.
    /// @param _operator The operator to query their signing key history for
    /// @param _referenceEpoch The epoch number to query the operator's weight at, or the maximum uint32 value for the last checkpoint.
    /// @return The weight of the operator.
    function _getOperatorWeightAtEpoch(
        address _operator,
        uint32 _referenceEpoch
    ) internal view returns (uint256) {
        return _operatorWeightAtEpoch[_referenceEpoch][_operator];
    }

    /// @notice Retrieves the threshold stake for a given reference epoch.
    /// @param _referenceEpoch The epoch number to query the threshold stake for.
    /// If set to the maximum uint32 value, it retrieves the latest threshold stake.
    /// @return The threshold stake in basis points for the reference epoch.
    function _getThresholdWeightAtEpoch(
        uint32 _referenceEpoch
    ) internal view returns (uint256) {
        return _thresholdWeightAtEpoch[_referenceEpoch];
    }

    /// @notice Validates that the cumulative stake of signed messages meets or exceeds the required threshold.
    /// @param _signedWeight The cumulative weight of the signers that have signed the message.
    /// @param _referenceEpoch The epoch number to verify the stake threshold for
    function _validateThresholdStake(uint256 _signedWeight, uint32 _referenceEpoch) internal view {
        uint256 thresholdWeight = _getThresholdWeightAtEpoch(_referenceEpoch);
        if (thresholdWeight > _signedWeight) {
            revert ECDSAStakeRegistry__InsufficientSignedStake();
        }
    }
}
