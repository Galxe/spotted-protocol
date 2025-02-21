// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IDelegationManager} from
    "eigenlayer-contracts/src/contracts/interfaces/IDelegationManager.sol";
import {
    IECDSAStakeRegistry, IECDSAStakeRegistryTypes
} from "../interfaces/IECDSAStakeRegistry.sol";
import {IEpochManager} from "../interfaces/IEpochManager.sol";
import {IServiceManager} from "../interfaces/ISpottedServiceManager.sol";
import {IAllocationManager} from
    "eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";
import {IAVSRegistrar} from "eigenlayer-contracts/src/contracts/interfaces/IAVSRegistrar.sol";
import {IAVSDirectoryTypes} from "eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";

interface IAVSDirectory {
    function avsOperatorStatus(address avs, address operator) external view returns (IAVSDirectoryTypes.OperatorAVSRegistrationStatus);
}

abstract contract ECDSAStakeRegistryStorage is IECDSAStakeRegistry {
    /// @notice Manages staking delegations through the DelegationManager interface
    IDelegationManager internal immutable DELEGATION_MANAGER;
    IEpochManager internal immutable EPOCH_MANAGER;
    IAllocationManager internal allocationManager;
    address internal avsRegistrar;
    IAVSDirectory internal immutable AVS_DIRECTORY;
    /// @dev The total amount of multipliers to weigh stakes
    uint256 internal constant BPS = 10_000;

    /// @notice Holds the address of the service manager
    address internal _serviceManager;

    /// @notice Whether M2 quorum registration is disabled
    bool public isM2QuorumRegistrationDisabled;

    /// @notice Stores the current quorum configuration
    Quorum internal _quorum;

    /// @notice The current operator set id
    uint32 internal currentOperatorSetId;

    uint256 public constant WAD = 1e18;

    /// @notice Specifies the weight required to become an operator
    uint256 internal _minimumWeight;


    /// @notice Tracks the threshold bps history using checkpoints
    mapping(uint32 epochNumber => uint256 thresholdWeight) internal _thresholdWeightAtEpoch;

    /// @notice Maps operator addresses to their respective stake histories using checkpoints
    mapping(uint32 epochNumber => mapping(address operator => uint256 operatorWeight)) internal _operatorWeightAtEpoch;

    /// @notice Maps an operator to their signing key
    mapping(uint32 epochNumber => mapping(address operator => address signingKey)) internal _operatorSigningKeyAtEpoch;

    /// @notice Maps a signing key to an operator
    mapping(address signingKey => address operator) internal _signingKeyToOperator;

    /// @notice Maps an operator to their P2p key history using checkpoints
    mapping(uint32 epochNumber => mapping(address operator => address p2pKey)) internal _operatorP2pKeyAtEpoch;

    /// @param _delegationManager Connects this registry with the DelegationManager
    constructor(address _delegationManager, address _epochManager, address _allocationManager, address _avsRegistrar, address _avsDirectory) {
        DELEGATION_MANAGER = IDelegationManager(_delegationManager);
        EPOCH_MANAGER = IEpochManager(_epochManager);
        allocationManager = IAllocationManager(_allocationManager);
        avsRegistrar = _avsRegistrar;
        AVS_DIRECTORY = IAVSDirectory(_avsDirectory);
    }

    // slither-disable-next-line shadowing-state
    /// @dev Reserves storage slots for future upgrades
    // solhint-disable-next-line
    uint256[40] private __gap;
}
