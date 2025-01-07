# Workflow

## Generate and Respond Tasks

### Generate Tasks and Proof

task generator generates tasks off chain and store in database, then give tasks to operators to sign and return an aggregated ECDSA signature, then response tasks and record the responses in database.

### User Validate Proof

user can validate the proof by calling the `isValidSignature` function in the corresponding stake registry on the chain.

```solidity
// IERC1271Upgradeable interface defined magic value
bytes4 constant internal MAGICVALUE = 0x1626ba7e;
```

if calling `isValidSignature` returns `MAGICVALUE`, the signature is valid.

## 1. Operator Register to Stake Registry

We implements epoch system to manage operator states. The epoch period is 7 days and the grace period is 1 day. Which means any operator state update will be effective at the next epoch if it is called before the grace period ends. And any update in the grace period will be effective at the epoch next epoch.

1. Operator register to stake registry by calling `registerOperatorWithSignature` function in stake registry. This will call `SpottedServiceManagerBase::registerOperator` function.

```solidity
 function registerOperatorWithSignature(
        ISignatureUtils.SignatureWithSaltAndExpiry memory _operatorSignature,
        address _signingKey
    ) external 
```
2. `SpottedServiceManagerBase::registerOperator` function will call `AVSDirectory::registerOperatorWithSig` function.

3. `ECDSAStakeRegistry` finished the registration process on mainnet and need to sync operators states to other supported chains. It calls `EpochManager::queueStateUpdate` function which stores the update and will be effective at the next epoch (if not in grace period).

4. `EpochManager::sendStateUpdates` function will utilize Abridge to send state updates to other supported chains via `RegistryStateSender` contract.

5. `RegistryStateReceiver` contract will `handleMessage` function to receive the state updates and update the operator states by calling `LightStakeRegistry::processEpochUpdate` function.

![process](/public/images/workflow-register.png)

## 2. Operator Deregister from Stake Registry

Similar to the register process.

## 3. Update Operator States in Epoch System

As illustrated in the register process, the operator states will be updated at the next epoch if the update is called before the grace period ends. And the light stake registry will sync the states to other supported chains. It serves as a replica of the mainnet stake registry. It ensures the consistency of the operator states across different chains in a same epoch.

## 4. Challenge and Slash

## 5. Reward submission



