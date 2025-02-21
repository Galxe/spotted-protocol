// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IAbridge} from "../interfaces/IAbridge.sol";
import {IStateManager} from "../interfaces/IStateManager.sol";

/// @title Remote Chain Verifier Errors Interface
/// @notice Defines all error cases in the remote chain verification system
interface IRemoteChainVerifierErrors {
    /// @notice Thrown when response from bridge is invalid
    error RemoteChainVerifier__InvalidResponse();
    /// @notice Thrown when state manager is not set
    error RemoteChainVerifier__StateManagerNotSet();
    /// @notice Thrown when main chain ID is invalid
    error RemoteChainVerifier__InvalidMainChainId();
    /// @notice Thrown when state is not found
    error RemoteChainVerifier__StateNotFound();
    /// @notice Thrown when message fee is insufficient
    error RemoteChainVerifier__InsufficientFee();
    /// @notice Thrown when block number is higher than current block
    error RemoteChainVerifier__BlockNumberTooHigh();
}

/// @title Remote Chain Verifier Events Interface
/// @notice Defines all events emitted by the remote chain verification system
interface IRemoteChainVerifierEvents {
    /// @notice Emitted when state manager address is updated
    /// @param newStateManager The new state manager address
    event StateManagerUpdated(address indexed newStateManager);

    /// @notice Emitted when verification is processed
    /// @param user The user address
    /// @param key The state key
    /// @param blockNumber The block number
    /// @param value The verified value
    event VerificationProcessed(
        address indexed user,
        uint256 indexed key,
        uint256 blockNumber,
        uint256 value
    );

    /// @notice Emitted when funds are withdrawn
    /// @param to The recipient address
    /// @param amount The amount withdrawn
    event FundsWithdrawn(address indexed to, uint256 amount);
}

/// @title Remote Chain Verifier Interface
/// @author Spotted Team
/// @notice Interface for verifying state on remote chains and sending results back to main chain
interface IRemoteChainVerifier is 
    IRemoteChainVerifierErrors,
    IRemoteChainVerifierEvents 
{
    /* STATE VERIFICATION */

    /// @notice Verifies state on remote chain and sends result to main chain
    /// @param user Address of the user whose state is being verified
    /// @param key Key of the state to verify
    /// @param blockNumber Block number at which to verify the state
    /// @dev Requires payment for cross-chain message fees
    function verifyState(
        address user,
        uint256 key,
        uint256 blockNumber
    ) external payable;

    /* CONTRACT REFERENCES */

    /// @notice Gets the bridge contract reference
    /// @return The bridge contract interface
    function abridge() external view returns (IAbridge);

    /// @notice Gets the state manager contract reference
    /// @return The state manager contract interface
    function stateManager() external view returns (IStateManager);

    /// @notice Gets the main chain ID
    /// @return The ID of the main chain
    function mainChainId() external view returns (uint256);

    /// @notice Gets the main chain verifier address
    /// @return The address of the verifier on main chain
    function mainChainVerifier() external view returns (address);
}
