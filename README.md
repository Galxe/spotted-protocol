# Cross-Chain State Oracle (Spotted)

Spotted is an AVS (Actively Validated Service) built on EigenLayer that enables cross-chain state queries. 

## Key Features

1. **Off-chain Task Generation**
- Tasks are generated and assigned directly by task generator to operators

1. **ECDSA Signature Verification**
- Uses ECDSA signatures for task responses
- Minimizes gas costs compared to BLS

1. **Cross-Chain State Verification**
- Verifies state claims across different chains
- Challenge-based dispute resolution system
- Bridge protocol integration for state proof verification (challenge)

2. cheap
3. optimistic
## Architecture Overview

### Core Components

1. **Service Management**
- SpottedServiceManager: Main AVS contract
- Task record and response verification

AVS (SpottedServiceManager)
-> ECDSAServiceManagerBase
-> AVSDirectory (Registration status)

1. **Registry System**

Operator
-> RegistryCoordinator (Business logic)
-> StakeRegistry (Stake management)
-> IndexRegistry (Quorum management)


3. **State Verification**
- CrossChainStateVerifier: Verifies cross-chain states
- BridgeVerifier: Protocol-specific state proof verification
- Challenge mechanism for dispute resolution

### Security Model

1. **EigenLayer Integration**
- Leverages restaking for economic security
- Slashing for malicious behavior
- Operator stake requirements

1. **Challenge System**
- Allows challenging invalid state claims
- Bond requirement for challengers
- Slashing penalties for proven violations

## Key Workflows

1. **Operator Registration**
- Register with EigenLayer
- Meet stake requirements
- Join specific quorums

2. **Task Execution**
- Task generator generates off-chain task
- Operator processes and signs response
- Response verified through ECDSA signatures

1. **Challenge**
`StateDisputeResolver::submitChallenge`  
-> `RemoteChainVerifier::verifyState`  
-> `MainChainVerifier::handleMessage (receive and update mapping)` 
-> `StateDisputeResolver::resolveChallenge (verify mapping)`

## Integration

1. **EigenLayer Core**
- Delegation Manager
- Strategy Manager

1. **Bridge Protocols**
- LayerZero (planned)
- Chainlink CCIP (planned)
- Other cross-chain messaging protocols

## Roles
Staker: delegate/undelegate through EigenLayer core contracts
Operator: register/unregister through RegistryCoordinator
Task Generator: generate tasks off chain directly to operators
Bridge Verifier: verify state proofs (only when challenged) from bridge protocols
