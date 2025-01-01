// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../interfaces/IAllocationManager.sol";
import "../interfaces/IStrategy.sol";

interface IStateDisputeResolver {
    // Custom errors
    error StateDisputeResolver__OperatorNotRegistered();
    error StateDisputeResolver__ChallengeAlreadyExists();
    error StateDisputeResolver__ChallengePeriodActive();
    error StateDisputeResolver__ChallengeAlreadyResolved();
    error StateDisputeResolver__InsufficientBond();
    error StateDisputeResolver__EmptyStrategiesArray();
    error StateDisputeResolver__InvalidSlashAmount();
    error StateDisputeResolver__InvalidStateManagerAddress();
    error StateDisputeResolver__StateManagerNotConfigured();
    error StateDisputeResolver__CallerNotServiceManager();
    error StateDisputeResolver__ChallengeWindowExpired();
    error StateDisputeResolver__CallerNotMainChainVerifier();
    error StateDisputeResolver__TaskNotFound();
    error StateDisputeResolver__TaskAlreadyProcessed();
    error StateDisputeResolver__StateNotVerified();
    error StateDisputeResolver__InvalidVerifierAddress();

    // Structs
    struct OperatorState {
        bool isRegistered; // whether operator is registered
        bool isSlashed; // whether operator has been slashed
        uint256 stake; // amount staked by operator
    }

    struct Challenge {
        address challenger; // address that submitted the challenge
        uint256 deadline; // block number when challenge expires
        bool resolved; // whether challenge has been resolved
        uint256 claimedState; // state claimed by operator
        uint256 actualState; // actual state verified on source chain
        bool verified; // whether the state has been verified
    }

    // Events
    event ChallengePeriodSet(uint256 newPeriod);
    event ChallengeBondSet(uint256 newBond);
    event ChallengeSubmitted(bytes32 indexed challengeId, address indexed challenger);
    event ChallengeResolved(bytes32 indexed challengeId, bool slashed);
    event OperatorSetIdUpdated(uint32 newSetId);
    event SlashableStrategiesUpdated(IStrategy[] strategies);
    event SlashAmountUpdated(uint256 newAmount);
    event OperatorSlashed(address operator, bytes32 challengeId);
    event StateManagerSet(uint256 indexed chainId, address indexed stateManager);
    event ServiceManagerSet(address indexed serviceManager);
    event MainChainVerifierSet(address indexed verifier);

    // Core functions
    function initialize(uint32 _operatorSetId, uint256 _slashAmount) external;

    function submitChallenge(address operator, uint32 taskNum) external payable;

    function resolveChallenge(address operator, uint32 taskNum) external;

    function setOperatorSetId(
        uint32 newSetId
    ) external;
    function setSlashableStrategies(
        IStrategy[] calldata strategies
    ) external;
    function setSlashAmount(
        uint256 newAmount
    ) external;
    function setStateManager(uint256 chainId, address stateManager) external;
    function setServiceManager(
        address _serviceManager
    ) external;
    function setMainChainVerifier(
        address _verifier
    ) external;

    // View functions
    function getOperator(
        address operator
    ) external view returns (OperatorState memory);
    function getChallenge(
        bytes32 challengeId
    ) external view returns (Challenge memory);
    function currentOperatorSetId() external view returns (uint32);
    function slashableStrategies(
        uint256 index
    ) external view returns (IStrategy);
    function slashAmount() external view returns (uint256);
    function stateManagers(
        uint256 chainId
    ) external view returns (address);
    function mainChainVerifier() external view returns (address);
    function getStateManager(
        uint256 chainId
    ) external view returns (address);
}
