// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable2Step, Ownable} from "@openzeppelin-v5.0.0/contracts/access/Ownable2Step.sol";
import {IAbridgeMessageHandler} from "../interfaces/IAbridge.sol";
import {IAbridge} from "../interfaces/IAbridge.sol";
import "../interfaces/IStateManager.sol";
import "../interfaces/IRemoteChainVerifier.sol";

contract RemoteChainVerifier is IRemoteChainVerifier, Ownable2Step {
    uint128 private constant EXECUTE_GAS_LIMIT = 500_000;
    IAbridge public immutable abridge;
    IStateManager public stateManager;
    uint256 public immutable mainChainId;
    address public immutable mainChainVerifier;

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

    // verify state on remote chain and return the state to main chain verifier
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

    // withdraw funds from this contract (unused fee from abridge)
    function withdraw(
        address to
    ) external onlyOwner {
        if (to == address(0)) revert RemoteChainVerifier__InvalidResponse();

        uint256 amount = address(this).balance;

        (bool success,) = to.call{value: amount}("");
        if (!success) revert RemoteChainVerifier__WithdrawFailed();

        emit FundsWithdrawn(to, amount);
    }

    receive() external payable {}
}
