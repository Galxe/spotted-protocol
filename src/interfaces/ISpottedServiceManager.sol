// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ISignatureUtils} from "@eigenlayer/contracts/interfaces/ISignatureUtils.sol";

interface ISpottedServiceManager {

    function registerOperatorToAVS(
        address operator,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external;

    function deregisterOperatorFromAVS(
        address operator
    ) external;

    function generateTaskId(
        address user,
        uint32 chainId,
        uint64 blockNumber,
        uint48 timestamp,
        uint32 epoch,
        uint256 key,
        uint256 value
    ) external pure returns (bytes32);
}
