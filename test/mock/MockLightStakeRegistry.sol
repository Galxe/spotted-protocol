// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ILightStakeRegistry} from "../../src/interfaces/ILightStakeRegistry.sol";
import {IEpochManager} from "../../src/interfaces/IEpochManager.sol";
import {Quorum, StrategyParams} from "../../src/interfaces/IECDSAStakeRegistryEventsAndErrors.sol";

contract MockLightStakeRegistry is ILightStakeRegistry {
    bool public shouldRevert;
    Quorum internal _quorum;
    mapping(address => bool) internal _operatorRegistered;
    mapping(address => address) internal _operatorSigningKeys;
    mapping(address => uint256) internal _operatorWeights;
    uint256 internal _totalWeight;
    uint256 internal _thresholdWeight;
    uint256 internal _minimumWeight;

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function setQuorum(Quorum memory newQuorum) external {
        delete _quorum.strategies;
        for(uint256 i = 0; i < newQuorum.strategies.length; i++) {
            _quorum.strategies.push(newQuorum.strategies[i]);
        }
    }

    function setOperatorSigningKey(address operator, address signingKey) external {
        _operatorSigningKeys[operator] = signingKey;
    }

    function setOperatorWeight(address operator, uint256 weight) external {
        _operatorWeights[operator] = weight;
    }

    function setTotalWeight(uint256 weight) external {
        _totalWeight = weight;
    }

    function setThresholdWeight(uint256 weight) external {
        _thresholdWeight = weight;
    }

    function setMinimumWeight(uint256 weight) external {
        _minimumWeight = weight;
    }

    function registerOperator(address operator) external {
        _operatorRegistered[operator] = true;
    }

    function quorum() external view returns (Quorum memory) {
        if (shouldRevert) revert("MockLightStakeRegistry: quorum reverted");
        return _quorum;
    }

    function getLastestOperatorSigningKey(address _operator) external view returns (address) {
        if (shouldRevert) revert("MockLightStakeRegistry: getLastestOperatorSigningKey reverted");
        return _operatorSigningKeys[_operator];
    }

    function getOperatorSigningKeyAtEpoch(address _operator, uint32 /*_epochNumber*/) external view returns (address) {
        if (shouldRevert) revert("MockLightStakeRegistry: getOperatorSigningKeyAtEpoch reverted");
        return _operatorSigningKeys[_operator];
    }

    function getLastCheckpointOperatorWeight(address _operator) external view returns (uint256) {
        if (shouldRevert) revert("MockLightStakeRegistry: getLastCheckpointOperatorWeight reverted");
        return _operatorWeights[_operator];
    }

    function getLastCheckpointTotalWeight() external view returns (uint256) {
        if (shouldRevert) revert("MockLightStakeRegistry: getLastCheckpointTotalWeight reverted");
        return _totalWeight;
    }

    function getLastCheckpointThresholdWeight() external view returns (uint256) {
        if (shouldRevert) revert("MockLightStakeRegistry: getLastCheckpointThresholdWeight reverted");
        return _thresholdWeight;
    }

    function getOperatorWeightAtEpoch(address _operator, uint32 /*_epochNumber*/) external view returns (uint256) {
        if (shouldRevert) revert("MockLightStakeRegistry: getOperatorWeightAtEpoch reverted");
        return _operatorWeights[_operator];
    }

    function getTotalWeightAtEpoch(uint32 /*_epochNumber*/) external view returns (uint256) {
        if (shouldRevert) revert("MockLightStakeRegistry: getTotalWeightAtEpoch reverted");
        return _totalWeight;
    }

    function getLastCheckpointThresholdWeightAtEpoch(uint32 /*_epochNumber*/) external view returns (uint256) {
        if (shouldRevert) revert("MockLightStakeRegistry: getLastCheckpointThresholdWeightAtEpoch reverted");
        return _thresholdWeight;
    }

    function operatorRegistered(address _operator) external view returns (bool) {
        if (shouldRevert) revert("MockLightStakeRegistry: operatorRegistered reverted");
        return _operatorRegistered[_operator];
    }

    function minimumWeight() external view returns (uint256) {
        if (shouldRevert) revert("MockLightStakeRegistry: minimumWeight reverted");
        return _minimumWeight;
    }

    function isValidSignature(bytes32 /*_dataHash*/, bytes memory /*_signatureData*/) external view returns (bytes4) {
        if (shouldRevert) revert("MockLightStakeRegistry: isValidSignature reverted");
        return 0x1626ba7e; // ERC1271 magic value
    }

    function processEpochUpdate(IEpochManager.StateUpdate[] memory /*updates*/) external view{
        if (shouldRevert) revert("MockLightStakeRegistry: processEpochUpdate reverted");
    }
} 