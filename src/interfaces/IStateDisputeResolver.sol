// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../interfaces/IAllocationManager.sol";
import "../interfaces/IStrategy.sol";

interface IStateDisputeResolver {
    // Errors
    error StateDisputeResolver__InsufficientBond();
    error StateDisputeResolver__InvalidSignaturesLength();
    error StateDisputeResolver__InvalidSignature();
    error StateDisputeResolver__DuplicateOperator();
    error StateDisputeResolver__ChallengeAlreadyExists();
    error StateDisputeResolver__StateNotVerified();
    error StateDisputeResolver__CallerNotChallengeSubmitter();
    error StateDisputeResolver__InvalidServiceManagerAddress();
    error StateDisputeResolver__InvalidVerifierAddress();
    error StateDisputeResolver__EmptyStrategiesArray();
    error StateDisputeResolver__InvalidSlashAmount();
    error StateDisputeResolver__CallerNotServiceManager();
    error StateDisputeResolver__CallerNotMainChainVerifier();
    error StateDisputeResolver__ChallengeAlreadyResolved();
    error StateDisputeResolver__ChallengePeriodClosed();

    struct State {
        address user;
        uint32 chainId;
        uint64 blockNumber;
        uint48 timestamp;
        uint256 key;
        uint256 value;
    }

    struct Challenge {
        address challenger;
        uint64 deadline;
        bool resolved;
        State state;
        address[] operators;
        uint256 actualState;
    }

    // Events
    event ChallengeSubmitted(bytes32 indexed challengeId, address indexed challenger);
    event ChallengeResolved(bytes32 indexed challengeId, bool successful);
    event OperatorSetIdUpdated(uint32 newSetId);
    event SlashableStrategiesUpdated(IStrategy[] strategies);
    event SlashAmountUpdated(uint256 newAmount);
    event ServiceManagerSet(address indexed serviceManager);
    event MainChainVerifierSet(address indexed verifier);
    event OperatorSlashed(address operator, bytes32 challengeId);

    // Core functions
    function initialize(
        address _allocationManager,
        uint32 _operatorSetId,
        uint256 _slashAmount
    ) external;

    function submitChallenge(
        State calldata state,
        address[] calldata operators,
        bytes[] calldata signatures
    ) external payable;

    function resolveChallenge(
        bytes32 challengeId
    ) external;

    // Admin functions
    function setOperatorSetId(
        uint32 newSetId
    ) external;
    function setSlashableStrategies(
        IStrategy[] calldata strategies
    ) external;
    function setSlashAmount(
        uint256 newAmount
    ) external;
    function setServiceManager(
        address _serviceManager
    ) external;
    function setMainChainVerifier(
        address _verifier
    ) external;

    // View functions
    function getChallenge(
        bytes32 challengeId
    ) external view returns (Challenge memory);
}
