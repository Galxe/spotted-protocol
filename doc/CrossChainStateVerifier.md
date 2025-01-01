# CrossChainStateVerifier

| File | Type | Proxy |
| -------- | -------- | -------- |
| `CrossChainStateVerifier.sol` | Singleton | UUPS proxy |

`CrossChainStateVerifier` is responsible for verifying cross-chain state claims and managing operator challenges. It enables secure state verification across different chains through:
- Bridge-specific state verification
- Challenge-based dispute resolution
- Operator slashing mechanism

The primary goals of the `CrossChainStateVerifier` are:
- Verify state claims across different chains
- Enable secure challenge resolution
- Manage operator penalties
- Coordinate with bridge verifiers

## High-level Concepts

1. State Verification
2. Challenge Management
3. Operator Slashing

## Important Definitions

- _Challenge_: A struct containing:
  - challenger: Address that submitted the challenge
  - deadline: Block number when challenge expires
  - resolved: Whether challenge has been resolved
  - claimedState: State claimed by operator
  - actualState: Actual state verified on source chain
- _OperatorState_: A struct containing:
  - isRegistered: Whether operator is registered
  - isSlashed: Whether operator has been slashed
  - stake: Amount staked by operator
- _Challenge Bond_: Amount of ETH required to submit a challenge
- _Challenge Period_: Number of blocks to wait before resolving challenge

## Challenge Submission 
The challenge submission process allows anyone to dispute operator state claims.

Methods:
`submitChallenge`

```solidity
function submitChallenge(
    uint256 chainId,
    uint256 blockNumber,
    bytes32 claimedState,
    bytes memory proof,
    address operator
) external payable
```

Submits a challenge against an operator's state claim with required bond.

Effects:
- Creates new challenge entry
- Verifies state through bridge verifier
- Stores actual state for comparison
- Emits ChallengeSubmitted event

Requirements:
- Sufficient challenge bond
- Operator must be registered
- No existing challenge for same parameters
- Valid bridge verifier configured

## Challenge Resolution 
The resolution process determines challenge outcome and handles penalties.

Methods:
`resolveChallenge`

```solidity
function resolveChallenge(
    bytes32 challengeId
) external
```

Resolves a challenge after challenge period expires.

Effects:
- Determines challenge outcome
- Slashes operator if challenge successful
- Distributes challenge bond
- Marks challenge as resolved
- Emits ChallengeResolved event

Requirements:
- Challenge must exist
- Challenge period must be over
- Challenge not already resolved

## Configuration 
Administrative functions for managing verifier settings.

Methods:
- `setVerifier`
- `setOperatorSetId`
- `setSlashableStrategies`
- `setSlashAmount`

```solidity
function setVerifier(
    uint256 chainId,
    address verifier
) external onlyOwner
```

Configures bridge verifier for specific chain.

Effects:
- Updates bridge verifier mapping
- Emits VerifierSet event

Requirements:
- Only owner can call
- Valid verifier address
