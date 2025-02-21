// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC1271Upgradeable} from "@openzeppelin-upgrades/contracts/interfaces/IERC1271Upgradeable.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {ISignatureUtils} from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";

interface IECDSAStakeRegistryTypes {
    /// @notice Parameters for a strategy and its weight multiplier
    struct StrategyParams {
        IStrategy strategy;
        uint96 multiplier;
    }

    /// @notice Configuration for a quorum's strategies
    struct Quorum {
        StrategyParams[] strategies;
    }
}

interface IECDSAStakeRegistryErrors {
    /// @notice Thrown when signature is invalid
    error ECDSAStakeRegistry__InvalidSignature();
    /// @notice Thrown when length of signers and signatures mismatch
    error ECDSAStakeRegistry__LengthMismatch();
    /// @notice Thrown when length is invalid (zero)
    error ECDSAStakeRegistry__InvalidLength();
    /// @notice Indicates the total signed stake fails to meet the required threshold
    error ECDSAStakeRegistry__InsufficientSignedStake();
    /// @notice Indicates the system finds a list of items unsorted
    error ECDSAStakeRegistry__NotSorted();
    /// @notice Thrown when registering an already registered operator
    error ECDSAStakeRegistry__OperatorAlreadyRegistered();
    /// @notice Thrown when de-registering or updating the stake for an unregisted operator
    error ECDSAStakeRegistry__OperatorNotRegistered();
    /// @notice Thrown when the reference epoch is invalid
    error ECDSAStakeRegistry__InvalidEpoch();
    /// @notice Thrown when the signing key is already set
    error ECDSAStakeRegistry__SigningKeyAlreadySet();
    /// @notice Indicates the quorum is invalid
    error ECDSAStakeRegistry__InvalidQuorum();
    /// @notice Thrown when M2 quorum registration is disabled
    error ECDSAStakeRegistry__M2QuorumRegistrationIsDisabled();
    /// @notice Thrown when the sender is not authorized
    error ECDSAStakeRegistry__InvalidSender();
}

interface IECDSAStakeRegistryEvents is IECDSAStakeRegistryTypes {
    /// @notice Emitted when an operator is registered
    event OperatorRegistered(
        address indexed _operator,
        uint256 blockNumber,
        address _p2pKey,
        address _signingKey,
        address _avs
    );

    /// @notice Emitted when an operator is deregistered
    event OperatorDeregistered(
        address indexed operator,
        uint256 blockNumber,
        address serviceManager
    );

    /// @notice Emitted when an operator's signing key is updated
    event SigningKeyUpdate(
        address indexed operator,
        address newSigningKey,
        address oldSigningKey
    );

    /// @notice Emitted when an operator's p2p key is updated
    event P2pKeyUpdate(
        address indexed operator,
        address newP2pKey,
        address oldP2pKey
    );

    /// @notice Emitted when an operator's weight is updated
    event OperatorWeightUpdated(
        address indexed operator,
        uint256 newWeight
    );

    /// @notice Emitted when the threshold weight is updated
    event ThresholdWeightUpdated(uint256 newThresholdWeight);

    /// @notice Emitted when the minimum weight is updated
    event MinimumWeightUpdated(
        uint256 oldMinimumWeight,
        uint256 newMinimumWeight
    );

    /// @notice Emitted when the quorum configuration is updated
    event QuorumUpdated(Quorum oldQuorum, Quorum newQuorum);

    /// @notice Emitted when M2 quorum registration is disabled
    event M2QuorumRegistrationDisabled();
}

interface IECDSAStakeRegistry is
    IECDSAStakeRegistryErrors,
    IECDSAStakeRegistryEvents,
    IERC1271Upgradeable
{
    /* INITIALIZATION */
    
    /// @notice Initializes the contract with threshold weight and quorum
    function initialize(
        address _serviceManager,
        uint256 _thresholdWeight,
        Quorum memory quorumParams
    ) external;

    /// @notice Disables M2 quorum registration
    function disableM2QuorumRegistration() external;

    /* OPERATOR MANAGEMENT */

    /// @notice Registers a new operator using a provided signature and signing key
    function registerOperatorOnAVSDirectory(
        ISignatureUtils.SignatureWithSaltAndExpiry memory _operatorSignature,
        address _signingKey,
        address _p2pKey
    ) external;

    /// @notice Deregisters an existing operator
    function deregisterOperatorOnAVSDirectory() external;

    /// @notice Called by AVS Registrar when operator is registered
    function onOperatorSetRegistered(
        address operator,
        address signingKey,
        address p2pKey
    ) external;

    /// @notice Called by AVS Registrar when operator is deregistered
    function onOperatorSetDeregistered(address operator) external;

    /* KEY MANAGEMENT */

    /// @notice Updates the signing key for an operator
    function updateOperatorSigningKey(address _newSigningKey) external;

    /// @notice Updates the p2p key for an operator
    function updateOperatorP2pKey(address _newP2pKey) external;

    /* WEIGHT MANAGEMENT */

    /// @notice Updates operators' weights
    function updateOperators(address[] memory _operators) external;

    /// @notice Updates the quorum configuration and operators
    function updateQuorumConfig(
        Quorum memory newQuorumConfig,
        address[] memory _operators
    ) external;

    /// @notice Updates minimum weight requirement
    function updateMinimumWeight(
        uint256 _newMinimumWeight,
        address[] memory _operators
    ) external;

    /// @notice Updates stake threshold
    function updateStakeThreshold(uint256 _thresholdWeight) external;

    /// @notice Sets current operator set ID
    function setCurrentOperatorSetId(uint32 _id) external;

    /* VIEW FUNCTIONS */

    /// @notice Gets current operator set ID
    function getCurrentOperatorSetId() external view returns (uint32);

    /// @notice Checks if operator is registered on AVS Directory
    function operatorRegisteredOnAVSDirectory(address operator) external view returns (bool);

    /// @notice Checks if operator is registered on current operator set
    function operatorRegisteredOnCurrentOperatorSet(address operator) external view returns (bool);

    /// @notice Checks if operator is registered
    function operatorRegistered(address operator) external view returns (bool);

    /// @notice Gets current quorum configuration
    function quorum() external view returns (Quorum memory);

    /// @notice Gets operator's signing key at epoch
    function getOperatorSigningKeyAtEpoch(
        address _operator,
        uint32 _epochNumber
    ) external view returns (address);

    /// @notice Gets operator's p2p key at epoch
    function getOperatorP2pKeyAtEpoch(
        address _operator,
        uint32 _epochNumber
    ) external view returns (address);

    /// @notice Gets operator's weight at epoch
    function getOperatorWeightAtEpoch(
        address _operator,
        uint32 _epochNumber
    ) external view returns (uint256);

    /// @notice Gets threshold weight at epoch
    function getThresholdWeightAtEpoch(
        uint32 _epochNumber
    ) external view returns (uint256);

    /// @notice Gets operator by signing key
    function getOperatorBySigningKey(
        address _signingKey
    ) external view returns (address);

    /// @notice Gets minimum weight requirement
    function minimumWeight() external view returns (uint256);

    /// @notice Gets operator's current weight
    function getOperatorWeight(address _operator) external view returns (uint256);

    /// @notice Gets operator's quorum weight
    function getQuorumWeight(address operator) external view returns (uint256);

    /// @notice Gets operator's set weight
    function getOperatorSetWeight(address operator) external view returns (uint256);

    /// @notice Gets threshold stake at epoch
    function getThresholdStake(uint32 _epochNumber) external view returns (uint256);
}
