// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IAbridge} from "../interfaces/IAbridge.sol";
import "../interfaces/IStateManager.sol";

interface IRemoteChainVerifier {
    // Errors
    error RemoteChainVerifier__InvalidResponse();
    error RemoteChainVerifier__StateManagerNotSet();
    error RemoteChainVerifier__InvalidMainChainId();
    error RemoteChainVerifier__StateNotFound();
    error RemoteChainVerifier__InsufficientFee();
    error RemoteChainVerifier__WithdrawFailed();
    // Events

    event StateManagerUpdated(address indexed newStateManager);
    event VerificationProcessed(
        address indexed user, uint256 indexed key, uint256 blockNumber, uint256 value
    );
    event FundsWithdrawn(address indexed to, uint256 amount);

    // View functions
    function abridge() external view returns (IAbridge);
    function stateManager() external view returns (IStateManager);
    function mainChainId() external view returns (uint256);
    function mainChainVerifier() external view returns (address);

    // External functions
    function verifyState(address user, uint256 key, uint256 blockNumber) external payable;
    function withdraw(
        address to
    ) external;
}
