# BridgeVerifier

| File | Type | Proxy |
| -------- | -------- | -------- |
| `BridgeVerifier.sol` | Implementation | - |

`BridgeVerifier` is responsible for verifying cross-chain state proofs from different bridge protocols (e.g. LayerZero, CCIP). It acts as a bridge adapter that standardizes the verification interface for the CrossChainStateVerifier to validate state claims across different chains.

The primary goal of the `BridgeVerifier` is to provide a unified verification interface that:
- Verifies state proofs from specific bridge protocols
- Validates block headers and state roots
- Ensures cross-chain message authenticity

## High-level Concepts

1. State Proof Verification
2. Bridge Protocol Adaptation  
3. Chain Support Management

## Important Definitions

- _State Proof_: A proof structure containing:
  - blockHeader: Block header data from source chain
  - stateRoot: Merkle root of the state trie
  - proof: Merkle proof of the state value
  - bridgeProof: Bridge-specific proof data
  
- _Bridge Protocol_: The underlying cross-chain messaging protocol (e.g. LayerZero, CCIP) used to relay and verify state proofs

---
## State Verification
The verification process validates state proofs from source chains using the underlying bridge protocol's verification mechanisms.

Methods:
`verifyState`

```solidity
function verifyState(
    uint256 sourceChainId,
    uint256 blockNumber,
    bytes memory proof
) external view returns (bytes32)
```

Verifies a state proof from the source chain and returns the verified state value.

Effects:
- Validates the proof format and structure
- Verifies block header authenticity
- Checks state root inclusion
- Returns verified state value

Requirements:
- Source chain must be supported
- Block number must be finalized
- Proof must be valid and complete
- Bridge protocol must be operational

---
## Chain Support
The verifier maintains a list of supported source chains and their verification parameters.

Methods:
- `getSupportedChainId`
- `isSupportedChain` 
- `getChainConfig`

```solidity
function getSupportedChainId() external view returns (uint256)
```

Returns the chain ID that this verifier supports.

Requirements:
- Verifier must be initialized
- Chain configuration must exist

---
## Bridge Protocol Integration
The verifier integrates with specific bridge protocols to leverage their cross-chain messaging and verification capabilities.

Key Components:
1. Protocol Endpoints
   - Bridge contract addresses
   - Protocol-specific interfaces
   
2. Verification Logic
   - Proof format adaptation
   - Protocol-specific validation
   - Error handling

3. Security Considerations
   - Proof tampering prevention
   - Block finality requirements
   - Bridge protocol security assumptions

The verification flow:
1. Receiving state proof from CrossChainStateVerifier
2. Adapting proof format for bridge protocol
3. Verifying proof using protocol mechanisms
4. Validating state value authenticity
5. Returning verified state or reverting on failure

This enables secure cross-chain state verification while abstracting bridge protocol complexities.
