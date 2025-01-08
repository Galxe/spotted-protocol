// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {IEpochManager} from "../interfaces/IEpochManager.sol";

interface IRegistryStateSender {
    struct BridgeInfo {
        address bridge;
        address receiver;
    }

    // Errors
    error RegistryStateSender__InsufficientFee();
    error RegistryStateSender__InvalidBridgeInfo();
    error RegistryStateSender__BridgeAlreadyExists();
    error RegistryStateSender__ChainNotSupported();
    error RegistryStateSender__InvalidSender();

    // Events
    event BridgeModified(uint256 indexed chainId, address newBridge, address newReceiver);

    function getBridgeInfoByChainId(
        uint256 chainId
    ) external view returns (BridgeInfo memory);
    function supportedChainIds(
        uint256 index
    ) external view returns (uint256);

    function addBridge(uint256 _chainId, address _bridge, address _receiver) external;

    function removeBridge(
        uint256 _chainId
    ) external;

    function modifyBridge(uint256 _chainId, address _newBridge, address _newReceiver) external;

    function sendBatchUpdates(
        uint256 epoch,
        uint256 chainId,
        IEpochManager.StateUpdate[] memory updates
    ) external payable;
}
