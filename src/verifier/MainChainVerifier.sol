// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable2Step, Ownable} from "@openzeppelin-v5.0.0/contracts/access/Ownable2Step.sol";
import {IAbridgeMessageHandler} from "../interfaces/IAbridge.sol";
import {IAbridge} from "../interfaces/IAbridge.sol";
import "../interfaces/IStateManager.sol";
import "../interfaces/IMainChainVerifier.sol";

// verifier for main chain that receives and processes verification results from remote chains
contract MainChainVerifier is Ownable2Step, IMainChainVerifier {
    // stores verified states from remote chains
    mapping(uint256 => mapping(address => mapping(uint256 => mapping(uint256 => Value)))) private
        verifiedStates; // chainId -> user -> key -> blockNumber -> Value

    // core contract references
    address public immutable disputeResolver;
    IAbridge public immutable abridge;

    // remote verifier configuration
    mapping(uint256 => address) public remoteVerifiers; // chainId -> verifier address
    mapping(address => bool) public isRemoteVerifier; // verifier address -> is authorized

    modifier onlyAbridge() {
        if (msg.sender != address(abridge)) {
            revert MainChainVerifier__OnlyAbridge();
        }
        _;
    }

    modifier onlyDisputeResolver() {
        if (msg.sender != disputeResolver) {
            revert MainChainVerifier__OnlyDisputeResolver();
        }
        _;
    }

    constructor(address _abridge, address _disputeResolver, address _owner) Ownable(_owner) {
        if (_abridge == address(0) || _disputeResolver == address(0)) {
            revert MainChainVerifier__InvalidResponse();
        }
        abridge = IAbridge(_abridge);
        disputeResolver = _disputeResolver;
    }

    // configures verifier address for a specific chain
    function setRemoteVerifier(uint256 chainId, address verifier) external onlyOwner {
        // revoke permissions from old verifier if exists
        address oldVerifier = remoteVerifiers[chainId];
        if (oldVerifier != address(0)) {
            isRemoteVerifier[oldVerifier] = false;
            abridge.updateRoute(oldVerifier, false);
        }

        remoteVerifiers[chainId] = verifier;
        isRemoteVerifier[verifier] = true;
        // grant permissions to new verifier
        abridge.updateRoute(verifier, true);

        emit RemoteVerifierSet(chainId, verifier);
    }

    // processes verification results from remote chains
    function handleMessage(
        address from,
        bytes calldata message,
        bytes32 guid
    ) external override onlyAbridge returns (bytes4) {
        if (!isRemoteVerifier[from]) {
            revert MainChainVerifier__UnauthorizedRemoteVerifier();
        }

        (uint256 chainId, address user, uint256 key, uint256 blockNumber, uint256 value, bool exist)
        = abi.decode(message, (uint256, address, uint256, uint256, uint256, bool));

        // store verification result
        verifiedStates[chainId][user][key][blockNumber] = Value({value: value, exist: exist});

        emit StateVerified(chainId, user, key, blockNumber, value);
        return IAbridgeMessageHandler.handleMessage.selector;
    }

    // retrieves verified state from storage
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
