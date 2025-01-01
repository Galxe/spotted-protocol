// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IAbridgeMessageHandler} from "../interfaces/IAbridge.sol";
import {IAbridge} from "../interfaces/IAbridge.sol";

interface IMainChainVerifier is IAbridgeMessageHandler {
    // Errors
    error MainChainVerifier__OnlyAbridge();
    error MainChainVerifier__OnlyDisputeResolver();
    error MainChainVerifier__InvalidResponse();
    error MainChainVerifier__UnauthorizedRemoteVerifier();

    // Structs
    struct Value {
        uint256 value;
        bool exist;
    }

    // Events
    event StateVerified(
        uint256 indexed chainId,
        address indexed user,
        uint256 indexed key,
        uint256 blockNumber,
        uint256 value
    );
    event RemoteVerifierSet(uint256 indexed chainId, address verifier);

    function disputeResolver() external view returns (address);
    function abridge() external view returns (IAbridge);
    function remoteVerifiers(
        uint256 chainId
    ) external view returns (address);
    function isRemoteVerifier(
        address verifier
    ) external view returns (bool);

    // External functions
    function setRemoteVerifier(uint256 chainId, address verifier) external;
    function getVerifiedState(
        uint256 chainId,
        address user,
        uint256 key,
        uint256 blockNumber
    ) external view returns (uint256 value, bool exist);
}
