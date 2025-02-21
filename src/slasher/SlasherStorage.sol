// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import {IAllocationManager} from "eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";
import {IECDSAStakeRegistry} from "../interfaces/IECDSAStakeRegistry.sol";

/// @title Slasher Storage Contract
/// @notice Handles storage variables for the Slasher contract
contract SlasherStorage {
    /// @notice The allocation manager contract
    IAllocationManager public allocationManager;

    /// @notice The state dispute resolver contract
    address public stateDisputeResolver;

    /// @notice The ECDSA stake registry contract
    IECDSAStakeRegistry public stakeRegistry;

    /// @notice Amount to slash from operators (in WAD format)
    uint256 public slashAmount;

    /// @notice WAD precision constant
    uint256 public constant WAD = 1e18;

    /// @notice Gap for future storage variables
    uint256[47] private __gap;

    /// @notice Constructor to initialize immutable variables
    /// @param _allocationManager The allocation manager contract address
    constructor(address _allocationManager) {
        allocationManager = IAllocationManager(_allocationManager);
    }
}