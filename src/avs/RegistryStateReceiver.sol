// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IAbridgeMessageHandler} from "../interfaces/IAbridge.sol";
import {IAbridge} from "../interfaces/IAbridge.sol";
import {Ownable} from "@openzeppelin-v5.0.0/contracts/access/Ownable.sol";
import {ILightStakeRegistry} from "../interfaces/ILightStakeRegistry.sol";
import {IRegistryStateReceiver} from "../interfaces/IRegistryStateReceiver.sol";
import {ECDSAStakeRegistryStorage, Quorum} from "../avs/ECDSAStakeRegistryStorage.sol";
import {IEpochManager} from "../interfaces/IEpochManager.sol";

contract RegistryStateReceiver is IRegistryStateReceiver, Ownable {
    IAbridge public immutable abridge;
    address public immutable sender;
    ILightStakeRegistry public immutable stakeRegistry;

    uint256 private currentEpoch;

    function getCurrentEpoch() external view returns (uint256) {
        return currentEpoch;
    }

    constructor(
        address _abridge,
        address _sender,
        address _stakeRegistry,
        address _owner
    ) Ownable(_owner) {
        abridge = IAbridge(_abridge);
        sender = _sender;
        stakeRegistry = ILightStakeRegistry(_stakeRegistry);

        // call updateRoute and check return value
        abridge.updateRoute(sender, true);
    }

    function handleMessage(
        address from,
        bytes calldata message,
        bytes32 /*guid*/
    ) external returns (bytes4) {
        if (from != sender) revert RegistryStateReceiver__InvalidSender();

        // decode epoch and updates
        (uint256 epoch, IEpochManager.StateUpdate[] memory updates) =
            abi.decode(message, (uint256, IEpochManager.StateUpdate[]));

        // update current epoch
        currentEpoch = epoch;

        // process updates
        try stakeRegistry.processEpochUpdate(updates) {
            emit UpdateProcessed(epoch, updates.length);
        } catch {
            revert RegistryStateReceiver__BatchUpdateFailed();
        }

        return IAbridgeMessageHandler.handleMessage.selector;
    }

    // update routing settings
    function updateRoute(
        bool allowed
    ) external onlyOwner {
        // call updateRoute and check return value
        abridge.updateRoute(sender, allowed);
    }
}
