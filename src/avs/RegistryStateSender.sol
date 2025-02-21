// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IRegistryStateSender} from "../interfaces/IRegistryStateSender.sol";
import {IAbridge} from "../interfaces/IAbridge.sol";
import {Ownable} from "@openzeppelin-v5.0.0/contracts/access/Ownable.sol";
import {IEpochManager} from "../interfaces/IEpochManager.sol";

/// @title Registry State Sender
/// @author Spotted Team
/// @notice Manages cross-chain state synchronization for the stake registry
/// @dev Handles sending state updates to other chains through bridges
contract RegistryStateSender is IRegistryStateSender, Ownable {
    /// @notice Address of the epoch manager contract
    /// @dev Immutable after deployment
    address public immutable epochManager;

    /// @notice Mapping of chain IDs to their bridge configurations
    /// @dev Contains bridge address and receiver address for each supported chain
    mapping(uint256 => BridgeInfo) public chainToBridgeInfo;

    /// @notice List of all supported chain IDs
    /// @dev Used to track and iterate over supported chains
    uint256[] public supportedChainIds;

    /// @notice Gas limit for cross-chain message execution
    /// @dev Fixed value to ensure consistent gas costs
    uint128 public constant EXECUTE_GAS_LIMIT = 500_000;

    /// @notice Ensures only the epoch manager can call certain functions
    /// @dev Reverts if caller is not the epoch manager
    modifier onlyEpochManager() {
        if (msg.sender != address(epochManager)) revert RegistryStateSender__InvalidSender();
        _;
    }

    /// @notice Initializes the contract with bridge configurations
    /// @param _chainIds Array of chain IDs to support
    /// @param _bridges Array of bridge contract addresses for each chain
    /// @param _receivers Array of receiver contract addresses for each chain
    /// @param _owner Address of the contract owner
    /// @param _epochManager Address of the epoch manager contract
    /// @dev Arrays must be of equal length
    constructor(
        uint256[] memory _chainIds,
        address[] memory _bridges,
        address[] memory _receivers,
        address _owner,
        address _epochManager
    ) Ownable(_owner) {
        epochManager = _epochManager;
        if (_chainIds.length != _bridges.length || _bridges.length != _receivers.length) {
            revert RegistryStateSender__InvalidBridgeInfo();
        }

        for (uint256 i = 0; i < _chainIds.length; i++) {
            _addBridge(_chainIds[i], _bridges[i], _receivers[i]);
        }
    }

    /// @notice Adds a new bridge configuration for a chain
    /// @param _chainId The ID of the chain to add
    /// @param _bridge The address of the bridge contract
    /// @param _receiver The address of the receiver contract
    /// @dev Only callable by owner
    function addBridge(uint256 _chainId, address _bridge, address _receiver) external onlyOwner {
        _addBridge(_chainId, _bridge, _receiver);
    }

    /// @notice Removes a bridge configuration for a chain
    /// @param _chainId The ID of the chain to remove
    /// @dev Only callable by owner
    function removeBridge(
        uint256 _chainId
    ) external onlyOwner {
        if (chainToBridgeInfo[_chainId].bridge == address(0)) {
            revert RegistryStateSender__ChainNotSupported();
        }

        delete chainToBridgeInfo[_chainId];

        for (uint256 i = 0; i < supportedChainIds.length; i++) {
            if (supportedChainIds[i] == _chainId) {
                supportedChainIds[i] = supportedChainIds[supportedChainIds.length - 1];
                supportedChainIds.pop();
                break;
            }
        }
    }

    /// @notice Internal function to add a bridge configuration
    /// @param _chainId The ID of the chain to add
    /// @param _bridge The address of the bridge contract
    /// @param _receiver The address of the receiver contract
    /// @dev Validates addresses and prevents duplicate bridges
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

    /// @notice directly send state to target chain
    /// @param epoch current epoch number
    /// @param chainId target chain ID
    /// @param data encoded state data
    function sendState(
        uint256 epoch,
        uint256 chainId,
        bytes memory data
    ) external payable onlyEpochManager {
        BridgeInfo memory bridgeInfo = chainToBridgeInfo[chainId];
        if (bridgeInfo.bridge == address(0)) {
            revert RegistryStateSender__ChainNotSupported();
        }

        (, uint256 fee) = IAbridge(bridgeInfo.bridge).estimateFee(
            bridgeInfo.receiver, 
            EXECUTE_GAS_LIMIT, 
            data
        );

        if (msg.value < fee) {
            revert RegistryStateSender__InsufficientFee();
        }

        IAbridge(bridgeInfo.bridge).send{value: fee}(
            bridgeInfo.receiver, 
            EXECUTE_GAS_LIMIT, 
            data
        );

        emit StateSent(epoch, chainId);
    }

    /// @notice Modifies an existing bridge configuration
    /// @param _chainId The ID of the chain to modify
    /// @param _newBridge The new bridge contract address
    /// @param _newReceiver The new receiver contract address
    /// @dev Only callable by owner
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

    /// @notice Gets bridge configuration for a chain
    /// @param chainId The ID of the chain to query
    /// @return Bridge configuration information
    function getBridgeInfoByChainId(
        uint256 chainId
    ) external view returns (BridgeInfo memory) {
        return chainToBridgeInfo[chainId];
    }
}
