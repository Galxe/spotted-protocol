// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {
    ECDSAStakeRegistryStorage, Quorum, StrategyParams
} from "../avs/ECDSAStakeRegistryStorage.sol";
import {IAbridgeMessageHandler} from "./IAbridge.sol";
interface IRegistryStateReceiver is IAbridgeMessageHandler {
    
    enum MessageType {
        REGISTER,
        DEREGISTER,
        UPDATE_SIGNING_KEY,
        UPDATE_OPERATORS,
        UPDATE_QUORUM,
        UPDATE_MIN_WEIGHT,
        UPDATE_THRESHOLD,
        UPDATE_OPERATORS_QUORUM
    }
    
}
