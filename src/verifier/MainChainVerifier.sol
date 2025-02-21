// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin-v5.0.0/contracts/access/Ownable.sol";
import {IAbridgeMessageHandler} from "../interfaces/IAbridge.sol";
import {IAbridge} from "../interfaces/IAbridge.sol";
import "../interfaces/IMainChainVerifier.sol";

/// @title Main Chain Verifier
/// @author Spotted Team
/// @notice Verifier for main chain that receives and processes verification results from remote chains
/// @dev Implements cross-chain verification result handling and state management
contract MainChainVerifier is Ownable, IMainChainVerifier {
    /// @notice Stores verified states from remote chains
    /// @dev Maps chainId -> user -> key -> blockNumber -> Value
    mapping(uint256 => mapping(address => mapping(uint256 => mapping(uint256 => Value)))) private
        verifiedStates;

    /// @notice Reference to the bridge contract
    /// @dev Immutable after deployment
    IAbridge public immutable abridge;

    /// @notice Maps chain IDs to their verifier addresses
    /// @dev Used to track authorized verifiers per chain
    mapping(uint256 => address) public remoteVerifiers;

    /// @notice Tracks whether an address is an authorized remote verifier
    /// @dev Quick lookup for verifier authorization
    mapping(address => bool) public isRemoteVerifier;

    /// @notice Ensures only the bridge contract can call certain functions
    /// @dev Reverts if caller is not the bridge
    modifier onlyAbridge() {
        if (msg.sender != address(abridge)) {
            revert MainChainVerifier__OnlyAbridge();
        }
        _;
    }

    /// @notice Initializes the verifier with bridge and owner addresses
    /// @param _abridge Address of the bridge contract
    /// @param _owner Address of the contract owner
    /// @dev Sets immutable bridge reference and initializes ownership
    constructor(address _abridge, address _owner) Ownable(_owner) {
        if (_abridge == address(0)) {
            revert MainChainVerifier__InvalidResponse();
        }
        abridge = IAbridge(_abridge);
    }

    /// @notice Configures verifier address for a specific chain
    /// @param chainId ID of the chain to configure
    /// @param verifier Address of the verifier for the chain
    /// @dev Updates routing permissions and emits event
    function setRemoteVerifier(uint256 chainId, address verifier) external onlyOwner {
        address oldVerifier = remoteVerifiers[chainId];
        if (oldVerifier != address(0)) {
            isRemoteVerifier[oldVerifier] = false;
            abridge.updateRoute(oldVerifier, false);
        }

        remoteVerifiers[chainId] = verifier;
        isRemoteVerifier[verifier] = true;
        abridge.updateRoute(verifier, true);

        emit RemoteVerifierSet(chainId, verifier);
    }

    /// @notice Processes verification results from remote chains
    /// @param from Address of the sender
    /// @param message Encoded verification data
    /// *guid*: Message identifier (unused)
    /// @return bytes4 Function selector indicating successful handling
    /// @dev Only callable by bridge, verifies sender authorization
    function handleMessage(
        address from,
        bytes calldata message,
        bytes32 /* guid */
    ) external override onlyAbridge returns (bytes4) {
        if (!isRemoteVerifier[from]) {
            revert MainChainVerifier__UnauthorizedRemoteVerifier();
        }

        (uint256 chainId, address user, uint256 key, uint256 blockNumber, uint256 value, bool exist)
        = abi.decode(message, (uint256, address, uint256, uint256, uint256, bool));

        verifiedStates[chainId][user][key][blockNumber] = Value({value: value, exist: exist});

        emit StateVerified(chainId, user, key, blockNumber, value);
        return IAbridgeMessageHandler.handleMessage.selector;
    }

    /// @notice Retrieves verified state from storage
    /// @param chainId ID of the chain to query
    /// @param user Address of the user
    /// @param key Key of the state
    /// @param blockNumber Block number of the state
    /// @return value The verified value
    /// @return exist Whether the value exists
    function getVerifiedState(
        uint256 chainId,
        address user,
        uint256 key,
        uint256 blockNumber
    ) external view returns (uint256 value, bool exist) {
        Value memory info = verifiedStates[chainId][user][key][blockNumber];
        return (info.value, info.exist);
    }
}
