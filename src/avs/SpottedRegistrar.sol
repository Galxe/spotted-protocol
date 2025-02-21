// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.27;

import {ISpottedRegistrar} from "../interfaces/ISpottedRegistrar.sol";
import {IAllocationManager} from "eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";
import {Ownable} from "@openzeppelin-v5.0.0/contracts/access/Ownable.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {OperatorSet} from "eigenlayer-contracts/src/contracts/libraries/OperatorSetLib.sol";
import {IECDSAStakeRegistry} from "../interfaces/IECDSAStakeRegistry.sol";

contract SpottedRegistrar is ISpottedRegistrar, Ownable {

    IAllocationManager public allocationManager;
    IECDSAStakeRegistry public immutable stakeRegistry;

    constructor(
        address _allocationManager, 
        address _stakeRegistry
    ) Ownable(msg.sender) {

        allocationManager = IAllocationManager(_allocationManager);
        stakeRegistry = IECDSAStakeRegistry(_stakeRegistry);
    }

    modifier onlyAllocationManager() {
        if(msg.sender != address(allocationManager)) {
            revert SpottedRegistrar__OnlyAllocationManager();
        }
        _;
    }

    modifier checkOperatorSetId(uint32[] calldata operatorSetIds) {
        if(operatorSetIds.length != 1 || operatorSetIds[0] != stakeRegistry.getCurrentOperatorSetId()) {
            revert SpottedRegistrar__InvalidOperatorSetIds();
        }
        _;
    }

    function registerOperator(
        address operator,
        uint32[] calldata operatorSetIds,
        bytes calldata data
    ) external override onlyAllocationManager checkOperatorSetId(operatorSetIds) {
        // Decode signing key and p2p key from data
        (address signingKey, address p2pKey) = abi.decode(data, (address, address));

        // Call stake registry to register operator
        stakeRegistry.onOperatorSetRegistered(operator, signingKey, p2pKey);
    }

    function deregisterOperator(
        address operator,
        uint32[] calldata /*operatorSetIds*/
    ) external override onlyAllocationManager {
        stakeRegistry.onOperatorSetDeregistered(operator);
    }

    function updateAllocationManager(address _allocationManager) external onlyOwner {
        if(_allocationManager == address(0)) {
            revert SpottedRegistrar__ZeroAddress();
        }
        allocationManager = IAllocationManager(_allocationManager);
    }
}