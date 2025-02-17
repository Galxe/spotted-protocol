// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IRegistryStateSender} from "../../src/interfaces/IRegistryStateSender.sol";
import {IEpochManager} from "../../src/interfaces/IEpochManager.sol";

contract MockRegistryStateSender is IRegistryStateSender {
    // Events for testing
    event BatchUpdatesSent(uint256 epoch, uint256 chainId, IEpochManager.StateUpdate[] updates);

    function getBridgeInfoByChainId(
        uint256 /*chainId*/
    ) external pure returns (BridgeInfo memory) {
        return BridgeInfo(address(1), address(1));
    }

    function supportedChainIds(uint256 /*index*/) external pure returns (uint256) {
        return 1;
    }

    function addBridge(uint256 _chainId, address _bridge, address _receiver) external {}

    function removeBridge(uint256 _chainId) external {}

    function modifyBridge(uint256 _chainId, address _newBridge, address _newReceiver) external {}

    function sendBatchUpdates(
        uint256 epoch,
        uint256 chainId,
        IEpochManager.StateUpdate[] memory updates
    ) external payable {
        emit BatchUpdatesSent(epoch, chainId, updates);
    }
}