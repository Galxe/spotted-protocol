// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import {ECDSAServiceManagerBase} from
    "@eigenlayer-middleware/src/unaudited/ECDSAServiceManagerBase.sol";
import {ECDSAStakeRegistry} from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import {ECDSAUpgradeable} from
    "@openzeppelin-upgrades/contracts/utils/cryptography/ECDSAUpgradeable.sol";
import {IERC1271Upgradeable} from
    "@openzeppelin-upgrades/contracts/interfaces/IERC1271Upgradeable.sol";
import {PausableUpgradeable} from
    "@openzeppelin-upgrades/contracts/security/PausableUpgradeable.sol";
import {IPauserRegistry} from "@eigenlayer/contracts/interfaces/IPauserRegistry.sol";
import {ISignatureUtils} from "@eigenlayer/contracts/interfaces/ISignatureUtils.sol";
import {IStateDisputeResolver} from "../interfaces/IStateDisputeResolver.sol";
import "../interfaces/ISpottedServiceManager.sol";

contract SpottedServiceManager is
    Initializable,
    ECDSAServiceManagerBase,
    PausableUpgradeable,
    ISpottedServiceManager
{
    using ECDSAUpgradeable for bytes32;

    // Task tracking
    mapping(address => mapping(bytes32 => TaskResponse)) private _taskResponses;

    // State variables
    IStateDisputeResolver public immutable disputeResolver;

    // Task response confirmer mapping
    mapping(address => bool) public isTaskResponseConfirmer;

    modifier onlyTaskResponseConfirmer() {
        if (!isTaskResponseConfirmer[msg.sender]) {
            revert SpottedServiceManager__CallerNotTaskResponseConfirmer();
        }
        _;
    }

    modifier onlyDisputeResolver() {
        if (msg.sender != address(disputeResolver)) {
            revert SpottedServiceManager__CallerNotDisputeResolver();
        }
        _;
    }

    constructor(
        address _avsDirectory,
        address _stakeRegistry,
        address _rewardsCoordinator,
        address _delegationManager,
        address _disputeResolver
    )
        ECDSAServiceManagerBase(_avsDirectory, _stakeRegistry, _rewardsCoordinator, _delegationManager)
    {
        _disableInitializers();
        disputeResolver = IStateDisputeResolver(_disputeResolver);
    }

    function initialize(
        address initialOwner,
        address initialRewardsInitiator,
        IPauserRegistry pauserRegistry,
        address[] memory initialConfirmers
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ServiceManagerBase_init(initialOwner, address(pauserRegistry));
        _setRewardsInitiator(initialRewardsInitiator);

        // Set initial confirmers
        uint256 initialConfirmersLength = initialConfirmers.length;
        for (uint256 i = 0; i < initialConfirmersLength;) {
            _setTaskResponseConfirmer(initialConfirmers[i], true);
            unchecked {
                ++i;
            }
        }
    }

    function setTaskResponseConfirmer(address confirmer, bool status) external onlyOwner {
        _setTaskResponseConfirmer(confirmer, status);
    }

    function respondToTask(
        Task calldata task,
        bytes memory signatureData
    ) external override whenNotPaused onlyTaskResponseConfirmer {
        // 验证taskId是否正确生成
        bytes32 computedTaskId = generateTaskId(
            task.user,
            task.chainId,
            task.blockNumber,
            task.key,
            task.value
        );
        if (computedTaskId != task.taskId) {
            revert SpottedServiceManager__InvalidTaskId();
        }

        // Decode signature data
        (address[] memory operators,,) = abi.decode(signatureData, (address[], bytes[], uint32));

        // 直接使用 taskId 作为消息哈希
        bytes32 ethSignedMessageHash = task.taskId.toEthSignedMessageHash();
        bytes4 magicValue = IERC1271Upgradeable.isValidSignature.selector;

        // verify quorum signatures
        if (
            magicValue
                != ECDSAStakeRegistry(stakeRegistry).isValidSignature(
                    ethSignedMessageHash, signatureData
                )
        ) {
            revert SpottedServiceManager__InvalidSignature();
        }

        // record response for each signing operator
        uint256 operatorsLength = operators.length;
        for (uint256 i = 0; i < operatorsLength;) {
            _taskResponses[operators[i]][task.taskId] = TaskResponse({
                task: task,
                responseBlock: uint64(block.number),
                challenged: false,
                resolved: false
            });
            unchecked {
                ++i;
            }
        }

        emit TaskResponded(task.taskId, task, msg.sender);
    }

    function handleChallengeSubmission(
        address operator,
        bytes32 taskId
    ) external onlyDisputeResolver {
        TaskResponse storage response = _taskResponses[operator][taskId];
        if (response.challenged) {
            revert SpottedServiceManager__TaskAlreadyChallenged();
        }
        response.challenged = true;
        emit TaskChallenged(operator, taskId);
    }

    function handleChallengeResolution(
        address operator,
        bytes32 taskId,
        bool challengeSuccessful
    ) external onlyDisputeResolver {
        TaskResponse storage response = _taskResponses[operator][taskId];
        if (!response.challenged) {
            revert SpottedServiceManager__TaskNotChallenged();
        }
        if (response.resolved) {
            revert SpottedServiceManager__TaskAlreadyResolved();
        }

        response.resolved = true;
        emit ChallengeResolved(operator, taskId, challengeSuccessful);
    }

    function registerOperatorToAVS(
        address operator,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external override onlyStakeRegistry {
        _registerOperatorToAVS(operator, operatorSignature);
    }

    function getTaskResponse(
        address operator,
        bytes32 taskId
    ) external view override returns (TaskResponse memory) {
        return _taskResponses[operator][taskId];
    }
    
    function generateTaskId(
        address user,
        uint32 chainId,
        uint64 blockNumber,
        uint256 key,
        uint256 value
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            user,
            chainId,
            blockNumber,
            key,
            value
        ));
    }

    function _setTaskResponseConfirmer(address confirmer, bool status) internal {
        if (confirmer == address(0)) revert SpottedServiceManager__InvalidAddress();
        isTaskResponseConfirmer[confirmer] = status;
        emit TaskResponseConfirmerSet(confirmer, status);
    }
}
