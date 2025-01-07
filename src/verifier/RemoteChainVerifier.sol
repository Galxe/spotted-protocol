// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable2Step, Ownable} from "@openzeppelin-v5.0.0/contracts/access/Ownable2Step.sol";
import {IAbridgeMessageHandler} from "../interfaces/IAbridge.sol";
import {IAbridge} from "../interfaces/IAbridge.sol";
import "../interfaces/IStateManager.sol";
import "../interfaces/IRemoteChainVerifier.sol";

/// @title Remote Chain Verifier
/// @author Spotted Team
/// @notice Verifies state on remote chains and sends results back to main chain
/// @dev Implements cross-chain state verification and message handling
contract RemoteChainVerifier is IRemoteChainVerifier, Ownable2Step {
    /// @notice Gas limit for cross-chain message execution
    /// @dev Fixed value to ensure consistent gas costs
    uint128 private constant EXECUTE_GAS_LIMIT = 500_000;

    /// @notice Reference to the bridge contract
    /// @dev Immutable after deployment
    IAbridge public immutable abridge;

    /// @notice Reference to the state manager contract
    /// @dev Can be updated by owner
    IStateManager public stateManager;

    /// @notice ID of the main chain where verification results are sent
    /// @dev Immutable after deployment
    uint256 public immutable mainChainId;

    /// @notice Address of the verifier contract on the main chain
    /// @dev Immutable after deployment
    address public immutable mainChainVerifier;

    /// @notice Initializes the verifier with required contract references
    /// @param _abridge Address of the bridge contract
    /// @param _stateManager Address of the state manager contract
    /// @param _mainChainId ID of the main chain
    /// @param _mainChainVerifier Address of the main chain verifier
    /// @param _owner Address of the contract owner
    /// @dev Sets immutable values and initializes ownership
    constructor(
        address _abridge,
        address _stateManager,
        uint256 _mainChainId,
        address _mainChainVerifier,
        address _owner
    ) Ownable(_owner) {
        if (_abridge == address(0)) revert RemoteChainVerifier__InvalidResponse();
        if (_mainChainId == 0) revert RemoteChainVerifier__InvalidMainChainId();
        if (_mainChainVerifier == address(0)) revert RemoteChainVerifier__InvalidResponse();

        abridge = IAbridge(_abridge);
        if (_stateManager != address(0)) {
            stateManager = IStateManager(_stateManager);
        }
        mainChainId = _mainChainId;
        mainChainVerifier = _mainChainVerifier;
    }

    /// @notice Verifies state on remote chain and sends result to main chain
    /// @param user Address of the user whose state is being verified
    /// @param key Key of the state to verify
    /// @param blockNumber Block number at which to verify the state
    /// @dev Requires payment for cross-chain message fees
    function verifyState(address user, uint256 key, uint256 blockNumber) external payable {
        if (address(stateManager) == address(0)) {
            revert RemoteChainVerifier__StateManagerNotSet();
        }

        try stateManager.getHistoryAtBlock(user, key, blockNumber) returns (
            IStateManager.History memory history
        ) {
            bytes memory response =
                abi.encode(mainChainId, user, key, blockNumber, history.value, true);

            (, uint256 fee) = abridge.estimateFee(mainChainVerifier, EXECUTE_GAS_LIMIT, response);
            if (msg.value < fee) revert RemoteChainVerifier__InsufficientFee();

            abridge.send{value: msg.value}(mainChainVerifier, EXECUTE_GAS_LIMIT, response);

            emit VerificationProcessed(user, key, blockNumber, history.value);
        } catch {
            revert RemoteChainVerifier__StateNotFound();
        }
    }
}
