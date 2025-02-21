// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IAbridgeMessageHandler} from "../interfaces/IAbridge.sol";
import {IAbridge} from "../interfaces/IAbridge.sol";

/// @title Main Chain Verifier Types Interface
/// @notice Defines types and structs used in the main chain verification system
interface IMainChainVerifierTypes {
    /// @notice Struct representing a verified state value
    /// @param value The verified state value
    /// @param exist Whether the state exists
    struct Value {
        uint256 value;
        bool exist;
    }
}

/// @title Main Chain Verifier Errors Interface
/// @notice Defines all error cases in the main chain verification system
interface IMainChainVerifierErrors {
    /// @notice Thrown when caller is not the bridge contract
    error MainChainVerifier__OnlyAbridge();
    /// @notice Thrown when verification response is invalid
    error MainChainVerifier__InvalidResponse();
    /// @notice Thrown when remote verifier is not authorized
    error MainChainVerifier__UnauthorizedRemoteVerifier();
}

/// @title Main Chain Verifier Events Interface
/// @notice Defines all events emitted by the main chain verification system
interface IMainChainVerifierEvents {
    /// @notice Emitted when a state is verified
    /// @param chainId The chain ID where the state was verified
    /// @param user The user address associated with the state
    /// @param key The state key
    /// @param blockNumber The block number when the state was verified
    /// @param value The verified state value
    event StateVerified(
        uint256 indexed chainId,
        address indexed user,
        uint256 indexed key,
        uint256 blockNumber,
        uint256 value
    );

    /// @notice Emitted when a remote verifier is set for a chain
    /// @param chainId The chain ID
    /// @param verifier The verifier address
    event RemoteVerifierSet(uint256 indexed chainId, address verifier);
}

/// @title Main Chain Verifier Interface
/// @author Spotted Team
/// @notice Interface for handling cross-chain state verification and managing remote verifiers
interface IMainChainVerifier is 
    IMainChainVerifierTypes,
    IMainChainVerifierErrors,
    IMainChainVerifierEvents,
    IAbridgeMessageHandler 
{
    /* REMOTE VERIFIER MANAGEMENT */
    
    /// @notice Sets the remote verifier for a specific chain
    /// @param chainId The chain ID to set verifier for
    /// @param verifier The verifier address
    function setRemoteVerifier(uint256 chainId, address verifier) external;

    /* STATE QUERIES */

    /// @notice Gets the verified state for given parameters
    /// @param chainId The chain ID to query
    /// @param user The user address
    /// @param key The state key
    /// @param blockNumber The block number
    /// @return value The verified state value
    /// @return exist Whether the state exists
    function getVerifiedState(
        uint256 chainId,
        address user,
        uint256 key,
        uint256 blockNumber
    ) external view returns (uint256 value, bool exist);

    /* VIEW FUNCTIONS */

    /// @notice Gets the bridge contract address
    /// @return The bridge contract interface
    function abridge() external view returns (IAbridge);

    /// @notice Gets the remote verifier for a chain
    /// @param chainId The chain ID to query
    /// @return The verifier address for the chain
    function remoteVerifiers(uint256 chainId) external view returns (address);

    /// @notice Checks if an address is an authorized remote verifier
    /// @param verifier The address to check
    /// @return Whether the address is an authorized verifier
    function isRemoteVerifier(address verifier) external view returns (bool);
}
