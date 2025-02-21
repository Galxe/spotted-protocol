// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IRegistryStateSender} from "../../src/interfaces/IRegistryStateSender.sol";

contract MockRegistryStateSender is IRegistryStateSender {
    address public immutable epochManager = address(1);

    function getBridgeInfoByChainId(
        uint256 /*chainId*/
    ) external pure returns (BridgeInfo memory) {
        return BridgeInfo(address(1), address(1));
    }

    function supportedChainIds(
        uint256 /*index*/
    ) external pure returns (uint256) {
        return 1;
    }

    function addBridge(
        uint256 _chainId,
        address _bridge,
        address _receiver
    ) external {
        emit BridgeModified(_chainId, _bridge, _receiver);
    }

    function removeBridge(
        uint256 _chainId
    ) external {}

    function modifyBridge(
        uint256 _chainId,
        address _newBridge,
        address _newReceiver
    ) external {
        emit BridgeModified(_chainId, _newBridge, _newReceiver);
    }

    function sendState(
        uint256 epoch,
        uint256 chainId,
        bytes memory /*data*/
    ) external payable {
        if (msg.value == 0) {
            revert RegistryStateSender__InsufficientFee();
        }
        emit StateSent(epoch, chainId);
    }
}
