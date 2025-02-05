<anthropic_solidity_attack_protocol>

## Reentrancy Attacks

### Core Principles
- Follow Checks-Effects-Interactions pattern
- Update state before external calls
- Use reentrancy guards for critical functions
- Consider cross-function and cross-contract reentrancy

### Implementation
```solidity
// SECURE PATTERN
function withdraw() public nonReentrant {
    uint amount = balances[msg.sender];
    balances[msg.sender] = 0;  // State change first
    (bool success, ) = msg.sender.call{value: amount}("");
    require(success);
}

// CROSS-CONTRACT PROTECTION
modifier crossContractGuard() {
    require(!operationInProgress[msg.sender]);
    operationInProgress[msg.sender] = true;
    _;
    operationInProgress[msg.sender] = false;
}
```

### Key Points
- Use OpenZeppelin's ReentrancyGuard
- Lock state during external calls
- Test for cross-function vulnerabilities
- Monitor for suspicious patterns
- Document trust assumptions



## Ambiguous Evaluation Order

### Core Principles
- Never rely on expression evaluation order
- Use temporary variables for intermediate results
- Avoid side effects in complex expressions
- Make evaluation order explicit

### Implementation
```solidity
// VULNERABLE PATTERNS
function vulnerable() public returns (uint) {
    uint x = 5;
    return x * x++;  // Ambiguous: could be 25 or 30
}

function vulnerable2(uint a) public returns (uint) {
    return complex1(a) + complex2(a);  // Order of side effects unclear
}

// SECURE PATTERNS
function secure(uint x) public returns (uint) {
    uint temp = x;  // Store value first
    x++;           // Modify after
    return temp * temp;  // Clear evaluation order
}

function secure2(uint a) public returns (uint) {
    // Make evaluation order explicit
    uint result1 = complex1(a);
    uint result2 = complex2(a);
    return result1 + result2;
}

// HANDLING MULTIPLE TRANSFORMATIONS
function secureTransform(uint input) public returns (uint) {
    // Explicit transformation chain
    uint step1 = transform1(input);
    uint step2 = transform2(step1);
    return transform3(step2);
}
```

### Key Points
- Break complex expressions into simple steps
- Document evaluation dependencies clearly
- Test with different compiler versions
- Avoid mixing state changes with calculations
- Use explicit temporary variables for clarity

## Frontrunning

### Core Principles
- Minimize transaction ordering importance
- Implement commit-reveal schemes
- Use batch processing where possible
- Set reasonable slippage limits
- Consider MEV protection

### Implementation
```solidity
// VULNERABLE PATTERNS
contract Vulnerable {
    function submitGuess(uint256 number) public payable {
        if (number == secretNumber) {  // Visible in mempool
            payable(msg.sender).transfer(prize);
        }
    }
}

// SECURE PATTERNS
contract CommitReveal {
    mapping(address => bytes32) private commits;
    mapping(address => bool) private revealed;
    
    // Step 1: Submit hash of guess
    function commitGuess(bytes32 commitHash) external {
        commits[msg.sender] = commitHash;
    }
    
    // Step 2: Reveal actual guess
    function revealGuess(uint256 guess, bytes32 nonce) external {
        require(!revealed[msg.sender], "Already revealed");
        bytes32 commit = commits[msg.sender];
        require(commit == keccak256(abi.encodePacked(guess, nonce)), "Invalid reveal");
        
        revealed[msg.sender] = true;
        // Process guess...
    }
}
```

### Key Points
- Use commit-reveal for sensitive operations
- Implement batch processing mechanisms
- Add price protection with min/max bounds
- Consider time delays for critical operations
- Monitor for unusual transaction patterns
- Use private mempools when possible



## ABI Hash Collisions

### Core Principles
- Avoid `abi.encodePacked` with multiple variable-length arguments
- Use `abi.encode` for dynamic types
- Add length checks or delimiters when packing is necessary
- Consider gas costs vs security trade-offs

### Implementation
```solidity
// VULNERABLE PATTERN
function hashVulnerable(address[] calldata a, address[] calldata b) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(a, b));  // Possible collision
}

// SECURE PATTERN
function hashSecure(address[] calldata a, address[] calldata b) public pure returns (bytes32) {
    return keccak256(abi.encode(a, b));  // No collisions possible
}

// ALTERNATIVE SECURE PATTERN (Gas Efficient)
function hashSecureEfficient(address[] calldata a, address[] calldata b) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(
        a.length,    // Add length as delimiter
        a,
        b.length,
        b
    ));
}
```

### Key Points
- Use `abi.encode` for signatures and storage keys
- Add explicit length checks when using `abi.encodePacked`
- Test hash collisions with different input combinations
- Document encoding choices and security assumptions
- Consider using fixed-size arrays where possible

## Approval Vulnerabilities

### Core Principles
- Avoid unlimited approvals
- Use safe approval functions
- Implement allowance tracking
- Consider two-step approval process
- Protect against frontrunning

### Implementation
```solidity
// VULNERABLE PATTERNS
function approve(address spender, uint256 amount) public returns (bool) {
    _approve(msg.sender, spender, amount);  // Direct setting - vulnerable to frontrunning
    return true;
}

// SECURE PATTERNS
contract SafeToken is ERC20 {
    // Safe increase/decrease allowance
    function safeIncreaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        uint256 currentAllowance = allowance(msg.sender, spender);
        _approve(msg.sender, spender, currentAllowance + addedValue);
        return true;
    }
    
    // Two-step approval process
    mapping(address => mapping(address => uint256)) private _pendingAllowances;
    
    function proposeAllowance(address spender, uint256 amount) public {
        _pendingAllowances[msg.sender][spender] = amount;
    }
    
    function confirmAllowance(address spender) public {
        uint256 amount = _pendingAllowances[msg.sender][spender];
        _approve(msg.sender, spender, amount);
        delete _pendingAllowances[msg.sender][spender];
    }
    
    // Limited-time approval
    mapping(address => mapping(address => uint256)) private _approvalDeadlines;
    
    function approveWithDeadline(address spender, uint256 amount, uint256 deadline) public {
        require(deadline > block.timestamp, "Invalid deadline");
        _approve(msg.sender, spender, amount);
        _approvalDeadlines[msg.sender][spender] = deadline;
    }
}
```

### Key Points
- Use OpenZeppelin's SafeERC20 for approvals
- Implement time-based or usage-based limits
- Add approval expiration mechanisms
- Monitor and log approval activities
- Provide tools for approval management
- Consider implementing approval caps

## Exposed Data

### Core Principles
- Never store PII on-chain
- Use off-chain storage for sensitive data
- Hash or encrypt necessary identifiers
- Implement access controls for data retrieval
- Consider regulatory compliance (GDPR)

### Implementation
```solidity
// VULNERABLE PATTERNS
contract Vulnerable {
    struct User {
        string email;     // PII exposed!
        string ipAddress; // Technical data exposed!
        address wallet;
    }
    mapping(address => User) public users;  // All data public!
}

// SECURE PATTERNS
contract Secure {
    // Only store hashes on-chain
    mapping(address => bytes32) private userDataHashes;
    
    // Store minimal required data
    struct UserOnChain {
        bytes32 dataHash;
        uint256 timestamp;
        bool isActive;
    }
    
    // Event for off-chain indexing
    event UserRegistered(address indexed user, bytes32 indexed dataHash);
    
    // Store hash of data instead of raw data
    function registerUser(bytes32 dataHash) external {
        userDataHashes[msg.sender] = dataHash;
        emit UserRegistered(msg.sender, dataHash);
    }
    
    // Verify data without exposing it
    function verifyUser(address user, bytes calldata data) external view returns (bool) {
        return keccak256(data) == userDataHashes[user];
    }
}
```

### Key Points
- Use off-chain storage systems (IPFS/Ceramic)
- Implement data minimization principles
- Hash sensitive identifiers before storage
- Use proxy identifiers when possible
- Maintain clear data access patterns
- Document data handling procedures

## Griefing Attacks

### Core Principles
- Validate external call results
- Implement gas limits for operations
- Use pull over push patterns
- Add rate limiting mechanisms
- Protect against timestamp manipulation

### Implementation
```solidity
// VULNERABLE PATTERNS
contract Vulnerable {
    // Timestamp manipulation vulnerability
    function deposit() public payable {
        lastDeposit = block.timestamp;  // Can be manipulated
    }
    
    // Gas griefing vulnerability
    function forward(bytes memory data) public {
        executed[data] = true;
        target.call(data);  // No gas limit or return check
    }
}

// SECURE PATTERNS
contract Secure {
    // Protected timestamp usage
    uint256 private constant MIN_DELAY = 1 hours;
    mapping(address => uint256) private lastOperations;
    
    function deposit() public payable {
        require(block.timestamp >= lastOperations[msg.sender] + MIN_DELAY, "Rate limited");
        lastOperations[msg.sender] = block.timestamp;
    }
    
    // Safe forwarding with gas limits
    function safeForward(
        address target,
        bytes memory data,
        uint256 gasLimit
    ) public returns (bool) {
        require(gasLimit >= MIN_GAS_LIMIT, "Insufficient gas limit");
        
        bool success;
        assembly {
            success := call(gasLimit, target, 0, add(data, 0x20), mload(data), 0, 0)
        }
        require(success, "Forward failed");
        return success;
    }
    
    // Pull pattern implementation
    mapping(address => uint256) private pendingWithdrawals;
    
    function withdraw() public {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "Nothing to withdraw");
        
        pendingWithdrawals[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }
}

// Rate Limited Contract
contract RateLimited {
    mapping(address => uint256) private lastAction;
    uint256 private constant RATE_LIMIT = 1 hours;
    
    modifier rateLimited() {
        require(
            block.timestamp >= lastAction[msg.sender] + RATE_LIMIT,
            "Rate limited"
        );
        lastAction[msg.sender] = block.timestamp;
        _;
    }
    
    function protectedAction() external rateLimited {
        // Protected action logic
    }
}
```

### Key Points
- Check return values of external calls
- Set appropriate gas limits for forwarding
- Implement rate limiting mechanisms
- Use pull patterns for withdrawals
- Monitor for suspicious patterns
- Add circuit breakers for critical functions

## Incorrect Parameter Order

### Core Principles
- Use structs for complex parameters
- Implement clear parameter naming
- Add validation for critical values
- Write comprehensive tests
- Document parameter ordering

### Implementation
```solidity
// VULNERABLE PATTERNS
contract Vulnerable {
    // Easy to mix up parameters
    function updatePosition(
        uint256 size,
        uint256 margin,
        uint256 price,
        bool isLong,
        uint256 leverage
    ) public {
        // Complex logic with many parameters
    }
    
    // Inconsistent parameter order
    function updateBorrowing(
        uint256 borrowFactor,
        uint256 size
    ) internal {
        marketUtils.update(
            size,           // Wrong order!
            borrowFactor    // Wrong order!
        );
    }
}
```

### Key Points
- Use structs for functions with many parameters
- Implement builder pattern for complex objects
- Add parameter validation checks
- Maintain consistent parameter ordering
- Write extensive test coverage
- Document parameter requirements clearly

## 9. Oracle Manipulation

### Core Principles
- Never use single price source
- Implement TWAP for price feeds
- Use decentralized oracle networks
- Add price deviation checks
- Monitor oracle health

### Implementation
```solidity
// VULNERABLE PATTERNS
contract Vulnerable {
    // Direct spot price usage
    function getPrice(address pair) public view returns (uint256) {
        (, int24 tick, , , , , ) = IUniswapV3Pool(pair).slot0();
        return tick;  // Vulnerable to manipulation
    }
    
    // Single oracle dependency
    function executeOrder(uint256 amount) public {
        uint256 price = oracle.getPrice();  // Single point of failure
        // Execute trade...
    }
}
```

### Key Points
- Use Time-Weighted Average Prices (TWAP)
- Implement multiple oracle sources
- Add price deviation checks
- Include circuit breakers
- Monitor oracle freshness
- Consider oracle network health

## Signature Attacks

### Core Principles
- Validate signature recovery results
- Prevent signature replay attacks
- Include chain ID in signatures
- Use OpenZeppelin's ECDSA library
- Implement nonce tracking

### Implementation
```solidity
// VULNERABLE PATTERNS
contract Vulnerable {
    // Missing validation
    function recover(uint8 v, bytes32 r, bytes32 s, bytes32 hash) external {
        address signer = ecrecover(hash, v, r, s);  // No validation
    }
    
    // Replay vulnerability
    function execute(bytes memory signature) external {
        bytes32 hash = keccak256(abi.encodePacked(msg.data));
        address signer = ECDSA.recover(hash, signature);  // Can be replayed
    }
}

// SECURE PATTERNS: OpenZeppelin EIP-712
```

### Key Points
- Use OpenZeppelin's ECDSA library
- Track and validate nonces
- Include chain ID in signatures
- Implement signature blacklisting
- Use EIP-712 for typed data
- Check for signature malleability
- Validate all recovery results

## Unprotected Swaps

### Core Principles
- Implement strict slippage protection
- Use commit-reveal for critical swaps
- Add dynamic price validation
- Monitor liquidity conditions
- Protect against sandwich attacks

### Key Points
- Never use zero minAmountOut
- Implement commit-reveal for large swaps
- Use TWAP for price validation
- Add dynamic fee selection
- Monitor pool liquidity
- Consider MEV protection
- Add emergency circuit breakers

## Denial of Service

### Core Principles
- Use pull over push payments
- Avoid unbounded operations
- Implement gas-efficient patterns
- Add circuit breakers
- Plan for block gas limits

### Implementation
```solidity
// VULNERABLE PATTERNS
contract Vulnerable {
    // Push payment vulnerability
    function refundAll() public {
        for(uint i = 0; i < refundAddresses.length; i++) {
            require(refundAddresses[i].send(refunds[i]));  // Can DoS
        }
    }
    
    // Unbounded iteration
    function processLargeArray() public {
        for(uint i = 0; i < hugeArray.length; i++) {  // May hit block gas limit
            // Complex processing...
        }
    }
}
```

### Key Points
- Use pull payment patterns
- Implement batch processing
- Add operation bounds
- Include circuit breakers
- Monitor gas usage
- Plan for network congestion
- Test edge cases thoroughly

> Claude must follow this protocol when implementing secure Solidity contracts.

</anthropic_solidity_attack_protocol>