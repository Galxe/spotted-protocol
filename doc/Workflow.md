# Workflow

## Generate and Respond Tasks

### 1. Generate Tasks and Proof
Task generator generates tasks off chain and stores them in database. These tasks are then distributed to operators who sign and return an aggregated ECDSA signature. The responses are recorded in the database along with the tasks.

### 2. User Validate Proof
Users can validate the proof by calling the `isValidSignature` function in the corresponding stake registry contract:

```solidity
// IERC1271Upgradeable interface defined magic value
bytes4 constant internal MAGICVALUE = 0x1626ba7e;
```

If calling `isValidSignature` returns `MAGICVALUE`, the signature is valid.

## 1. Operator Register to Stake Registry

We implement an epoch system to manage operator states. The epoch period is 7 days with a 1-day grace period. Any operator state update will be effective at the next epoch if called before the grace period ends. Updates made during the grace period will take effect at the epoch after next.

1. Operator registers to stake registry by calling `registerOperatorWithSignature` function in stake registry. This will call `SpottedServiceManagerBase::registerOperator` function.

```solidity
function registerOperatorWithSignature(
    ISignatureUtils.SignatureWithSaltAndExpiry memory _operatorSignature,
    address _signingKey
) external 
```

2. `SpottedServiceManagerBase::registerOperator` function will call `AVSDirectory::registerOperatorWithSig` function.

3. `ECDSAStakeRegistry` finishes the registration process on mainnet and needs to sync operators states to other supported chains. It calls `EpochManager::queueStateUpdate` function which stores the update and will be effective at the next epoch (if not in grace period).

4. `EpochManager::sendStateUpdates` function will utilize Abridge to send state updates to other supported chains via `RegistryStateSender` contract.

5. `RegistryStateReceiver` contract will call `handleMessage` function to receive the state updates and update the operator states by calling `LightStakeRegistry::processEpochUpdate` function.

![process](/public/images/workflow-register.png)

## 2. Operator Deregister from Stake Registry

Similar to the register process.

## 3. Update Operator States in Epoch System

As illustrated in the register process, the operator states will be updated at the next epoch if the update is called before the grace period ends. The light stake registry will sync the states to other supported chains. It serves as a replica of the mainnet stake registry, ensuring consistency of operator states across different chains in the same epoch.

## 4. Challenge and Slash

1. Malicious operators sign a wrong state proof.
2. AVS detects and challengeSubmitter submits a challenge by calling `StateDisputeResolver::submitChallenge` function. Then a challenge is created and stored in `StateDisputeResolver` contract, with a unique `challengeId` generated (same as task id).

```solidity
bytes32 challengeId =
    keccak256(abi.encodePacked(
    state.user, 
    state.chainId, 
    state.blockNumber, 
    state.timestamp, 
    state.key));
```

3. Anyone can call `RemoteChainVerifier::verifyState` function to verify the state on remote chain (query `StateManager::getHistoryAtBlock` function) and then send the result to `MainChainVerifier` contract through Abridge. `MainChainVerifier` contract will record the verified state and emit `StateVerified` event.

4. Anyone can call `StateDisputeResolver::resolveChallenge` function to resolve the challenge by querying `MainChainVerifier`'s mapping. If the challenge is successful, the operator will be slashed by calling `AllocationManager::slashOperator` function.

![challenge](/public/images/workflow-challenge.png)

## 5. Reward submission

AVS will call `SpottedServiceManagerBase::submitReward` function to submit rewards based on the weight and task responses of operators. The detailed reward calculation can be found in the go script repo.


