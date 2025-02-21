// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin-v5.0.0/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IAllocationManager, IAllocationManagerTypes} from "eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {IMainChainVerifier} from "../interfaces/IMainChainVerifier.sol";
import {IStateDisputeResolver} from "../interfaces/IStateDisputeResolver.sol";
import {ISpottedServiceManager} from "../interfaces/ISpottedServiceManager.sol";
import {IECDSAStakeRegistry} from "../interfaces/IECDSAStakeRegistry.sol";
import {OperatorSet} from "eigenlayer-contracts/src/contracts/libraries/OperatorSetLib.sol";
import "../interfaces/IEpochManager.sol";
import {ISlasher} from "../interfaces/ISlasher.sol";

/// @title State Dispute Resolver
/// @author Spotted Team
/// @notice Handles disputes over state claims and manages operator slashing
/// @dev Implements EIP-712 for typed data signing and verification
contract StateDisputeResolver is ReentrancyGuard, EIP712, Ownable, IStateDisputeResolver {
    /// @notice Core protocol dependencies - all immutable for security and gas optimization
    IEpochManager public immutable epochManager;
    IMainChainVerifier public immutable mainChainVerifier;
    IECDSAStakeRegistry public immutable ecdsaStakeRegistry;
    ISlasher public immutable slasher;
    string public constant VERSION = "1.0.0";
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

    /// @notice Address authorized to submit challenges
    address public challengeSubmitter;

    /// @notice Current operator set identifier
    uint32 public currentOperatorSetId;

    /// @notice Amount to slash from operators (in WAD format)
    uint256 public slashAmount;

    /// @notice EIP-712 type hash for State struct
    /// @dev Used in typed data signing
    bytes32 private constant STATE_TYPEHASH =
        keccak256("State(address user,uint32 chainId,uint64 blockNumber,uint256 key,uint256 value)");

    /// @notice Mapping of active challenges
    mapping(bytes32 => Challenge) private challenges;

    /// @notice Mapping to track challenged operators
    mapping(bytes32 => mapping(address => bool)) private operatorSlashed;

    /// @notice Mapping to track challenged operators
    mapping(bytes32 => mapping(address => bool)) private operatorChallenged;

    /// @notice Maximum number of signatures allowed per submission
    uint256 public constant MAX_SIGNATURES = 50;

    /// @notice Mapping of claimable amounts for each address
    mapping(address => uint256) public claimableAmount;

    /// @notice Contract constructor
    /// @dev Sets all core dependencies and initializes the contract
    /// @param _epochManager Address of epoch manager contract
    /// @param _mainChainVerifier Address of main chain verifier contract
    /// @param _ecdsaStakeRegistry Address of ECDSA stake registry contract
    /// @param _slasher Address of slasher contract
    constructor(
        address _epochManager,
        address _mainChainVerifier,
        address _ecdsaStakeRegistry,
        address _slasher
    ) EIP712("SpottedStateResolver", VERSION) {
        epochManager = IEpochManager(_epochManager);
        mainChainVerifier = IMainChainVerifier(_mainChainVerifier);
        ecdsaStakeRegistry = IECDSAStakeRegistry(_ecdsaStakeRegistry);
        slasher = ISlasher(_slasher);
    }

    /// @notice Allows contract to receive ETH
    receive() external payable {}

    /// @notice Submit challenge based on state data and signatures
    /// @param stateData The original state data that was signed
    /// @param signatures Array of signatures from operators
    function submitChallenge(
        State calldata stateData,
        bytes[] calldata signatures
    ) external payable nonReentrant {
        if (msg.value < CHALLENGE_BOND) {
            revert StateDisputeResolver__InsufficientBond();
        }

        if (signatures.length == 0) {
            revert StateDisputeResolver__NoSignatures();
        }

        if (signatures.length > MAX_SIGNATURES) {
            revert StateDisputeResolver__TooManySignatures();
        }

        // Generate task ID
        bytes32 taskId = keccak256(abi.encode(stateData));

        // Generate the hash that was signed
        bytes32 structHash = keccak256(
            abi.encode(
                STATE_TYPEHASH,
                stateData.user,
                stateData.chainId,
                stateData.blockNumber,
                stateData.key,
                stateData.value
            )
        );
        bytes32 hashData = _hashTypedDataV4(structHash);

        // Create or get existing challenge
        Challenge storage challenge = challenges[taskId];
        if (challenge.challengers.length == 0) {
            // Initialize new challenge
            challenge.state = State({
                user: stateData.user,
                chainId: stateData.chainId,
                blockNumber: stateData.blockNumber,
                key: stateData.key,
                value: stateData.value
            });
        }

        // Verify each signature and process operators
        for (uint256 i = 0; i < signatures.length;) {
            address signingKey = ECDSA.recover(hashData, signatures[i]);
            address operator = ecdsaStakeRegistry.getOperatorBySigningKey(signingKey);
            if (operator == address(0)) {
                revert StateDisputeResolver__InvalidSignature();
            }
            // Check if already challenged
            if (operatorChallenged[taskId][operator]) {
                revert StateDisputeResolver__AlreadyChallenged();
            }

            // Mark as challenged and add to array
            operatorChallenged[taskId][operator] = true;
            challenge.challengedOperators.push(operator);

            unchecked {
                ++i;
            }
        }

        // Add challenger
        challenge.challengers.push(msg.sender);

        emit ChallengeSubmitted(taskId, msg.sender);
    }

    /// @notice Claim challenge bond
    function claim() external nonReentrant {
        uint256 amount = claimableAmount[msg.sender];
        if (amount == 0) {
            revert StateDisputeResolver__NoFundsToClaim();
        }

        // Update state before transfer
        claimableAmount[msg.sender] = 0;

        // Transfer funds
        (bool success,) = msg.sender.call{value: amount}("");
        if (!success) {
            revert StateDisputeResolver__TransferFailed();
        }

        emit ClaimProcessed(msg.sender, amount);
    }

    /// @notice Resolves a submitted challenge
    /// @param taskId Identifier of the challenge to resolve
    function resolveChallenge(
        bytes32 taskId
    ) external nonReentrant {
        Challenge storage challenge = challenges[taskId];

        if (challenge.resolved) {
            revert StateDisputeResolver__ChallengeAlreadyResolved();
        }

        if (challenge.challengers.length == 0) {
            revert StateDisputeResolver__NoChallengers();
        }

        // Get verified state
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
        challenge.resolved = true;

        if (challengeSuccessful) {
            // Record claimable amounts for challengers instead of direct transfer
            uint256 challengerCount = challenge.challengers.length;
            for (uint256 i = 0; i < challengerCount;) {
                address challenger = challenge.challengers[i];
                claimableAmount[challenger] += CHALLENGE_BOND;
                unchecked {
                    ++i;
                }
            }

            // Slash operators
            uint256 operatorCount = challenge.challengedOperators.length;
            for (uint256 i = 0; i < operatorCount;) {
                address operator = challenge.challengedOperators[i];

                _slashOperator(operator, taskId);
                unchecked {
                    ++i;
                }
            }
        }

        // Clear arrays
        delete challenge.challengedOperators;
        delete challenge.challengers;

        emit ChallengeResolved(taskId, challengeSuccessful);
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
        try slasher.fulfillSlashingRequest(operator) {
            emit OperatorSlashed(operator, challengeId);
        } catch {
            emit SlashingFailed(operator, challengeId);
        }
    }
}
