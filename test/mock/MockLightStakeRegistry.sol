// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ILightStakeRegistry} from "../../src/interfaces/ILightStakeRegistry.sol";
import {IERC1271Upgradeable} from "@openzeppelin-upgrades/contracts/interfaces/IERC1271Upgradeable.sol";

contract MockLightStakeRegistry is ILightStakeRegistry {
    bool public shouldRevert;
    
    // Storage mappings aligned with LightStakeRegistry
    mapping(uint32 => mapping(address => uint256)) internal _operatorWeightAtEpoch;
    mapping(uint32 => mapping(address => address)) internal _operatorSigningKeyAtEpoch;
    mapping(uint32 => uint256) internal _thresholdWeightAtEpoch;

    // Test helper functions
    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function setOperatorSigningKeyAtEpoch(
        address operator,
        uint32 epochNumber,
        address signingKey
    ) external {
        _operatorSigningKeyAtEpoch[epochNumber][operator] = signingKey;
    }

    function setOperatorWeightAtEpoch(
        address operator,
        uint32 epochNumber,
        uint256 weight
    ) external {
        _operatorWeightAtEpoch[epochNumber][operator] = weight;
    }

    function setThresholdWeightAtEpoch(
        uint32 epochNumber,
        uint256 weight
    ) external {
        _thresholdWeightAtEpoch[epochNumber] = weight;
    }

    // Interface implementations
    function initialize() external {
        if (shouldRevert) revert("MockLightStakeRegistry: initialize reverted");
    }

    function processEpochUpdate(bytes memory data) external {
        if (shouldRevert) revert("MockLightStakeRegistry: processEpochUpdate reverted");
        
        (
            uint32 epochNumber,
            address[] memory operators,
            address[] memory signingKeys,
            uint256[] memory weights,
            uint256 thresholdWeight
        ) = abi.decode(data, (uint32, address[], address[], uint256[], uint256));

        // Update threshold weight
        _thresholdWeightAtEpoch[epochNumber] = thresholdWeight;

        // Update operator data
        for(uint256 i = 0; i < operators.length; i++) {
            _operatorSigningKeyAtEpoch[epochNumber][operators[i]] = signingKeys[i];
            _operatorWeightAtEpoch[epochNumber][operators[i]] = weights[i];
        }
    }

    function getOperatorSigningKeyAtEpoch(
        address operator,
        uint32 epochNumber
    ) external view returns (address) {
        if (shouldRevert) revert("MockLightStakeRegistry: getOperatorSigningKeyAtEpoch reverted");
        return _operatorSigningKeyAtEpoch[epochNumber][operator];
    }

    function getOperatorWeightAtEpoch(
        address operator,
        uint32 epochNumber
    ) external view returns (uint256) {
        if (shouldRevert) revert("MockLightStakeRegistry: getOperatorWeightAtEpoch reverted");
        return _operatorWeightAtEpoch[epochNumber][operator];
    }

    function getThresholdWeightAtEpoch(
        uint32 epochNumber
    ) external view returns (uint256) {
        if (shouldRevert) revert("MockLightStakeRegistry: getThresholdWeightAtEpoch reverted");
        return _thresholdWeightAtEpoch[epochNumber];
    }

    function isValidSignature(
        bytes32 _dataHash,
        bytes memory _signatureData
    ) external view returns (bytes4) {
        if (shouldRevert) revert("MockLightStakeRegistry: isValidSignature reverted");
        return IERC1271Upgradeable.isValidSignature.selector;
    }
}
