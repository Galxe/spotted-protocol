// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {SlasherStorage} from "./SlasherStorage.sol";
import {ISlasher} from "../interfaces/ISlasher.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {IAllocationManager, IAllocationManagerTypes} from "eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";
import {OwnableUpgradeable} from "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import {IECDSAStakeRegistry} from "../interfaces/IECDSAStakeRegistry.sol";
import {OperatorSet} from "eigenlayer-contracts/src/contracts/libraries/OperatorSetLib.sol";
/// @title Spotted Slasher Contract
/// @notice Handles slashing of operator stakes
contract SpottedSlasher is SlasherStorage, ISlasher, OwnableUpgradeable {

    /// @notice Modifier to check if caller is state dispute resolver
    modifier onlyStateDisputeResolver() {
        require(msg.sender == stateDisputeResolver, "SpottedSlasher: caller not state dispute resolver");
        _;
    }

    /// @notice Constructor to initialize immutable variables
    /// @param _allocationManager The allocation manager contract address
    constructor(address _allocationManager) SlasherStorage(_allocationManager) {
        _disableInitializers();
    }

    /// @notice Initializes the contract
    /// @param initialOwner The initial owner address
    /// @param _stateDisputeResolver The state dispute resolver address
    /// @param _slashAmount The initial slash amount in WAD format
    function initialize(
        address initialOwner,
        address _stateDisputeResolver,
        uint256 _slashAmount
    ) external initializer {
        require(initialOwner != address(0), "SpottedSlasher: zero address");
        require(_stateDisputeResolver != address(0), "SpottedSlasher: zero address");
        require(_slashAmount > 0 && _slashAmount <= WAD, "SpottedSlasher: invalid slash amount");

        __Ownable_init();
        _transferOwnership(initialOwner);
        
        stateDisputeResolver = _stateDisputeResolver;
        slashAmount = _slashAmount;
    }

    /// @inheritdoc ISlasher
    function fulfillSlashingRequest(address operator) external onlyStateDisputeResolver {
        require(operator != address(0), "SpottedSlasher: zero address");

        // Get current operator set ID from stake registry
        uint32 operatorSetId = stakeRegistry.getCurrentOperatorSetId();
        
        // Create operator set struct
        OperatorSet memory operatorSet = OperatorSet({
            avs: address(this),
            id: operatorSetId
        });

        // Get strategies from allocation manager
        IStrategy[] memory strategies = allocationManager.getStrategiesInOperatorSet(operatorSet);
        require(strategies.length > 0, "SpottedSlasher: no strategies");

        // Create slashing params
        IAllocationManagerTypes.SlashingParams memory params = IAllocationManagerTypes.SlashingParams({
            operator: operator,
            operatorSetId: operatorSetId,
            strategies: strategies,
            wadsToSlash: new uint256[](strategies.length),
            description: "Spotted Slashing"
        });

        // Set slash amount for each strategy
        for(uint256 i = 0; i < strategies.length;) {
            params.wadsToSlash[i] = slashAmount;
            unchecked { ++i; }
        }

        // Call allocation manager to slash
        allocationManager.slashOperator(address(this), params);

        emit OperatorSlashed(operator);
    }

    /// @inheritdoc ISlasher
    function setAllocationManager(address _allocationManager) external onlyOwner {
        require(_allocationManager != address(0), "SpottedSlasher: zero address");
        allocationManager = IAllocationManager(_allocationManager);
        emit AllocationManagerUpdated(_allocationManager);
    }

    /// @inheritdoc ISlasher
    function setSlashAmount(uint256 newAmount) external onlyOwner {
        require(newAmount > 0 && newAmount <= WAD, "SpottedSlasher: invalid slash amount");
        slashAmount = newAmount;
        emit SlashAmountUpdated(newAmount);
    }

    /// @inheritdoc ISlasher
    function getSlashableStrategies() external view returns (IStrategy[] memory) {
        // Get current operator set ID from stake registry
        uint32 operatorSetId = stakeRegistry.getCurrentOperatorSetId();
        
        // Create operator set struct
        OperatorSet memory operatorSet = OperatorSet({
            avs: address(this),
            id: operatorSetId
        });

        // Return strategies from allocation manager
        return allocationManager.getStrategiesInOperatorSet(operatorSet);
    }

}