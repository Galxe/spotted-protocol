<solidity_economic_pattern>
## String Equality Comparison Pattern

### Core Principles
- Optimize gas consumption for string comparisons
- Handle different string lengths efficiently
- Use cryptographic hashing for equality checks
- Implement gas-efficient comparison logic

### Implementation Guide
```solidity
contract StringComparison {
    // Events
    event ComparisonResult(bool result, uint256 gasUsed);
    
    // Main comparison function
    function compareStrings(string memory a, string memory b) public returns (bool) {
        uint256 startGas = gasleft();
        bool result = _compareWithLengthCheck(a, b);
        
        emit ComparisonResult(result, startGas - gasleft());
        return result;
    }
    
    // Optimized internal comparison
    function _compareWithLengthCheck(string memory a, string memory b) internal pure returns (bool) {
        // Length check first to save gas
        if (bytes(a).length != bytes(b).length) {
            return false;
        }
        
        // Hash comparison for equal lengths
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
    
    // Alternative character-by-character comparison (for short strings)
    function _compareByCharacter(string memory a, string memory b) internal pure returns (bool) {
        bytes memory bytesA = bytes(a);
        bytes memory bytesB = bytes(b);
        
        if (bytesA.length != bytesB.length) {
            return false;
        }
        
        for (uint i = 0; i < bytesA.length; i++) {
            if (bytesA[i] != bytesB[i]) {
                return false;
            }
        }
        return true;
    }
    
    // Smart comparison (chooses method based on length)
    function smartCompare(string memory a, string memory b) public returns (bool) {
        bytes memory bytesA = bytes(a);
        
        // Use character comparison for very short strings
        if (bytesA.length <= 2) {
            return _compareByCharacter(a, b);
        }
        
        // Use hash comparison for longer strings
        return _compareWithLengthCheck(a, b);
    }
}
```

### Comparison Methods
1. **Hash-based**:
   - Use keccak256 hashing
   - Constant gas cost
   - Best for longer strings

2. **Character-by-character**:
   - Direct byte comparison
   - Linear gas cost
   - Efficient for very short strings

3. **Hybrid**:
   - Length-based method selection
   - Optimized gas usage
   - Best of both approaches

### Key Points
- Check lengths before hashing
- Consider string encoding
- Monitor gas consumption
- Handle empty strings
- Use appropriate method

### Common Patterns
```solidity
// Gas-optimized comparison
function optimizedCompare(string memory a, string memory b) internal pure returns (bool) {
    bytes memory bytesA = bytes(a);
    bytes memory bytesB = bytes(b);
    
    if (bytesA.length != bytesB.length) {
        return false;
    }
    
    return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
}

// Short string comparison
function shortStringCompare(string memory a, string memory b) internal pure returns (bool) {
    bytes memory bytesA = bytes(a);
    bytes memory bytesB = bytes(b);
    
    if (bytesA.length != bytesB.length || bytesA.length > 2) {
        return false;
    }
    
    if (bytesA.length == 1) {
        return bytesA[0] == bytesB[0];
    }
    return bytesA[0] == bytesB[0] && bytesA[1] == bytesB[1];
}

// Memory efficient comparison
function memoryEfficientCompare(
    string memory a, 
    string memory b
) internal pure returns (bool) {
    return bytes(a).length == bytes(b).length && 
           keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
}
```

### Anti-patterns
```solidity
// DON'T: Skip length check
function inefficientCompare(string a, string b) {
    return keccak256(a) == keccak256(b);  // Wastes gas on different lengths
}

// DON'T: Always use character comparison
function expensiveCompare(string a, string b) {
    bytes memory bytesA = bytes(a);
    bytes memory bytesB = bytes(b);
    // Expensive for long strings
    for (uint i = 0; i < bytesA.length; i++) {
        if (bytesA[i] != bytesB[i]) return false;
    }
    return true;
}

// DON'T: Unnecessary type conversions
function wastefulCompare(string a, string b) {
    string memory tempA = a;  // Unnecessary conversion
    string memory tempB = b;
    return keccak256(tempA) == keccak256(tempB);
}

// DON'T: Redundant operations
function redundantCompare(string a, string b) {
    if (keccak256(a) == keccak256(b)) {  // Hash comparison first
        if (bytes(a).length == bytes(b).length) {  // Length check after
            return true;
        }
    }
    return false;
}
```

## Tight Variable Packing Pattern

### Core Principles
- Optimize storage layout for gas efficiency
- Pack multiple small variables into single slots
- Order variables strategically
- Use minimum required sizes for types

### Implementation Guide
```solidity
contract TightPacking {
    // Events
    event StructCreated(uint256 gasUsed);
    
    // Efficient packing example
    struct PackedStruct {
        // Slot 1: 1 + 1 + 1 + 1 + 1 + 1 + 1 + 1 = 8 bytes
        uint8 id;          // 1 byte
        uint8 category;    // 1 byte
        uint8 status;      // 1 byte
        uint8 flags;       // 1 byte
        bytes1 code1;      // 1 byte
        bytes1 code2;      // 1 byte
        bytes1 code3;      // 1 byte
        bytes1 code4;      // 1 byte
        
        // Slot 2: 16 + 16 = 32 bytes
        uint128 amount;    // 16 bytes
        uint128 balance;   // 16 bytes
        
        // Slot 3: 20 bytes
        address owner;     // 20 bytes
        
        // Slot 4: 32 bytes
        bytes32 data;      // 32 bytes
    }
    
    // State variables packing
    uint8 public constant VERSION = 1;     // 1 byte
    uint16 public constant MAX_VALUE = 1000; // 2 bytes
    uint32 public timestamp;               // 4 bytes
    address public immutable admin;        // 20 bytes
    // Above variables pack into single 32 byte slot
    
    PackedStruct[] public items;
    
    constructor() {
        admin = msg.sender;
        timestamp = uint32(block.timestamp);
    }
    
    function createPackedStruct() external returns (uint256) {
        uint256 startGas = gasleft();
        
        PackedStruct memory newStruct = PackedStruct({
            id: 1,
            category: 2,
            status: 1,
            flags: 0,
            code1: 0x01,
            code2: 0x02,
            code3: 0x03,
            code4: 0x04,
            amount: 1000,
            balance: 2000,
            owner: msg.sender,
            data: bytes32(0)
        });
        
        items.push(newStruct);
        
        uint256 gasUsed = startGas - gasleft();
        emit StructCreated(gasUsed);
        return gasUsed;
    }
}
```

### Storage Layout
1. **Single Slot Packing**:
   - 32 bytes per slot
   - Pack small variables together
   - Order by size ascending
   - Consider alignment

2. **Multi-Slot Structures**:
   - Group related variables
   - Minimize slot usage
   - Consider access patterns
   - Optimize hot variables

3. **Array Storage**:
   - Fixed arrays pack tightly
   - Dynamic arrays start new slots
   - Consider element sizes
   - Balance packing vs access

### Key Points
- Check variable sizes
- Order by ascending size
- Monitor slot usage
- Consider access patterns
- Document storage layout

### Common Patterns
```solidity
// Efficient state variable packing
contract StateVarPacking {
    uint8 public constant VERSION = 1;     // 1 byte
    uint16 public constant MAX_USERS = 1000; // 2 bytes
    uint32 public lastUpdate;              // 4 bytes
    address public owner;                  // 20 bytes
    // Total: 27 bytes (fits in one slot)
    
    // Next slot starts here
    uint256 public totalSupply;           // 32 bytes
}

// Efficient struct packing
contract StructPacking {
    struct UserInfo {
        uint8 status;      // 1 byte
        uint16 grade;      // 2 bytes
        uint32 lastLogin;  // 4 bytes
        address wallet;    // 20 bytes
        // Total: 27 bytes (fits in one slot)
    }
    
    struct TokenInfo {
        uint8 decimals;    // 1 byte
        uint8 category;    // 1 byte
        uint16 id;        // 2 bytes
        uint32 created;   // 4 bytes
        address token;    // 20 bytes
        // Total: 28 bytes (fits in one slot)
    }
}

// Memory efficient array
contract ArrayPacking {
    // Fixed size array packing
    uint8[32] public flags;  // Packs 32 flags into one slot
    
    // Efficient dynamic array
    struct MiniData {
        uint8 x;  // 1 byte
        uint8 y;  // 1 byte
        uint8 z;  // 1 byte
    }
    MiniData[] public dataArray;  // Each 3 elements pack into one slot
}
```

### Anti-patterns
```solidity
// DON'T: Inefficient ordering
struct BadPacking {
    uint8 a;      // 1 byte
    uint256 b;    // 32 bytes (forces new slot)
    uint8 c;      // 1 byte (forces new slot)
    uint256 d;    // 32 bytes (forces new slot)
}

// DON'T: Oversized variables
struct WastefulTypes {
    uint256 smallNumber;  // Uses 32 bytes for small values
    uint256 timestamp;    // uint32 would suffice
    uint256 status;      // uint8 would suffice
}

// DON'T: Unnecessary gaps
struct GappyStruct {
    uint8 a;     // 1 byte
    uint256 b;   // Forces 31 byte gap
    uint8 c;     // Forces new slot
}

// DON'T: Ignoring alignment
struct UnalignedStruct {
    uint24 a;    // 3 bytes
    uint256 b;   // Forces 29 byte gap
    uint24 c;    // Forces new slot
}
```

## Memory Array Building Pattern

### Core Principles
- Build arrays in memory for gas-efficient data retrieval
- Use view functions to avoid storage costs
- Aggregate data without state modifications
- Optimize storage layout for queries

### Implementation Guide
```solidity
contract MemoryArrayBuilder {
    // Events
    event ItemAdded(uint256 indexed id, address indexed owner);
    
    // Data structures
    struct Item {
        string name;
        string category;
        address owner;
        uint32 zipcode;
        uint32 price;
        bool active;
    }
    
    // Storage
    Item[] public items;
    mapping(address => uint256) public ownerItemCount;
    mapping(string => uint256) public categoryItemCount;
    
    // Memory array builders
    function getItemsByOwner(address owner) external view returns (uint256[] memory) {
        // Create fixed-size array in memory
        uint256[] memory result = new uint256[](ownerItemCount[owner]);
        uint256 counter = 0;
        
        // Build array by filtering items
        for (uint256 i = 0; i < items.length; i++) {
            if (items[i].owner == owner && items[i].active) {
                result[counter] = i;
                counter++;
            }
        }
        
        return result;
    }
    
    function getItemsByCategory(string memory category) external view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](categoryItemCount[category]);
        uint256 counter = 0;
        
        for (uint256 i = 0; i < items.length; i++) {
            if (keccak256(bytes(items[i].category)) == keccak256(bytes(category)) && 
                items[i].active) {
                result[counter] = i;
                counter++;
            }
        }
        
        return result;
    }
    
    // Complex query example
    function getItemsByOwnerAndPrice(
        address owner,
        uint32 minPrice,
        uint32 maxPrice
    ) external view returns (uint256[] memory) {
        // First get count for array size
        uint256 count = 0;
        for (uint256 i = 0; i < items.length; i++) {
            if (items[i].owner == owner && 
                items[i].price >= minPrice && 
                items[i].price <= maxPrice &&
                items[i].active) {
                count++;
            }
        }
        
        // Build result array
        uint256[] memory result = new uint256[](count);
        uint256 counter = 0;
        
        for (uint256 i = 0; i < items.length; i++) {
            if (items[i].owner == owner && 
                items[i].price >= minPrice && 
                items[i].price <= maxPrice &&
                items[i].active) {
                result[counter] = i;
                counter++;
            }
        }
        
        return result;
    }
    
    // Helper functions
    function addItem(
        string memory name,
        string memory category,
        uint32 zipcode,
        uint32 price
    ) external {
        items.push(Item({
            name: name,
            category: category,
            owner: msg.sender,
            zipcode: zipcode,
            price: price,
            active: true
        }));
        
        ownerItemCount[msg.sender]++;
        categoryItemCount[category]++;
        
        emit ItemAdded(items.length - 1, msg.sender);
    }
}
```

### Query Types
1. **Simple Filtering**:
   - Single condition queries
   - Fixed array size from mapping
   - Linear iteration pattern

2. **Complex Filtering**:
   - Multiple conditions
   - Dynamic array sizing
   - Nested iteration support

3. **Aggregation Queries**:
   - Group by operations
   - Count aggregations
   - Range filtering

### Key Points
- Use view functions for free queries
- Pre-calculate array sizes
- Maintain accurate counters
- Consider pagination for large datasets
- Optimize iteration patterns

### Common Patterns
```solidity
// Efficient counter management
contract CounterManagement {
    mapping(address => uint256) public ownerCounts;
    
    function incrementCount(address owner) internal {
        ownerCounts[owner]++;
    }
    
    function decrementCount(address owner) internal {
        if (ownerCounts[owner] > 0) {
            ownerCounts[owner]--;
        }
    }
}

// Paginated queries
contract PaginatedQueries {
    function getItemsPage(
        uint256 offset,
        uint256 limit
    ) external view returns (uint256[] memory) {
        require(offset < items.length, "Invalid offset");
        
        uint256 size = limit;
        if (offset + limit > items.length) {
            size = items.length - offset;
        }
        
        uint256[] memory result = new uint256[](size);
        for (uint256 i = 0; i < size; i++) {
            result[i] = offset + i;
        }
        
        return result;
    }
}

// Multi-index queries
contract MultiIndexQueries {
    mapping(bytes32 => uint256[]) private categoryIndex;
    
    function indexItem(uint256 id, string memory category) internal {
        bytes32 key = keccak256(bytes(category));
        categoryIndex[key].push(id);
    }
    
    function queryIndex(string memory category) external view 
        returns (uint256[] memory) 
    {
        bytes32 key = keccak256(bytes(category));
        return categoryIndex[key];
    }
}
```

### Anti-patterns
```solidity
// DON'T: Return full structs array
function getAllItems() external view returns (Item[] memory) {
    return items;  // Expensive and may hit gas limits
}

// DON'T: Unnecessary storage writes
function updateCounter(address owner) external {
    ownerItemCount[owner] = getItemCount(owner);  // Wasteful gas
}

// DON'T: Unbounded iteration
function queryWithoutLimit() external view returns (uint256[] memory) {
    // May run out of gas for large datasets
    return getAllActiveItems();
}

// DON'T: Redundant storage reads
function inefficientQuery(address owner) external view 
    returns (uint256[] memory) 
{
    Item memory item;  // Unnecessary memory allocation
    uint256[] memory result = new uint256[](ownerItemCount[owner]);
    
    for (uint256 i = 0; i < items.length; i++) {
        item = items[i];  // Redundant storage read
        if (item.owner == owner) {
            // Process item
        }
    }
    return result;
}
``` 

> Claude must follow these patterns when implementing Solidity economic patterns.

</solidity_economic_pattern>

