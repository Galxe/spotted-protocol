// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ISpottedOracleUser {
    // Called when state proof is fulfilled
    function onStateProofReceived(
        bytes32 requestId,
        uint256 value,
        uint64 blockNumber,
        uint32 timestamp,
        uint32 nonce,
        uint8 stateType
    ) external;
}
