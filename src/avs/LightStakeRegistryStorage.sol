// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ILightStakeRegistry} from "../interfaces/ILightStakeRegistry.sol";
import {IRegistryStateReceiver} from "../interfaces/IRegistryStateReceiver.sol";

abstract contract LightStakeRegistryStorage is ILightStakeRegistry {
    IRegistryStateReceiver internal immutable REGISTRY_STATE_RECEIVER;
    
    /// @notice The total amount of multipliers to weigh stakes
    uint256 internal constant BPS = 10_000;

    /// @notice Maps epoch number to threshold weight
    mapping(uint32 => uint256) internal _thresholdWeightAtEpoch;

    /// @notice Maps epoch number to operator to weight
    mapping(uint32 => mapping(address => uint256)) internal _operatorWeightAtEpoch;

    /// @notice Maps epoch number to operator to signing key
    mapping(uint32 => mapping(address => address)) internal _operatorSigningKeyAtEpoch;

    constructor(address _registryStateReceiver) {
        REGISTRY_STATE_RECEIVER = IRegistryStateReceiver(_registryStateReceiver);
    }

    // slither-disable-next-line shadowing-state
    /// @dev Reserves storage slots for future upgrades
    uint256[40] private __gap;
}
