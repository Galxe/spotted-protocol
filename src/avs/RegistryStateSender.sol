// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IRegistryStateSender} from "../interfaces/IRegistryStateSender.sol";
import {IAbridge} from "../interfaces/IAbridge.sol";
import {Ownable} from "@openzeppelin-v5.0.0/contracts/access/Ownable.sol";
import {IEpochManager} from "../interfaces/IEpochManager.sol";

contract RegistryStateSender is IRegistryStateSender, Ownable {
    // immutable variables
    address public immutable stakeRegistry;
    mapping(uint256 => BridgeInfo) public chainToBridgeInfo;
    uint256[] public supportedChainIds;

    // gas limit for cross-chain execution
    uint128 public constant EXECUTE_GAS_LIMIT = 500_000;

    // ensure caller is stake registry
    modifier onlyStakeRegistry() {
        if (msg.sender != address(stakeRegistry)) revert RegistryStateSender__InvalidSender();
        _;
    }

    // initialize contract with bridge configurations
    constructor(
        uint256[] memory _chainIds,
        address[] memory _bridges,
        address[] memory _receivers,
        address _owner,
        address _stakeRegistry
    ) Ownable(_owner) {
        stakeRegistry = _stakeRegistry;
        if (_chainIds.length != _bridges.length || _bridges.length != _receivers.length) {
            revert RegistryStateSender__InvalidBridgeInfo();
        }

        for (uint256 i = 0; i < _chainIds.length; i++) {
            _addBridge(_chainIds[i], _bridges[i], _receivers[i]);
        }
    }

    // add new bridge for a chain
    function addBridge(uint256 _chainId, address _bridge, address _receiver) external onlyOwner {
        _addBridge(_chainId, _bridge, _receiver);
    }

    // remove bridge for a chain
    function removeBridge(
        uint256 _chainId
    ) external onlyOwner {
        if (chainToBridgeInfo[_chainId].bridge == address(0)) {
            revert RegistryStateSender__ChainNotSupported();
        }

        delete chainToBridgeInfo[_chainId];

        // remove chain from supported list
        for (uint256 i = 0; i < supportedChainIds.length; i++) {
            if (supportedChainIds[i] == _chainId) {
                supportedChainIds[i] = supportedChainIds[supportedChainIds.length - 1];
                supportedChainIds.pop();
                break;
            }
        }
    }

    // internal function to add bridge
    function _addBridge(uint256 _chainId, address _bridge, address _receiver) internal {
        if (_bridge == address(0) || _receiver == address(0)) {
            revert RegistryStateSender__InvalidBridgeInfo();
        }
        if (chainToBridgeInfo[_chainId].bridge != address(0)) {
            revert RegistryStateSender__BridgeAlreadyExists();
        }

        chainToBridgeInfo[_chainId] = BridgeInfo({bridge: _bridge, receiver: _receiver});
        supportedChainIds.push(_chainId);
    }

    // send batch updates to target chain
    function sendBatchUpdates(
        uint256 epoch,
        uint256 chainId,
        IEpochManager.StateUpdate[] memory updates
    ) external payable onlyStakeRegistry {
        BridgeInfo memory bridgeInfo = chainToBridgeInfo[chainId];
        if (bridgeInfo.bridge == address(0)) revert RegistryStateSender__ChainNotSupported();

        bytes memory data = abi.encode(epoch, updates);

        // estimate required fee
        (, uint256 fee) =
            IAbridge(bridgeInfo.bridge).estimateFee(bridgeInfo.receiver, EXECUTE_GAS_LIMIT, data);

        if (msg.value < fee) revert RegistryStateSender__InsufficientFee();

        // send cross-chain message
        IAbridge(bridgeInfo.bridge).send{value: fee}(bridgeInfo.receiver, EXECUTE_GAS_LIMIT, data);
    }

    // modify existing bridge configuration
    function modifyBridge(
        uint256 _chainId,
        address _newBridge,
        address _newReceiver
    ) external onlyOwner {
        if (chainToBridgeInfo[_chainId].bridge == address(0)) {
            revert RegistryStateSender__ChainNotSupported();
        }
        if (_newBridge == address(0) || _newReceiver == address(0)) {
            revert RegistryStateSender__InvalidBridgeInfo();
        }

        chainToBridgeInfo[_chainId] = BridgeInfo({bridge: _newBridge, receiver: _newReceiver});

        emit BridgeModified(_chainId, _newBridge, _newReceiver);
    }

    // get bridge info for a chain
    function getBridgeInfoByChainId(
        uint256 chainId
    ) external view returns (BridgeInfo memory) {
        return chainToBridgeInfo[chainId];
    }
}
