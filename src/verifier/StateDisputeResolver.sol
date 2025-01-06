// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ReentrancyGuard} from "@openzeppelin-v5.0.0/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/IAllocationManager.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IMainChainVerifier.sol";
import "../interfaces/IStateDisputeResolver.sol";
import "../interfaces/ISpottedServiceManager.sol";
import {EIP712Upgradeable} from
    "lib/eigenlayer-middleware/lib/eigenlayer-contracts/lib/openzeppelin-contracts-upgradeable-v4.9.0/contracts/utils/cryptography/EIP712Upgradeable.sol";

contract StateDisputeResolver is
    IStateDisputeResolver,
    ReentrancyGuard,
    EIP712Upgradeable,
    Ownable
{
    // Constants
    uint256 public constant UNVERIFIED = type(uint256).max;
    uint256 public constant CHALLENGE_WINDOW = 7200; // 24 hours
    uint256 public constant CHALLENGE_BOND = 1 ether; // 1e18 wei
    uint256 public constant CHALLENGE_PERIOD = 7200; // 24 hours

    IAllocationManager public allocationManager;
    IMainChainVerifier public mainChainVerifier;

    address public challengeSubmitter;
    uint32 public currentOperatorSetId;
    IStrategy[] public slashableStrategies;
    uint256 public slashAmount; // In WAD format (1e18 = 100%)
    ISpottedServiceManager public serviceManager;

    bytes32 private constant STATE_TYPEHASH = keccak256(
        "State(address user,uint32 chainId,uint64 blockNumber,uint48 timestamp,uint256 key,uint256 value)"
    );
    // Active challenges
    mapping(bytes32 => Challenge) private challenges;

    // single mainChainVerifier address

    modifier onlyServiceManager() {
        if (msg.sender != address(serviceManager)) {
            revert StateDisputeResolver__CallerNotServiceManager();
        }
        _;
    }

    modifier onlyMainChainVerifier() {
        if (msg.sender != address(mainChainVerifier)) {
            revert StateDisputeResolver__CallerNotMainChainVerifier();
        }
        _;
    }

    modifier onlyChallengeSubmitter() {
        if (msg.sender != challengeSubmitter) {
            revert StateDisputeResolver__CallerNotChallengeSubmitter();
        }
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _allocationManager,
        uint32 _operatorSetId,
        uint256 _slashAmount
    ) external initializer {
        __EIP712_init("SpottedStateResolver", "v1");

        // Initialize contract state
        allocationManager = IAllocationManager(_allocationManager);
        currentOperatorSetId = _operatorSetId;
        slashAmount = _slashAmount;
    }

    receive() external payable {}

    // submit challenge for invalid state claim
    function submitChallenge(
        State calldata state,
        address[] calldata operators,
        bytes[] calldata signatures
    ) external payable onlyChallengeSubmitter nonReentrant {
        // check bond amount using constant
        if (msg.value < CHALLENGE_BOND) {
            revert StateDisputeResolver__InsufficientBond();
        }

        // Check arrays length match
        if (operators.length != signatures.length || operators.length == 0) {
            revert StateDisputeResolver__InvalidSignaturesLength();
        }

        // Generate EIP712 hash
        bytes32 structHash = keccak256(
            abi.encode(
                STATE_TYPEHASH,
                state.user,
                state.chainId,
                state.blockNumber,
                state.timestamp,
                state.key,
                state.value
            )
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        uint256 signaturesLength = signatures.length;
        // Verify each signature and check operators match
        for (uint256 i = 0; i < signaturesLength;) {
            address recoveredSigner = ECDSA.recover(hash, signatures[i]);
            if (recoveredSigner != operators[i]) {
                revert StateDisputeResolver__InvalidSignature();
            }
            // Check for duplicate operators
            for (uint256 j = 0; j < i; j++) {
                if (operators[j] == recoveredSigner) {
                    revert StateDisputeResolver__DuplicateOperator();
                }
            }
            unchecked {
                ++i;
            }
        }

        // Generate challenge ID
        bytes32 challengeId =
            keccak256(abi.encodePacked(state.user, state.chainId, state.blockNumber, state.key));

        if (challenges[challengeId].challenger != address(0)) {
            revert StateDisputeResolver__ChallengeAlreadyExists();
        }

        challenges[challengeId] = Challenge({
            challenger: msg.sender,
            deadline: block.number + CHALLENGE_PERIOD,
            resolved: false,
            state: state,
            operators: operators,
            actualState: UNVERIFIED,
            verified: false
        });

        emit ChallengeSubmitted(challengeId, msg.sender);
    }

    // everyone can call resolves submitted challenge
    function resolveChallenge(
        bytes32 challengeId
    ) external {
        Challenge storage challenge = challenges[challengeId];
        if (challenge.resolved) {
            revert StateDisputeResolver__ChallengeAlreadyResolved();
        }
        if (block.number <= challenge.deadline) {
            revert StateDisputeResolver__ChallengePeriodActive();
        }

        // Get verified state from MainChainVerifier
        (uint256 actualValue, bool exist) = mainChainVerifier.getVerifiedState(
            challenge.state.chainId,
            challenge.state.user,
            challenge.state.key,
            challenge.state.blockNumber
        );

        if (!exist) {
            revert StateDisputeResolver__StateNotVerified();
        }

        bool challengeSuccessful = challenge.state.value != actualValue;

        // Slash operators if challenge successful
        if (challengeSuccessful) {
            for (uint256 i = 0; i < challenge.operators.length; i++) {
                _slashOperator(challenge.operators[i], challengeId);
            }
            payable(msg.sender).transfer(CHALLENGE_BOND);
        }

        challenge.resolved = true;
        challenge.actualState = actualValue;
        challenge.verified = true;

        emit ChallengeResolved(challengeId, challengeSuccessful);
    }

    function setOperatorSetId(
        uint32 newSetId
    ) external onlyOwner {
        currentOperatorSetId = newSetId;
        emit OperatorSetIdUpdated(newSetId);
    }

    function setSlashableStrategies(
        IStrategy[] calldata strategies
    ) external onlyOwner {
        if (strategies.length == 0) {
            revert StateDisputeResolver__EmptyStrategiesArray();
        }
        delete slashableStrategies;
        uint256 strategiesLength = strategies.length;
        for (uint256 i = 0; i < strategiesLength;) {
            slashableStrategies.push(strategies[i]);
            unchecked {
                ++i;
            }
        }
        emit SlashableStrategiesUpdated(strategies);
    }

    function setSlashAmount(
        uint256 newAmount
    ) external onlyOwner {
        if (newAmount > 1e18) {
            revert StateDisputeResolver__InvalidSlashAmount();
        }
        slashAmount = newAmount;
        emit SlashAmountUpdated(newAmount);
    }

    function setServiceManager(
        address _serviceManager
    ) external onlyOwner {
        if (_serviceManager == address(0)) {
            revert StateDisputeResolver__InvalidServiceManagerAddress();
        }
        serviceManager = ISpottedServiceManager(_serviceManager);
        emit ServiceManagerSet(_serviceManager);
    }

    // set mainChainVerifier address
    function setMainChainVerifier(
        address _verifier
    ) external onlyOwner {
        if (_verifier == address(0)) {
            revert StateDisputeResolver__InvalidVerifierAddress();
        }
        mainChainVerifier = IMainChainVerifier(_verifier);
        emit MainChainVerifierSet(_verifier);
    }

    function getChallenge(
        bytes32 challengeId
    ) external view returns (Challenge memory) {
        return challenges[challengeId];
    }

    // internal function to slash operator
    function _slashOperator(address operator, bytes32 challengeId) private {
        if (slashableStrategies.length == 0) {
            revert StateDisputeResolver__EmptyStrategiesArray();
        }

        uint256[] memory wadsToSlash = new uint256[](slashableStrategies.length);
        uint256 strategiesLength = slashableStrategies.length;
        for (uint256 i = 0; i < strategiesLength;) {
            wadsToSlash[i] = slashAmount;
            unchecked {
                ++i;
            }
        }

        IAllocationManager.SlashingParams memory params = IAllocationManager.SlashingParams({
            operator: operator,
            operatorSetId: currentOperatorSetId,
            strategies: slashableStrategies,
            wadsToSlash: wadsToSlash,
            description: string(
                abi.encodePacked("Cross chain state verification failure-Challenge ID: ", challengeId)
            )
        });

        allocationManager.slashOperator(address(this), params);
        emit OperatorSlashed(operator, challengeId);
    }
}
