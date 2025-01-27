// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../interfaces/IAllocationManager.sol";
import "../interfaces/IStrategy.sol";

interface IStateDisputeResolver {
    // Version constant


    // Errors
    error StateDisputeResolver__InsufficientBond();
    error StateDisputeResolver__NoSignatures();
    error StateDisputeResolver__TooManySignatures(); 
    error StateDisputeResolver__NotActiveOperator();
    error StateDisputeResolver__AlreadyChallenged();
    error StateDisputeResolver__ChallengeAlreadyResolved();
    error StateDisputeResolver__NoChallengers();
    error StateDisputeResolver__StateNotVerified();
    error StateDisputeResolver__EmptyStrategiesArray();
    error StateDisputeResolver__InvalidSlashAmount();
    error StateDisputeResolver__NoFundsToClaim();
    error StateDisputeResolver__TransferFailed();

    struct State {
        address user;
        uint32 chainId;
        uint64 blockNumber;
        uint256 key;
        uint256 value;
    }

    struct Challenge {
        address[] challengers;
        address[] challengedOperators;
        State state;
        bool resolved;
    }

    // Events
    event ChallengeSubmitted(bytes32 indexed challengeId, address indexed challenger);
    event ChallengeResolved(bytes32 indexed challengeId, bool successful);
    event OperatorSetIdUpdated(uint32 newSetId);
    event SlashableStrategiesUpdated(IStrategy[] strategies);
    event SlashAmountUpdated(uint256 newAmount);
    error StateDisputeResolver__InvalidSignaturesLength();
    error StateDisputeResolver__DuplicateOperator();
    error StateDisputeResolver__ChallengeAlreadyExists();
    error StateDisputeResolver__CallerNotChallengeSubmitter();
    error StateDisputeResolver__InvalidServiceManagerAddress();
    error StateDisputeResolver__InvalidVerifierAddress();
    event OperatorSlashed(address operator, bytes32 challengeId);
    event ClaimProcessed(address indexed user, uint256 amount);
    event SlashingFailed(address operator, bytes32 challengeId);
    // Core functions

    function submitChallenge(
        State calldata stateData,
        bytes[] calldata signatures
    ) external payable;

    function resolveChallenge(bytes32 challengeId) external;

    // Admin functions
    function setOperatorSetId(uint32 newSetId) external;
    function setSlashableStrategies(IStrategy[] calldata strategies) external;
    function setSlashAmount(uint256 newAmount) external;

    // View functions
    function getChallenge(bytes32 challengeId) external view returns (Challenge memory);
}
