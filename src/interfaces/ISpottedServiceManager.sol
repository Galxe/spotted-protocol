// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ISignatureUtils} from "@eigenlayer/contracts/interfaces/ISignatureUtils.sol";

interface ISpottedServiceManager {
    // Custom errors
    error SpottedServiceManager__CallerNotDisputeResolver();
    error SpottedServiceManager__CallerNotStakeRegistry();
    error SpottedServiceManager__InvalidAddress();

    // Events
    event OperatorRegistered(address indexed operator);
    event OperatorDeregistered(address indexed operator);

    // Core functions
    function registerOperatorToAVS(
        address operator,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external;

    function deregisterOperatorFromAVS(
        address operator
    ) external;

    // View functions
    function generateTaskId(
        address user,
        uint32 chainId,
        uint64 blockNumber,
        uint256 key,
        uint256 value,
        uint256 timestamp
    ) external pure returns (bytes32);
}
