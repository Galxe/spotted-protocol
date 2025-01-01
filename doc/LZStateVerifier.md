# LZStateVerifier

| File | Type | Proxy |
| -------- | -------- | -------- |
| `LZStateVerifier.sol` | Implementation | - |

`LZStateVerifier` is a contract implementing the IBridgeVerifier interface, responsible for verifying cross-chain states through the LayerZero protocol.

Key Objectives:
- Verify cross-chain state proofs via LayerZero protocol
- Ensure authenticity and integrity of cross-chain messages
- Manage verification states and results

## High-level Concepts

1. State Verification
2. LayerZero Protocol Integration
3. Verification State Management

## Important Definitions

- _VerificationData_:
  - stateValue: The state value to be verified
  - isCompleted: Whether verification is completed
  - isVerified: Whether verification passed
  - blockNumber: Block number of verification
  - isCompleted: Completion status


## State Verification

Verifies state proofs from source chains through the LayerZero protocol.

Methods:
`verifyState`

```solidity
function verifyState(
    uint256 sourceChainId,
    uint256 blockNumber,
    bytes memory proof
) external payable returns (bytes32)
```

Verifies a state proof from the source chain and returns the verified state value.

Effects:
- Sends cross-chain message to source chain requesting state verification
- Creates new verification record
- Updates verification status
- Emits verification events

Requirements:
- Source chain must be supported
- Block number must be valid
- Proof data must be complete
- Sufficient verification fee must be paid

## Verification Status

Manages and tracks verification states.

Methods:
- `getVerificationStatus`
- `isVerified`

```solidity
function getVerificationStatus(bytes32 verificationId) 
    external view returns (VerificationData memory)
```

Returns verification status info for the specified verification ID.

Returns:
- Verification data struct containing status and results

Requirements:
- Verification ID must exist

Verification Flow:
1. Receive verification request (challenge) from `StateDisputeResolver`
2. Send cross-chain verification message via LayerZero
3. Receive and verify cross-chain response
4. Update verification status
5. Return verification result or revert on failure
