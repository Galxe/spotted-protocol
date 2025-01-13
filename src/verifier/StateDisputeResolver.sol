// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ReentrancyGuard} from "@openzeppelin-v5.0.0/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/IAllocationManager.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IMainChainVerifier.sol";
import "../interfaces/IStateDisputeResolver.sol";
import "../interfaces/ISpottedServiceManager.sol";
import {EIP712Upgradeable} from
    "lib/eigenlayer-middleware/lib/eigenlayer-contracts/lib/openzeppelin-contracts-upgradeable-v4.9.0/contracts/utils/cryptography/EIP712Upgradeable.sol";

/// @title State Dispute Resolver
/// @author Spotted Team
/// @notice Handles disputes over state claims and manages operator slashing
/// @dev Implements EIP-712 for typed data signing and verification
contract StateDisputeResolver is
    IStateDisputeResolver,
    ReentrancyGuard,
    EIP712Upgradeable,
    Ownable
{
    /// @notice Maximum value used to represent unverified state
    /// @dev Used as a sentinel value for unverified states
    uint256 public constant UNVERIFIED = type(uint256).max;

    /// @notice Time window for submitting challenges (in blocks)
    /// @dev Set to 24 hours worth of blocks
    uint256 public constant CHALLENGE_WINDOW = 7200;

    /// @notice Required bond amount for submitting challenges
    /// @dev Set to 1 ETH in wei
    uint256 public constant CHALLENGE_BOND = 1 ether;

    /// @notice Duration of challenge period (in blocks)
    /// @dev Set to 24 hours worth of blocks
    uint256 public constant CHALLENGE_PERIOD = 7200;

    /// @notice Reference to allocation manager contract
    IAllocationManager public allocationManager;

    /// @notice Reference to main chain verifier contract
    IMainChainVerifier public mainChainVerifier;

    /// @notice Address authorized to submit challenges
    address public challengeSubmitter;

    /// @notice Current operator set identifier
    uint32 public currentOperatorSetId;

    /// @notice Array of strategies that can be slashed
    IStrategy[] public slashableStrategies;

    /// @notice Amount to slash from operators (in WAD format)
    uint256 public slashAmount;

    /// @notice Reference to service manager contract
    ISpottedServiceManager public serviceManager;

    /// @notice EIP-712 type hash for State struct
    /// @dev Used in typed data signing
    bytes32 private constant STATE_TYPEHASH = keccak256(
        "State(address user,uint32 chainId,uint64 blockNumber,uint48 timestamp,uint256 key,uint256 value)"
    );

    /// @notice Mapping of active challenges
    mapping(bytes32 => Challenge) private challenges;

    /// @notice Ensures caller is the service manager
    modifier onlyServiceManager() {
        if (msg.sender != address(serviceManager)) {
            revert StateDisputeResolver__CallerNotServiceManager();
        }
        _;
    }

    /// @notice Ensures caller is the main chain verifier
    modifier onlyMainChainVerifier() {
        if (msg.sender != address(mainChainVerifier)) {
            revert StateDisputeResolver__CallerNotMainChainVerifier();
        }
        _;
    }

    /// @notice Ensures caller is the challenge submitter
    modifier onlyChallengeSubmitter() {
        if (msg.sender != challengeSubmitter) {
            revert StateDisputeResolver__CallerNotChallengeSubmitter();
        }
        _;
    }

    /// @notice Contract constructor
    /// @dev Disables initializers for implementation contract
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract
    /// @param _allocationManager Address of allocation manager contract
    /// @param _operatorSetId Initial operator set ID
    /// @param _slashAmount Initial slash amount in WAD format
    function initialize(
        address _allocationManager,
        uint32 _operatorSetId,
        uint256 _slashAmount
    ) external initializer {
        __EIP712_init("SpottedStateResolver", "v1");
        allocationManager = IAllocationManager(_allocationManager);
        currentOperatorSetId = _operatorSetId;
        slashAmount = _slashAmount;
    }

    /// @notice Allows contract to receive ETH
    receive() external payable {}

    /// @notice Submits a challenge for an invalid state claim
    /// @param state The state being challenged
    /// @param operators Array of operators who signed the state
    /// @param signatures Array of signatures from operators
    /// @dev Requires challenge bond and verifies signatures
    function submitChallenge(
        State calldata state,
        address[] calldata operators,
        bytes[] calldata signatures
    ) external payable onlyChallengeSubmitter nonReentrant {
        // check bond amount using constant
        if (msg.value < CHALLENGE_BOND) {
            revert StateDisputeResolver__InsufficientBond();
        }

        // Check arrays length match
        if (operators.length != signatures.length || operators.length == 0) {
            revert StateDisputeResolver__InvalidSignaturesLength();
        }

        // Generate EIP712 hash
        bytes32 structHash = keccak256(
            abi.encode(
                STATE_TYPEHASH,
                state.user,
                state.chainId,
                state.blockNumber,
                state.timestamp,
                state.key,
                state.value
            )
        );
        bytes32 hashData = _hashTypedDataV4(structHash);
        uint256 signaturesLength = signatures.length;
        // Verify each signature and check operators match
        for (uint256 i = 0; i < signaturesLength;) {
            address recoveredSigner = ECDSA.recover(hashData, signatures[i]);
            if (recoveredSigner != operators[i]) {
                revert StateDisputeResolver__InvalidSignature();
            }
            // Check for duplicate operators
            for (uint256 j = 0; j < i; j++) {
                if (operators[j] == recoveredSigner) {
                    revert StateDisputeResolver__DuplicateOperator();
                }
            }
            unchecked {
                ++i;
            }
        }

        // Generate challenge ID
        bytes32 challengeId = keccak256(
            abi.encodePacked(
                state.user, state.chainId, state.blockNumber, state.timestamp, state.key
            )
        );

        if (challenges[challengeId].challenger != address(0)) {
            revert StateDisputeResolver__ChallengeAlreadyExists();
        }

        challenges[challengeId] = Challenge({
            challenger: msg.sender,
            deadline: uint64(block.number + CHALLENGE_PERIOD),
            resolved: false,
            state: state,
            operators: operators,
            actualState: UNVERIFIED
        });

        emit ChallengeSubmitted(challengeId, msg.sender);
    }

    /// @notice Resolves a submitted challenge
    /// @param challengeId Identifier of the challenge to resolve
    /// @dev Verifies state and handles slashing if challenge is successful
    function resolveChallenge(
        bytes32 challengeId
    ) external {
        Challenge storage challenge = challenges[challengeId];
        if (challenge.resolved) {
            revert StateDisputeResolver__ChallengeAlreadyResolved();
        }
        if (block.number >= challenge.deadline) {
            revert StateDisputeResolver__ChallengePeriodClosed();
        }

        // Get verified state from MainChainVerifier
        (uint256 actualValue, bool exist) = mainChainVerifier.getVerifiedState(
            challenge.state.chainId,
            challenge.state.user,
            challenge.state.key,
            challenge.state.blockNumber
        );

        if (!exist) {
            revert StateDisputeResolver__StateNotVerified();
        }

        bool challengeSuccessful = challenge.state.value != actualValue;

        // Slash operators if challenge successful
        if (challengeSuccessful) {
            for (uint256 i = 0; i < challenge.operators.length; i++) {
                _slashOperator(challenge.operators[i], challengeId);
            }
            payable(msg.sender).transfer(CHALLENGE_BOND);
        }

        challenge.resolved = true;
        challenge.actualState = actualValue;

        emit ChallengeResolved(challengeId, challengeSuccessful);
    }

    /// @notice Updates the operator set ID
    /// @param newSetId New operator set identifier
    function setOperatorSetId(
        uint32 newSetId
    ) external onlyOwner {
        currentOperatorSetId = newSetId;
        emit OperatorSetIdUpdated(newSetId);
    }

    /// @notice Sets the strategies that can be slashed
    /// @param strategies Array of strategy contracts
    function setSlashableStrategies(
        IStrategy[] calldata strategies
    ) external onlyOwner {
        uint256 strategiesLength = strategies.length;
        if (strategiesLength == 0) {
            revert StateDisputeResolver__EmptyStrategiesArray();
        }
        delete slashableStrategies;

        for (uint256 i = 0; i < strategiesLength;) {
            slashableStrategies.push(strategies[i]);
            unchecked {
                ++i;
            }
        }
        emit SlashableStrategiesUpdated(strategies);
    }

    /// @notice Updates the slash amount
    /// @param newAmount New slash amount in WAD format
    function setSlashAmount(
        uint256 newAmount
    ) external onlyOwner {
        if (newAmount > 1e18) {
            revert StateDisputeResolver__InvalidSlashAmount();
        }
        slashAmount = newAmount;
        emit SlashAmountUpdated(newAmount);
    }

    /// @notice Sets the service manager address
    /// @param _serviceManager Address of new service manager
    function setServiceManager(
        address _serviceManager
    ) external onlyOwner {
        if (_serviceManager == address(0)) {
            revert StateDisputeResolver__InvalidServiceManagerAddress();
        }
        serviceManager = ISpottedServiceManager(_serviceManager);
        emit ServiceManagerSet(_serviceManager);
    }

    /// @notice Sets the main chain verifier address
    /// @param _verifier Address of new main chain verifier
    function setMainChainVerifier(
        address _verifier
    ) external onlyOwner {
        if (_verifier == address(0)) {
            revert StateDisputeResolver__InvalidVerifierAddress();
        }
        mainChainVerifier = IMainChainVerifier(_verifier);
        emit MainChainVerifierSet(_verifier);
    }

    /// @notice Retrieves challenge information
    /// @param challengeId Identifier of the challenge
    /// @return Challenge Challenge data structure
    function getChallenge(
        bytes32 challengeId
    ) external view returns (Challenge memory) {
        return challenges[challengeId];
    }

    /// @notice Internal function to slash an operator
    /// @param operator Address of operator to slash
    /// @param challengeId Identifier of the related challenge
    /// @dev Applies slashing across all slashable strategies
    function _slashOperator(address operator, bytes32 challengeId) private {
        if (slashableStrategies.length == 0) {
            revert StateDisputeResolver__EmptyStrategiesArray();
        }

        uint256[] memory wadsToSlash = new uint256[](slashableStrategies.length);
        uint256 strategiesLength = slashableStrategies.length;
        for (uint256 i = 0; i < strategiesLength;) {
            wadsToSlash[i] = slashAmount;
            unchecked {
                ++i;
            }
        }

        IAllocationManager.SlashingParams memory params = IAllocationManager.SlashingParams({
            operator: operator,
            operatorSetId: currentOperatorSetId,
            strategies: slashableStrategies,
            wadsToSlash: wadsToSlash,
            description: string(
                abi.encodePacked("Cross chain state verification failure-Challenge ID: ", challengeId)
            )
        });

        allocationManager.slashOperator(address(this), params);
        emit OperatorSlashed(operator, challengeId);
    }
}
