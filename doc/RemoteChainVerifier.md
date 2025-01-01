# RemoteChainVerifier

| File | Type | Proxy |
| -------- | -------- | -------- |
| `RemoteChainVerifier.sol` | Singleton(on supported chains) | No proxy |

`RemoteChainVerifier` is responsible for verifying states on remote chains and sending results back to the main chain verifier through Abridge. It handles state verification requests and manages bridge fee payments.

## High-level Concepts

1. Remote state verification
2. Cross-chain result transmission
3. State manager integration

## Important Definitions

- _Constants_:
```solidity
uint128 private constant EXECUTE_GAS_LIMIT = 500_000;  // Gas limit for bridge messages
```

- _State Variables_:
```solidity
IAbridge public immutable abridge;              // Bridge interface
IStateManager public stateManager;              // State manager interface
uint256 public immutable mainChainId;           // Main chain identifier
address public immutable mainChainVerifier;     // Main chain verifier address
```

## Access Control

The contract implements ownership-based access control:
- _Owner_: Can withdraw returned bridge fees
- _Anyone_: Can request state verification with sufficient fee

## Core Functions

### State Verification
```solidity
function verifyState(
    address user,
    uint256 key,
    uint256 blockNumber
) external payable
```

Verifies state on remote chain and sends result to main chain.

Effects:
- Queries state from state manager
- Encodes verification result
- Sends result through bridge
- Emits VerificationProcessed event

Requirements:
- State manager must be set
- Sufficient ETH provided for bridge fee
- State must exist at specified block

### Fee Management

#### withdraw
```solidity
function withdraw(address to) external onlyOwner
```

Withdraws returned bridge fees.

Requirements:
- Only owner can call
- Valid recipient address

## Integration with External Systems

The contract integrates with:
- State manager for local state queries
- Abridge for cross-chain message passing
- Main chain verifier for result reception

Key interactions:
- Queries local state history
- Estimates and pays bridge fees
- Transmits verification results to main chain
