# Spotted: Next-Generation Cross-Chain State Oracle

Spotted is an innovative AVS (Actively Validated Service) built on EigenLayer that revolutionizes cross-chain state verification. By leveraging EigenLayer's security infrastructure and implementing novel optimization techniques, it provides a cost-saving, efficient, and decentralized solution for state verification across blockchain networks.

## Core Innovations

### Cryptographic State Proof System
- Pure cryptographic approach without relying on message passing
- Eliminates expensive cross-chain message fees (up to 85% cost reduction vs LayerZero/CCIP)
- Optimistic verification with challenge-based security
- Decentralized verification through operator quorums

| Feature | Traditional Bridge (e.g. LayerZero/CCIP) | Spotted's Cryptographic Proof |
|---------|-------------------------------------|------------------------------|
| Verification Method | Message Passing | Signature-based Verification |
| Gas Cost | 300,000 - 400,000 + extra fee (e.g. network fee) | 50,000 - 140,000 (based on operators number) + $0 extra fee|
| Latency | Minutes (depending on chain's block confirmation number) | Instant |
| Security Asset Pool | Isolated staking pool | Possibly leverages entire EigenLayer ecosystem stake ($10+ billion)  |

### Advanced Task Distribution System
- Intelligent off-chain task generation with dynamic operator assignment
- Parallel processing architecture for minimal latency
- Advanced batching strategies for gas optimization
- Real-time operator coordination and load balancing

### High-Performance ECDSA Verification
- Optimized ECDSA signature scheme implementation
- Up to 70% gas savings compared to traditional BLS solutions
- Universal proof verification across any EVM chain:
  
```solidity
struct StateProof {
  uint32 chainId;      // Target chain identifier
  address user;        // State owner address
  uint256 key;        // State identifier
  uint256 value;      // State value
  uint64 blockNumber; // Block height
  uint48 timestamp;   // Block timestamp
  uint32 epochNumber; // Epoch number
}
```

### Verification Infrastructure
- Multi-chain stake registry deployment
- EIP1271-compliant signature verification system
- Reliable challenge-response dispute resolution
- Seamless bridge protocol integration
- Real-time state synchronization

### Technical Advantages
- Minimal gas overhead through optimized proof generation and validation
- Fast-path optimistic verification with strong fallback guarantees
- Multi-layered security through EigenLayer's economic mechanisms
- Horizontal scalability across multiple chains

## System Architecture

### Core Service Layer

1. **Service Management Hub**
```
AVS (SpottedServiceManager)
├── ECDSAServiceManagerBase
└── AVSDirectory （EigenLayer's core contract）
```

2. **Registry Infrastructure**
```
Registry System
├── ECDSAStakeRegistry (Operator & Stake Management)
│   ├── Operator Registration
│   ├── Weight Management
│   └── ECDSA Signature Verification
├── LightStakeRegistry (Cross-chain State Sync)
│   ├── Operator State Updates
│   └── Signature Validation
└── EpochManager (Epoch & State Management)
    ├── Epoch Transitions
    ├── Grace Periods
    └── State Synchronization
```

3. **State Management System**
```
State System
├── StateManager (State History)
│   ├── Value Storage
│   ├── History Tracking
│   └── Binary Search
└── StateDisputeResolver (Dispute Handling)
    ├── Challenge Submission
    ├── Verification
    └── Slashing
```

4. **Cross-Chain Verification**
```
Verification System
├── MainChainVerifier (Mainnet)
│   ├── State Reception
│   ├── Verifier Management
│   └── State Storage
├── RemoteChainVerifier (Support Chains)
│   ├── State Verification
│   ├── Result Transmission
│   └── Fee Management
└── Abridge (Message Layer)
    ├── Message Routing
    ├── Fee Handling
    └── State Sync
```

5. **Registry State Sync**
```
State Sync System
├── RegistryStateSender (Mainnet)
│   ├── State Updates
│   └── Bridge Integration
└── RegistryStateReceiver (Support Chains)
    ├── State Reception
    └── Registry Updates
```

### Security Architecture

1. **EigenLayer Integration**
- Leverages restaking for enhanced economic security
- Sophisticated slashing mechanisms
- Dynamic stake requirements

2. **Challenge Mechanism**
- Real-time state verification
- Economic incentives for challengers
- Automated slashing execution


## Roles

- **Staker**: delegate/undelegate through EigenLayer core contracts
- **Operator**: register/unregister through RegistryCoordinator
- **Task Generator**: generate tasks off chain directly to operators
- **Bridge Abstraction Layer**: send/receive messages using Abridge, useful for state verification and operator state synchronization
- **Bridge Verifier**: verify state proofs (only when challenged) from bridge protocols

## Workflows

Workflows are defined in the [Workflows.md](./doc/Workflows.md) file.

## Contracts

### [StateManager.sol](./doc/StateManager.md)

`StateManager` is responsible for managing state transitions and history for users. Users can set arbitrary key-value pairs states in the contract with comprehensive history tracking and querying capabilities. Then, the state can be queried to generate proof by AVS.

### [ECDSAServiceManagerBase.sol](./doc/ECDSAServiceManagerBase.md)

`ECDSAServiceManagerBase` is an abstract base contract that provides core infrastructure provided by EigenLayer for the AVS. It manages operator registration, stake tracking, and rewards distribution for ECDSA-based services.

### [SpottedServiceManager.sol](./doc/SpottedServiceManager.md)

`SpottedServiceManager` is an Active Validator Set (AVS) service manager that enables cross-chain state verification through a quorum of operators. It inherits from `ECDSAServiceManagerBase` and implements additional functionality for state verification and dispute resolution.

### [ECDSAStakeRegistry.sol](./doc/ECDSAStakeRegistry.md)

`ECDSAStakeRegistry` manages operator registration, stake weights, and ECDSA signature verification for AVS. It maintains historical records of operator weights and signing keys while enforcing quorum rules for signature validation. It uses `EpochCheckpointsUpgradeable` to store historical records separately for each epoch.

### [LightStakeRegistry.sol](./doc/LightStakeRegistry.md)

`LightStakeRegistry` is a lightweight cross-chain state synchronization contract that receives and processes state updates from the main chain's `EpochManager`. It primarily serves to validate operator signatures on sidechains by maintaining operator states (weights, signing keys, etc.) for each epoch.

### [EpochManager.sol](./doc/EpochManager.md)

`EpochManager` manages epoch transitions and state updates for the AVS system. It handles epoch advancement, grace periods, and state synchronization across chains.

### [RegistryStateSender.sol](./doc/RegistryStateSender.md)

`RegistryStateSender` manages cross-chain state synchronization for the stake registry. It handles sending state updates to other chains through bridges, enabling multi-chain operator set management.

### [RegistryStateReceiver.sol](./doc/RegistryStateReceiver.md)

`RegistryStateReceiver` is responsible for receiving and processing operator state updates from the mainnet through Abridge. It maintains the synchronized operator state by forwarding updates to the LightStakeRegistry on the destination chain.

### [StateDisputeResolver.sol](./doc/StateDisputeResolver.md)

`StateDisputeResolver` is responsible for handling challenges against operator state claims in the Spotted AVS. Built on EigenLayer's middleware, it enables secure dispute resolution through a challenge-response mechanism backed by EigenLayer's economic stake-slashing system.

### [RemoteChainVerifier.sol](./doc/RemoteChainVerifier.md)

`RemoteChainVerifier` is responsible for verifying states on remote chains and sending results back to the main chain verifier through Abridge. It handles state verification requests and manages bridge fee payments.

### [MainChainVerifier.sol](./doc/MainChainVerifier.md)

`MainChainVerifier` is responsible for receiving and storing state verification results from remote chains through Abridge. It maintains a record of verified states and manages remote verifier authorizations.

