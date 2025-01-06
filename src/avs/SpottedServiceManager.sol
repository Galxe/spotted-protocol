// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import {ECDSAServiceManagerBase} from
    "@eigenlayer-middleware/src/unaudited/ECDSAServiceManagerBase.sol";
import {ECDSAStakeRegistry} from "./ECDSAStakeRegistry.sol";
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

    // State variables
    IStateDisputeResolver public immutable disputeResolver;

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
        IPauserRegistry pauserRegistry
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ServiceManagerBase_init(initialOwner, address(pauserRegistry));
        _setRewardsInitiator(initialRewardsInitiator);
    }

    function registerOperatorToAVS(
        address operator,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external override(ECDSAServiceManagerBase, ISpottedServiceManager) onlyStakeRegistry {
        _registerOperatorToAVS(operator, operatorSignature);
    }

    function deregisterOperatorFromAVS(
        address operator
    ) external override(ECDSAServiceManagerBase, ISpottedServiceManager) onlyStakeRegistry {
        _deregisterOperatorFromAVS(operator);
    }

    function generateTaskId(
        address user,
        uint32 chainId,
        uint64 blockNumber,
        uint256 key,
        uint256 value,
        uint256 timestamp
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(user, chainId, blockNumber, timestamp, key, value));
    }
}
