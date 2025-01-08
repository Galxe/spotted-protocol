# RegistryStateReceiver

| File | Type | Proxy |
| -------- | -------- | -------- |
| `RegistryStateReceiver.sol` | Singleton(other support chains) | No proxy |

`RegistryStateReceiver` is responsible for receiving and processing operator state updates from the mainnet through Abridge. It maintains the synchronized operator state by forwarding updates to the LightStakeRegistry on the destination chain.

## Core Components

### State Variables
```solidity
IAbridge public immutable abridge;                   // Bridge interface
address public immutable sender;                     // Authorized sender address
ILightStakeRegistry public immutable stakeRegistry;  // Stake registry reference
uint256 private currentEpoch;                        // Current epoch number
```

### Access Control
```solidity
modifier onlyAbridge() {
    if (msg.sender != address(abridge)) revert RegistryStateReceiver__InvalidSender();
    _;
}

modifier onlyOwner() {
    // OpenZeppelin Ownable implementation
}
```

## Key Features

### Message Handling
```solidity
function handleMessage(
    address from,
    bytes calldata message,
    bytes32 /*guid*/
) external onlyAbridge returns (bytes4)
```
- Processes state updates received through the bridge
- Validates sender authorization
- Decodes epoch and update data
- Updates current epoch
- Forwards updates to stake registry
- Returns success selector

### Route Management
```solidity
function updateRoute(bool allowed) external onlyOwner
```
- Updates bridge route settings for sender
- Controls message reception authorization
- Only callable by owner

### State Queries
```solidity
function getCurrentEpoch() external view returns (uint256)
```
- Returns current epoch number
- Used for synchronization verification

## Integration Points

The contract integrates with:
1. **Abridge**: For cross-chain message reception
2. **LightStakeRegistry**: For processing state updates
3. **RegistryStateSender**: Source of state updates on mainnet

## Security Features

1. **Access Control**
   - Bridge-only message handling
   - Owner-only route management
   - Sender validation

2. **Message Validation**
   - Source address verification
   - Message format validation
   - Update processing verification

3. **Error Handling**
   - Explicit revert conditions
   - Update failure detection
   - Clear error messages

## Error Cases
```solidity
error RegistryStateReceiver__InvalidSender()
error RegistryStateReceiver__BatchUpdateFailed()
```

## Events
```solidity
event UpdateProcessed(uint256 epoch, uint256 updateCount)
```

## Constructor Configuration
```solidity
constructor(
    address _abridge,
    address _sender,
    address _stakeRegistry,
    address _owner
)
```
- Initializes contract with required addresses
- Sets up initial bridge routing
- Establishes ownership
- Validates configuration parameters
