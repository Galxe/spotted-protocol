// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ReentrancyGuard} from "@openzeppelin-v5.0.0/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/IAllocationManager.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IMainChainVerifier.sol";
import "../interfaces/IStateDisputeResolver.sol";
import "../interfaces/ISpottedServiceManager.sol";

contract StateDisputeResolver is
    IStateDisputeResolver,
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuard
{
    // Constants
    uint256 public constant UNVERIFIED = type(uint256).max;
    uint256 public constant CHALLENGE_WINDOW = 7200; // 24 hours
    uint256 public constant CHALLENGE_BOND = 1 ether; // 1e18 wei
    uint256 public constant CHALLENGE_PERIOD = 7200; // 24 hours

    IAllocationManager public immutable allocationManager;

    // New state variables
    uint32 public currentOperatorSetId;
    IStrategy[] public slashableStrategies;
    uint256 public slashAmount; // In WAD format (1e18 = 100%)
    ISpottedServiceManager public serviceManager;

    // Active challenges
    mapping(bytes32 => Challenge) private challenges;
    mapping(address => OperatorState) private operators;
    // Add mapping for StateManager addresses
    mapping(uint256 => address) public stateManagers;

    // single mainChainVerifier address
    address public mainChainVerifier;

    modifier onlyServiceManager() {
        if (msg.sender != address(serviceManager)) {
            revert StateDisputeResolver__CallerNotServiceManager();
        }
        _;
    }

    modifier onlyMainChainVerifier() {
        if (msg.sender != mainChainVerifier) {
            revert StateDisputeResolver__CallerNotMainChainVerifier();
        }
        _;
    }

    constructor(
        address _allocationManager
    ) {
        allocationManager = IAllocationManager(_allocationManager);
    }

    receive() external payable {}

    function initialize(uint32 _operatorSetId, uint256 _slashAmount) external initializer {
        __Ownable_init();
        currentOperatorSetId = _operatorSetId;
        slashAmount = _slashAmount;
    }

    // submit challenge for invalid state claim
    function submitChallenge(address operator, uint32 taskNum) external payable nonReentrant {
        // check bond amount using constant
        if (msg.value < CHALLENGE_BOND) {
            revert StateDisputeResolver__InsufficientBond();
        }

        // get task response
        ISpottedServiceManager.TaskResponse memory response =
            ISpottedServiceManager(serviceManager).getTaskResponse(operator, taskNum);

        // verify task exists
        if (response.responseBlock == 0) {
            revert StateDisputeResolver__TaskNotFound();
        }

        // verify not already challenged or resolved
        if (response.challenged || response.resolved) {
            revert StateDisputeResolver__TaskAlreadyProcessed();
        }

        // verify within challenge window
        if (block.number > response.responseBlock + CHALLENGE_WINDOW) {
            revert StateDisputeResolver__ChallengeWindowExpired();
        }

        if (!operators[operator].isRegistered) {
            revert StateDisputeResolver__OperatorNotRegistered();
        }

        bytes32 challengeId = keccak256(abi.encodePacked(operator, taskNum));

        if (challenges[challengeId].challenger != address(0)) {
            revert StateDisputeResolver__ChallengeAlreadyExists();
        }

        challenges[challengeId] = Challenge({
            challenger: msg.sender,
            deadline: block.number + CHALLENGE_PERIOD,
            resolved: false,
            claimedState: response.task.value,
            actualState: UNVERIFIED,
            verified: false
        });

        // Mark task as challenged
        ISpottedServiceManager(serviceManager).handleChallengeSubmission(operator, taskNum);

        emit ChallengeSubmitted(challengeId, msg.sender);
    }

    // everyone can call resolves submitted challenge
    function resolveChallenge(address operator, uint32 taskNum) external nonReentrant {
        bytes32 challengeId = keccak256(abi.encodePacked(operator, taskNum));
        Challenge storage challenge = challenges[challengeId];

        if (challenge.resolved) {
            revert StateDisputeResolver__ChallengeAlreadyResolved();
        }

        if (block.number <= challenge.deadline) {
            revert StateDisputeResolver__ChallengePeriodActive();
        }

        // get task response to get chainId
        ISpottedServiceManager.TaskResponse memory response =
            ISpottedServiceManager(serviceManager).getTaskResponse(operator, taskNum);

        // get verified state from MainChainVerifier
        (uint256 actualValue, bool exist) = IMainChainVerifier(mainChainVerifier).getVerifiedState(
            response.task.chainId, response.task.user, response.task.key, response.task.blockNumber
        );

        if (!exist) {
            revert StateDisputeResolver__StateNotVerified();
        }
        bool challengeSuccessful = challenge.claimedState != actualValue;
        // slash operator if claimed state does not match actual state
        if (challengeSuccessful) {
            _slashOperator(operator, challengeId);
            payable(challenge.challenger).transfer(CHALLENGE_BOND);
        } else {
            // return half of bond to challenger
            payable(challenge.challenger).transfer(CHALLENGE_BOND / 2);
        }

        challenge.resolved = true;
        challenge.actualState = actualValue;
        challenge.verified = true;

        // Notify service manager of resolution
        ISpottedServiceManager(serviceManager).handleChallengeResolution(
            operator, taskNum, challengeSuccessful
        );

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

    function setStateManager(uint256 chainId, address stateManager) external onlyOwner {
        if (stateManager == address(0)) {
            revert StateDisputeResolver__InvalidStateManagerAddress();
        }
        stateManagers[chainId] = stateManager;
        emit StateManagerSet(chainId, stateManager);
    }

    function setServiceManager(
        address _serviceManager
    ) external onlyOwner {
        require(_serviceManager != address(0), "Invalid address");
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
        mainChainVerifier = _verifier;
        emit MainChainVerifierSet(_verifier);
    }

    function getStateManager(
        uint256 chainId
    ) external view returns (address) {
        address stateManager = stateManagers[chainId];
        if (stateManager == address(0)) {
            revert StateDisputeResolver__StateManagerNotConfigured();
        }
        return stateManager;
    }

    function getChallenge(
        bytes32 challengeId
    ) external view returns (Challenge memory) {
        return challenges[challengeId];
    }

    function getOperator(
        address operator
    ) external view returns (OperatorState memory) {
        return operators[operator];
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

        OperatorState storage state = operators[operator];
        state.isSlashed = true;

        emit OperatorSlashed(operator, challengeId);
    }
}
