<solidity_behavioral_pattern>

## Guard Check Pattern

### Core Principles
- Validate inputs and state before execution
- Use appropriate validation methods (require, assert, revert)
- Maintain contract invariants
- Preserve atomicity on failure

### Implementation Guide
```solidity
contract GuardCheck {
    // Input validation
    function processUserInput(uint input) public {
        require(input > 0, "Input must be positive");  // Pre-condition check
        require(input < max, "Input exceeds max");     // Boundary check
        
        // Process input...
        
        assert(invariant == true);  // Post-condition check
    }
    
    // State validation
    function complexStateChange(address addr, uint amount) public {
        // Pre-conditions
        require(addr != address(0), "Invalid address");
        require(amount > 0, "Invalid amount");
        
        // Complex state checks
        if (condition1) {
            // Do something
        } else if (condition2) {
            // Do something else
        } else {
            revert("Invalid state");  // Complex condition failure
        }
        
        // Post-conditions
        assert(totalSupply == previousSupply + amount);  // Invariant check
    }
}
```

### Usage Guidelines
1. **require()** - Use for:
   - Input validation
   - State preconditions
   - External call validation
   - Return value checks

2. **assert()** - Use for:
   - Invariant checks
   - Overflow/underflow checks
   - Internal error detection
   - Post-condition validation

3. **revert()** - Use for:
   - Complex condition failures
   - Multi-condition logic
   - Custom error scenarios

### Key Points
- Place require() at function start
- Use assert() for critical invariants
- Add descriptive error messages
- Consider gas costs (assert uses all gas)
- Maintain atomicity on failures

### Common Patterns
```solidity
// Input validation
require(input != 0, "Invalid input");

// Address validation
require(addr != address(0), "Zero address");

// Authorization
require(msg.sender == owner, "Unauthorized");

// State checks
require(state == State.Active, "Invalid state");

// Balance checks
require(balance >= amount, "Insufficient balance");

// Complex conditions
if (complexCondition) {
    revert("Invalid scenario");
}

// Invariant checks
assert(x == y + z);
```

### Anti-patterns
```solidity
// DON'T: Use assert for input validation
assert(input > 0);  // Will consume all gas

// DON'T: Skip error messages
require(condition);  // Hard to debug

// DON'T: Complex require conditions
require(a && b && c && d);  // Split into multiple checks

// DON'T: Late validation
// ... complex logic ...
require(input > 0);  // Validate early
```

## State Machine Pattern

### Core Principles
- Define explicit contract stages using enums
- Control function access based on stages
- Implement secure stage transitions
- Handle time-based stage changes

### Implementation Guide
```solidity
contract StateMachine {
    // Stage definitions
    enum Stages {
        Stage1,
        Stage2,
        Stage3,
        Finished
    }
    
    Stages public currentStage = Stages.Stage1;
    uint256 public stageStartTime;
    
    // Stage control
    modifier atStage(Stages _stage) {
        require(currentStage == _stage, "Invalid stage");
        _;
    }
    
    // Auto transition
    modifier timedTransitions() {
        if (currentStage == Stages.Stage1 && block.timestamp >= stageStartTime + 1 days) {
            _nextStage();
        }
        _;
    }
    
    // Manual transition
    modifier transitionAfter() {
        _;
        _nextStage();
    }
    
    // Stage-specific functions
    function stage1Function() external 
        timedTransitions 
        atStage(Stages.Stage1) 
    {
        // Stage 1 logic
    }
    
    function stage2Function() external 
        timedTransitions 
        atStage(Stages.Stage2) 
        transitionAfter 
    {
        // Stage 2 logic
    }
    
    // Internal helpers
    function _nextStage() internal {
        currentStage = Stages(uint(currentStage) + 1);
        stageStartTime = block.timestamp;
    }
}
```

### Transition Types
1. **Time-based**:
   - Use block.timestamp for timing
   - Consider miner manipulation (±900s)
   - Implement through modifiers

2. **Function-based**:
   - Manual transitions after logic
   - Automatic transitions on completion
   - Guard against unauthorized changes

3. **Condition-based**:
   - Transition based on contract state
   - Check external conditions
   - Validate state changes

### Key Points
- Define clear stage progression
- Validate stage transitions
- Handle edge cases
- Consider timing attacks
- Document stage requirements

### Common Patterns
```solidity
// Stage definition
enum Stages { Created, Active, Ended }

// Stage check
modifier onlyDuringStage(Stages _stage) {
    require(currentStage == _stage, "Wrong stage");
    _;
}

// Timed transition
modifier checkStageTransition() {
    if (shouldTransition()) {
        currentStage = nextStage();
    }
    _;
}

// Manual transition
function completeStage() external {
    require(canCompleteStage(), "Cannot complete");
    currentStage = nextStage();
    emit StageCompleted(currentStage);
}
```

### Anti-patterns
```solidity
// DON'T: Unprotected transitions
function nextStage() public {  // Should be internal/private
    currentStage = Stages(uint(currentStage) + 1);
}

// DON'T: Missing stage validation
function criticalFunction() public {  // Missing stage check
    // Logic that should only run in specific stage
}

// DON'T: Incorrect modifier order
function stageFunction() public
    atStage(Stages.Active)     // Wrong order
    timedTransitions           // Should be first
{
    // Logic
}

// DON'T: Tight timing constraints
require(block.timestamp == targetTime);  // Too strict
```

## Oracle Pattern

### Core Principles
- Access off-chain data securely
- Maintain data integrity and trust
- Handle asynchronous responses
- Implement proper error handling

### Implementation Guide
```solidity
contract OracleConsumer {
    // Oracle interface
    struct Request {
        bytes32 id;
        bool fulfilled;
        string result;
    }
    
    mapping(bytes32 => Request) public requests;
    address public oracle;
    
    // Request handling
    function requestData() external payable {
        require(msg.value >= oraclePrice, "Insufficient payment");
        
        bytes32 requestId = oracleContract.request{value: msg.value}(
            "URL",
            "json(https://api.example.com/data).result"
        );
        
        requests[requestId] = Request({
            id: requestId,
            fulfilled: false,
            result: ""
        });
    }
    
    // Callback function
    function __callback(bytes32 requestId, string memory result) external {
        require(msg.sender == oracle, "Unauthorized");
        require(!requests[requestId].fulfilled, "Already fulfilled");
        
        requests[requestId].fulfilled = true;
        requests[requestId].result = result;
        
        processResult(requestId);
    }
    
    // Result processing
    function processResult(bytes32 requestId) internal {
        string memory result = requests[requestId].result;
        // Process the result...
    }
}
```

### Integration Types
1. **Centralized Oracle**:
   - Single trusted data provider
   - Simple integration
   - Single point of failure

2. **Decentralized Oracle**:
   - Multiple data sources
   - Consensus mechanism
   - Higher reliability

3. **Hardware Oracle**:
   - Trusted execution environment
   - Direct hardware readings
   - Enhanced security

### Key Points
- Verify oracle authenticity
- Handle callback failures
- Consider data source reliability
- Implement timeout mechanisms
- Plan for oracle costs

### Common Patterns
```solidity
// Multiple oracle consensus
contract MultiOracle {
    uint256 public constant MIN_RESPONSES = 3;
    mapping(bytes32 => uint256) public responseCounts;
    mapping(bytes32 => mapping(string => uint256)) public responseVotes;
    
    function processResponse(bytes32 requestId, string memory response) internal {
        responseVotes[requestId][response]++;
        
        if (responseVotes[requestId][response] >= MIN_RESPONSES) {
            finalizeRequest(requestId, response);
        }
    }
}

// Timeout handling
contract TimeoutOracle {
    uint256 public constant TIMEOUT = 1 hours;
    mapping(bytes32 => uint256) public requestTimes;
    
    function checkTimeout(bytes32 requestId) public {
        if (block.timestamp >= requestTimes[requestId] + TIMEOUT) {
            handleTimeout(requestId);
        }
    }
}
```

### Anti-patterns
```solidity
// DON'T: Trust single source blindly
function unsafeCallback(string memory result) external {
    processResult(result);  // Missing sender validation
}

// DON'T: Ignore response validation
function weakCallback(bytes32 id, string memory result) external {
    require(msg.sender == oracle);  // Missing request validation
    requests[id].result = result;   // Missing fulfillment check
}

// DON'T: Skip timeout handling
function requestWithoutTimeout() external {
    oracle.request("data");  // No timeout mechanism
}

// DON'T: Hardcode URLs
string constant URL = "https://api.example.com";  // Inflexible
```

## Randomness Pattern

### Core Principles
- Generate secure pseudo-random numbers
- Prevent manipulation by miners
- Use commit-reveal scheme
- Handle seed management securely

### Implementation Guide
```solidity
contract RandomnessGenerator {
    // State variables
    bytes32 private sealedSeed;
    uint256 private commitBlock;
    address private trustedParty;
    bool private isCommitted;
    
    // Events
    event SeedCommitted(bytes32 sealedSeed, uint256 commitBlock);
    event RandomGenerated(uint256 random);
    
    // Commit phase
    function commitSeed(bytes32 _sealedSeed) external {
        require(msg.sender == trustedParty, "Unauthorized");
        require(!isCommitted, "Already committed");
        
        sealedSeed = _sealedSeed;
        commitBlock = block.number + 1;
        isCommitted = true;
        
        emit SeedCommitted(_sealedSeed, commitBlock);
    }
    
    // Reveal phase
    function revealSeed(bytes32 _seed) external returns (uint256) {
        require(isCommitted, "Not committed");
        require(block.number > commitBlock, "Too early");
        require(keccak256(abi.encodePacked(msg.sender, _seed)) == sealedSeed, "Invalid seed");
        
        uint256 random = uint256(keccak256(abi.encodePacked(
            _seed,
            blockhash(commitBlock)
        )));
        
        isCommitted = false;
        emit RandomGenerated(random);
        return random;
    }
    
    // Helper functions
    function boundedRandom(uint256 random, uint256 min, uint256 max) internal pure returns (uint256) {
        require(max > min, "Invalid bounds");
        return min + (random % (max - min + 1));
    }
}
```

### Generation Methods
1. **Block Hash Based**:
   - Use future block hash
   - Combine with committed seed
   - Consider block availability limit

2. **Oracle Based**:
   - Use external RNG service
   - Higher trust requirements
   - Additional cost per request

3. **Commit-Reveal**:
   - Two-phase process
   - Prevents manipulation
   - Requires trusted party

### Key Points
- Never use block.timestamp
- Avoid predictable sources
- Consider block hash limitations
- Implement timeout handling
- Validate seed commitments

### Common Patterns
```solidity
// Bounded random number
function getRandomNumber(uint256 min, uint256 max) internal returns (uint256) {
    uint256 random = generateRandom();
    return min + (random % (max - min + 1));
}

// Multi-block random
function multiBlockRandom() internal returns (uint256) {
    return uint256(keccak256(abi.encodePacked(
        blockhash(block.number - 1),
        blockhash(block.number - 2),
        block.difficulty
    )));
}

// VRF-style random
function verifiableRandom(bytes32 seed, bytes32 blockHash) 
    internal pure returns (uint256, bytes memory) 
{
    return VRF.generateProof(seed, blockHash);
}
```

### Anti-patterns
```solidity
// DON'T: Use block.timestamp
uint256 random = uint256(block.timestamp);  // Manipulatable

// DON'T: Use current block hash
uint256 random = uint256(blockhash(block.number));  // Predictable

// DON'T: Single source of randomness
uint256 random = uint256(keccak256(msg.sender));  // Manipulatable

// DON'T: Forget bounds
uint256 random = generateRandom() % max;  // Biased distribution
```

> Claude must follow these patterns when implementing Solidity behavioral patterns.

</solidity_behavioral_pattern>
