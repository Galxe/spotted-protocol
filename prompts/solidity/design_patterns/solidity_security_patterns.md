<solidity_security_pattern>

## Access Restriction Pattern

### Core Principles
- Restrict function access based on conditions
- Use modifiers for reusable restrictions
- Implement role-based access control
- Handle ownership transfers securely

### Implementation Guide
```solidity
contract AccessControl {
    // State variables
    address private owner;
    mapping(address => bool) private admins;
    mapping(bytes32 => mapping(address => bool)) private roles;
    uint256 private lastChange;
    
    // Events
    event RoleGranted(bytes32 role, address account);
    event RoleRevoked(bytes32 role, address account);
    
    constructor() {
        owner = msg.sender;
        lastChange = block.timestamp;
    }
    
    // Basic access control
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not owner");
        _;
    }
    
    modifier onlyAdmin() {
        require(admins[msg.sender], "Caller is not admin");
        _;
    }
    
    modifier onlyRole(bytes32 role) {
        require(roles[role][msg.sender], "Missing required role");
        _;
    }
    
    // Time-based restrictions
    modifier onlyAfter(uint256 time) {
        require(block.timestamp >= time, "Too early");
        _;
    }
    
    // Value-based restrictions
    modifier costs(uint256 amount) {
        require(msg.value >= amount, "Insufficient payment");
        _;
        uint256 refund = msg.value - amount;
        if (refund > 0) {
            payable(msg.sender).transfer(refund);
        }
    }
    
    // Role management
    function grantRole(bytes32 role, address account) external onlyAdmin {
        roles[role][account] = true;
        emit RoleGranted(role, account);
    }
    
    function revokeRole(bytes32 role, address account) external onlyAdmin {
        roles[role][account] = false;
        emit RoleRevoked(role, account);
    }
}
```

### Restriction Types
1. **Identity-based**:
   - Owner restrictions
   - Role-based access
   - Multi-signature requirements

2. **State-based**:
   - Contract state checks
   - Balance requirements
   - Time-based locks

3. **Value-based**:
   - Payment requirements
   - Stake conditions
   - Token holdings

### Key Points
- Use descriptive modifier names
- Implement secure role management
- Consider multi-sig for critical functions
- Handle ownership transfers safely
- Emit events for important changes

### Common Patterns
```solidity
// Role-based access
bytes32 public constant MINTER_ROLE = keccak256("MINTER");
modifier onlyMinter() {
    require(hasRole(MINTER_ROLE, msg.sender), "Not minter");
    _;
}

// Multi-signature requirement
modifier requiresApprovals(uint256 required) {
    require(approvals[msg.sig] >= required, "Insufficient approvals");
    _;
}

// Pausable functionality
modifier whenNotPaused() {
    require(!paused, "Contract is paused");
    _;
}

// Timed lock
modifier lockUntil(uint256 time) {
    require(block.timestamp >= time, "Still locked");
    _;
}
```

### Anti-patterns
```solidity
// DON'T: Use tx.origin
modifier unsafe() {
    require(tx.origin == owner);  // Use msg.sender instead
    _;
}

// DON'T: Forget zero address checks
function setOwner(address newOwner) external {  // Missing check
    owner = newOwner;
}

// DON'T: Complex modifier logic
modifier complexCheck() {
    // Keep modifier logic simple and focused
    require(complex && nested && logic);
    _;
}

// DON'T: Hardcode roles
modifier onlyAdmin() {
    require(msg.sender == 0x123...);  // Use role-based system
    _;
}
```

## Emergency Stop Pattern

### Core Principles
- Provide emergency pause functionality
- Protect critical operations
- Enable safe recovery mechanisms
- Implement proper authorization

### Implementation Guide
```solidity
contract EmergencyStop {
    // State variables
    bool public paused;
    address private guardian;
    mapping(address => uint256) private balances;
    
    // Events
    event ContractPaused(address indexed by);
    event ContractUnpaused(address indexed by);
    event EmergencyWithdrawal(address indexed user, uint256 amount);
    
    constructor() {
        guardian = msg.sender;
    }
    
    // Circuit breaker modifiers
    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }
    
    modifier whenPaused() {
        require(paused, "Contract not paused");
        _;
    }
    
    modifier onlyGuardian() {
        require(msg.sender == guardian, "Not guardian");
        _;
    }
    
    // Emergency controls
    function pause() external onlyGuardian {
        require(!paused, "Already paused");
        paused = true;
        emit ContractPaused(msg.sender);
    }
    
    function unpause() external onlyGuardian {
        require(paused, "Not paused");
        paused = false;
        emit ContractUnpaused(msg.sender);
    }
    
    // Normal operation functions
    function deposit() external payable whenNotPaused {
        balances[msg.sender] += msg.value;
    }
    
    function transfer(address to, uint256 amount) external whenNotPaused {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        balances[to] += amount;
    }
    
    // Emergency functions
    function emergencyWithdraw() external whenPaused {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance");
        
        balances[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdrawal failed");
        
        emit EmergencyWithdrawal(msg.sender, amount);
    }
}
```

### Protection Levels
1. **Full Stop**:
   - All non-emergency functions disabled
   - Only recovery operations allowed
   - Complete operational halt

2. **Partial Stop**:
   - Critical functions paused
   - Basic operations continue
   - Selective functionality

3. **Gradual Stop**:
   - Phased shutdown process
   - Tiered access restrictions
   - Controlled wind-down

### Key Points
- Implement proper access control
- Include emergency recovery
- Emit pause/unpause events
- Consider partial stops
- Test recovery scenarios

### Common Patterns
```solidity
// Multi-guardian system
contract MultiGuardian {
    uint256 public constant MIN_SIGNATURES = 2;
    mapping(address => bool) public guardians;
    mapping(bytes32 => uint256) public pauseVotes;
    
    function proposePause() external {
        require(guardians[msg.sender], "Not guardian");
        bytes32 pauseId = keccak256(abi.encodePacked(block.timestamp));
        pauseVotes[pauseId]++;
        
        if (pauseVotes[pauseId] >= MIN_SIGNATURES) {
            _pause();
        }
    }
}

// Tiered shutdown
contract TieredStop {
    enum StopLevel { NONE, PARTIAL, FULL }
    StopLevel public currentLevel;
    
    modifier atLevel(StopLevel level) {
        require(currentLevel == level, "Wrong level");
        _;
    }
    
    function setStopLevel(StopLevel level) external onlyGuardian {
        currentLevel = level;
    }
}

// Time-locked recovery
contract TimedRecovery {
    uint256 public constant RECOVERY_DELAY = 24 hours;
    uint256 public pauseTime;
    
    function initiateRecovery() external whenPaused onlyGuardian {
        pauseTime = block.timestamp;
    }
    
    function completeRecovery() external whenPaused onlyGuardian {
        require(block.timestamp >= pauseTime + RECOVERY_DELAY, "Too early");
        _unpause();
    }
}
```

### Anti-patterns
```solidity
// DON'T: Unprotected pause
function pause() external {  // Missing access control
    paused = true;
}

// DON'T: Irreversible stop
function emergencyStop() external onlyOwner {  // No unpause
    paused = true;
}

// DON'T: Unsafe state changes
function riskyFunction() external whenNotPaused {
    // State changes before checks
    balances[msg.sender] = 0;
    require(msg.sender.send(amount), "Failed");
}

// DON'T: Missing events
function setPaused(bool state) external {  // No events
    paused = state;
}
```

> Claude must follow these patterns when implementing Solidity security patterns.

</solidity_security_pattern>
