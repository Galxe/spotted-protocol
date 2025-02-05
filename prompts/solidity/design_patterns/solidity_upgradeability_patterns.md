<solidity_upgradeability_pattern>

## Proxy Delegate Pattern

### Core Principles
- Enable contract upgradeability
- Preserve storage layout
- Handle delegate calls safely
- Maintain transparent proxying

### Implementation Guide
```solidity
contract ProxyDelegate {
    // Storage
    bytes32 private constant IMPLEMENTATION_SLOT = 
        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
    bytes32 private constant ADMIN_SLOT = 
        bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
    
    // Events
    event Upgraded(address indexed implementation);
    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);
    
    constructor(address _logic, address _admin) {
        _setImplementation(_logic);
        _setAdmin(_admin);
    }
    
    // Proxy logic
    fallback() external payable {
        _delegate(_getImplementation());
    }
    
    receive() external payable {
        _delegate(_getImplementation());
    }
    
    // Admin functions
    modifier onlyAdmin() {
        require(msg.sender == _getAdmin(), "Not admin");
        _;
    }
    
    function upgradeTo(address newImplementation) external onlyAdmin {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }
    
    // Internal functions
    function _delegate(address implementation) internal {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code.
            calldatacopy(0, 0, calldatasize())
            
            // Call implementation
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            
            // Copy return data
            returndatacopy(0, 0, returndatasize())
            
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
    
    function _setImplementation(address newImplementation) private {
        require(newImplementation != address(0), "Invalid implementation");
        require(_isContract(newImplementation), "Not a contract");
        
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
    }
    
    function _getImplementation() private view returns (address implementation) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            implementation := sload(slot)
        }
    }
    
    function _setAdmin(address newAdmin) private {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            sstore(slot, newAdmin)
        }
    }
    
    function _getAdmin() private view returns (address admin) {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            admin := sload(slot)
        }
    }
    
    function _isContract(address addr) private view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }
}
```

### Storage Patterns
1. **Unstructured Storage**:
   - Use keccak256 slots
   - Avoid storage collisions
   - Support arbitrary layouts

2. **Eternal Storage**:
   - Separate storage contract
   - Immutable storage layout
   - Value mapping approach

3. **Diamond Storage**:
   - Namespaced storage
   - Multiple implementations
   - Faceted upgrades

### Key Points
- Validate implementations
- Handle delegate calls safely
- Emit upgrade events
- Check storage compatibility
- Implement access control

### Common Patterns
```solidity
// Storage layout contract
contract StorageLayout {
    // Never modify existing storage
    uint256 public value;
    mapping(address => uint256) public balances;
    // Only append new storage
    uint256 public newValue;
}

// Implementation contract
contract Implementation is StorageLayout {
    function setValue(uint256 _value) external {
        value = _value;
    }
}

// Transparent proxy admin
contract ProxyAdmin {
    function upgrade(
        TransparentUpgradeableProxy proxy,
        address implementation
    ) public onlyOwner {
        proxy.upgradeTo(implementation);
    }
}
```

### Anti-patterns
```solidity
// DON'T: Modify storage layout
contract BadImplementation {
    uint256 public newValue;  // Wrong order
    uint256 public value;     // Storage collision
}

// DON'T: Unprotected upgrades
function upgrade(address impl) external {  // Missing access control
    _setImplementation(impl);
}

// DON'T: Skip implementation checks
function setImplementation(address impl) {
    implementation = impl;  // Missing contract check
}

// DON'T: Unsafe delegatecall
function unsafeDelegate() {
    implementation.delegatecall(msg.data);  // Missing return handling
}
```

## Eternal Storage Pattern

### Core Principles
- Separate storage from logic
- Maintain data persistence across upgrades
- Use flexible key-value storage
- Implement proper access control

### Implementation Guide
```solidity
contract EternalStorage {
    // State variables
    address private owner;
    address private latestVersion;
    
    // Storage mappings
    mapping(bytes32 => uint256) private uintStorage;
    mapping(bytes32 => string) private stringStorage;
    mapping(bytes32 => address) private addressStorage;
    mapping(bytes32 => bytes) private bytesStorage;
    mapping(bytes32 => bool) private boolStorage;
    mapping(bytes32 => int256) private intStorage;
    
    // Events
    event VersionUpdated(address indexed oldVersion, address indexed newVersion);
    event DataStored(bytes32 indexed key, string storageType);
    event DataDeleted(bytes32 indexed key, string storageType);
    
    constructor() {
        owner = msg.sender;
    }
    
    // Access control
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyLatestVersion() {
        require(msg.sender == latestVersion, "Not latest version");
        _;
    }
    
    // Version management
    function upgradeVersion(address _newVersion) external onlyOwner {
        require(_newVersion != address(0), "Invalid address");
        address oldVersion = latestVersion;
        latestVersion = _newVersion;
        emit VersionUpdated(oldVersion, _newVersion);
    }
    
    // Getter functions
    function getUint(bytes32 _key) external view returns (uint256) {
        return uintStorage[_key];
    }
    
    function getString(bytes32 _key) external view returns (string memory) {
        return stringStorage[_key];
    }
    
    function getAddress(bytes32 _key) external view returns (address) {
        return addressStorage[_key];
    }
    
    // Setter functions
    function setUint(bytes32 _key, uint256 _value) external onlyLatestVersion {
        uintStorage[_key] = _value;
        emit DataStored(_key, "uint256");
    }
    
    function setString(bytes32 _key, string calldata _value) external onlyLatestVersion {
        stringStorage[_key] = _value;
        emit DataStored(_key, "string");
    }
    
    function setAddress(bytes32 _key, address _value) external onlyLatestVersion {
        addressStorage[_key] = _value;
        emit DataStored(_key, "address");
    }
    
    // Delete functions
    function deleteUint(bytes32 _key) external onlyLatestVersion {
        delete uintStorage[_key];
        emit DataDeleted(_key, "uint256");
    }
    
    function deleteString(bytes32 _key) external onlyLatestVersion {
        delete stringStorage[_key];
        emit DataDeleted(_key, "string");
    }
    
    function deleteAddress(bytes32 _key) external onlyLatestVersion {
        delete addressStorage[_key];
        emit DataDeleted(_key, "address");
    }
}
```

### Storage Types
1. **Basic Types**:
   - Integers (uint/int)
   - Strings and bytes
   - Addresses and booleans
   - Mappings via composite keys

2. **Complex Types**:
   - Structs via multiple keys
   - Arrays via indexed keys
   - Nested mappings
   - Custom types

3. **Key Generation**:
   - Unique identifiers
   - Composite keys
   - Namespace prefixes
   - Version tracking

### Key Points
- Maintain storage immutability
- Implement version control
- Use proper key generation
- Handle access control
- Track storage changes

### Common Patterns
```solidity
// Storage wrapper contract
contract StorageWrapper {
    EternalStorage private store;
    
    // Key generation helpers
    function userKey(address user) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("user", user));
    }
    
    function balanceKey(address user) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("balance", user));
    }
    
    // Wrapper functions
    function getUserBalance(address user) external view returns (uint256) {
        return store.getUint(balanceKey(user));
    }
    
    function setUserBalance(address user, uint256 balance) external {
        store.setUint(balanceKey(user), balance);
    }
}

// Namespace management
contract NamespacedStorage {
    bytes32 private constant NAMESPACE = keccak256("com.example.storage");
    
    function namespaceKey(string memory key) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(NAMESPACE, key));
    }
}

// Complex data storage
contract ComplexStorage {
    function setStruct(
        bytes32 key,
        uint256 value1,
        string calldata value2
    ) external {
        store.setUint(keccak256(abi.encodePacked(key, "value1")), value1);
        store.setString(keccak256(abi.encodePacked(key, "value2")), value2);
    }
}
```

### Anti-patterns
```solidity
// DON'T: Direct storage access
contract UnsafeAccess {
    mapping(bytes32 => uint256) public values;  // Should be private
}

// DON'T: Unstructured keys
function badKeyGeneration(address user) {
    store.setUint(bytes32(uint256(user)), value);  // No namespace
}

// DON'T: Missing version control
function unsafeSet(bytes32 key, uint256 value) {
    store.setUint(key, value);  // No version check
}

// DON'T: Inconsistent key generation
function inconsistentKeys() {
    store.setUint(keccak256("user_balance"), value1);
    store.setUint(sha256("user_balance"), value2);  // Different hash
}
```

> Claude must follow these patterns when implementing Solidity upgradeability patterns.

</solidity_upgradeability_pattern>

