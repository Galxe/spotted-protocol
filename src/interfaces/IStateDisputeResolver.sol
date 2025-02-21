// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/// @title State Dispute Resolver Types Interface
/// @notice Defines types and structs used in the state dispute resolution system
interface IStateDisputeResolverTypes {
    /// @notice Enum representing operator status in challenges
    enum OperatorStatus {
        UNCHALLENGED,
        CHALLENGED
    }

    /// @notice Struct representing state data that can be challenged
    struct State {
        address user;
        uint32 chainId; 
        uint64 blockNumber;
        uint256 key;
        uint256 value;
    }

    /// @notice Struct representing an active challenge
    struct Challenge {
        address[] challengers;
        address[] challengedOperators;
        State state;
        bool resolved;
    }
}

/// @title State Dispute Resolver Errors Interface
/// @notice Defines all error cases in the state dispute resolution system
interface IStateDisputeResolverErrors {
    /// @notice Thrown when bond amount is insufficient for challenge
    error StateDisputeResolver__InsufficientBond();
    /// @notice Thrown when no signatures provided
    error StateDisputeResolver__NoSignatures();
    /// @notice Thrown when too many signatures provided
    error StateDisputeResolver__TooManySignatures();
    /// @notice Thrown when signature is invalid
    error StateDisputeResolver__InvalidSignature();
    /// @notice Thrown when operator already challenged
    error StateDisputeResolver__AlreadyChallenged();
    /// @notice Thrown when challenge already resolved
    error StateDisputeResolver__ChallengeAlreadyResolved();
    /// @notice Thrown when no challengers exist
    error StateDisputeResolver__NoChallengers();
    /// @notice Thrown when state not verified
    error StateDisputeResolver__StateNotVerified();
    /// @notice Thrown when no funds to claim
    error StateDisputeResolver__NoFundsToClaim();
    /// @notice Thrown when transfer fails
    error StateDisputeResolver__TransferFailed();
}

/// @title State Dispute Resolver Events Interface
/// @notice Defines all events emitted by the state dispute resolution system
interface IStateDisputeResolverEvents {
    /// @notice Emitted when a new challenge is submitted
    event ChallengeSubmitted(bytes32 indexed challengeId, address indexed challenger);
    /// @notice Emitted when a challenge is resolved
    event ChallengeResolved(bytes32 indexed challengeId, bool successful);
    /// @notice Emitted when an operator is slashed
    event OperatorSlashed(address operator, bytes32 challengeId);
    /// @notice Emitted when a claim is processed
    event ClaimProcessed(address indexed user, uint256 amount);
    /// @notice Emitted when slashing fails
    event SlashingFailed(address operator, bytes32 challengeId);
}

/// @title State Dispute Resolver Interface
/// @author Spotted Team
/// @notice Interface for handling disputes over state claims and managing operator slashing
interface IStateDisputeResolver is 
    IStateDisputeResolverTypes,
    IStateDisputeResolverErrors,
    IStateDisputeResolverEvents 
{
    /* CHALLENGE MANAGEMENT */

    /// @notice Submit challenge based on state data and signatures
    /// @param stateData The original state data that was signed
    /// @param signatures Array of signatures from operators
    function submitChallenge(
        State calldata stateData,
        bytes[] calldata signatures
    ) external payable;

    /// @notice Resolves a submitted challenge
    /// @param challengeId Identifier of the challenge to resolve
    function resolveChallenge(bytes32 challengeId) external;

    /// @notice Claim challenge bond
    function claim() external;

    /* VIEW FUNCTIONS */

    /// @notice Retrieves challenge information
    /// @param challengeId Identifier of the challenge
    /// @return Challenge data structure
    function getChallenge(bytes32 challengeId) external view returns (Challenge memory);
}
