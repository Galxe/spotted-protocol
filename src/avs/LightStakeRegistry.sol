// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {LightStakeRegistryStorage} from "./LightStakeRegistryStorage.sol";
import {OwnableUpgradeable} from "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import {SignatureCheckerUpgradeable} from "@openzeppelin-upgrades/contracts/utils/cryptography/SignatureCheckerUpgradeable.sol";
import {IERC1271Upgradeable} from "@openzeppelin-upgrades/contracts/interfaces/IERC1271Upgradeable.sol";

contract LightStakeRegistry is IERC1271Upgradeable, OwnableUpgradeable, LightStakeRegistryStorage {
    using SignatureCheckerUpgradeable for address;

    constructor(address _registryStateReceiver) LightStakeRegistryStorage(_registryStateReceiver) {
        _disableInitializers();
    }

    modifier onlyStateReceiver() {
        if (msg.sender != address(REGISTRY_STATE_RECEIVER)) {
            revert LightStakeRegistry__InvalidSender();
        }
        _;
    }

    function initialize() external initializer {
        __LightStakeRegistry_init();
    }

    function isValidSignature(
        bytes32 _dataHash,
        bytes memory _signatureData
    ) external view returns (bytes4) {
        (address[] memory operators, bytes[] memory signatures, uint32 referenceEpoch) =
            abi.decode(_signatureData, (address[], bytes[], uint32));
            
        _checkSignatures(_dataHash, operators, signatures, referenceEpoch);
        return IERC1271Upgradeable.isValidSignature.selector;
    }

    function processEpochUpdate(bytes memory data) external onlyStateReceiver {
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
        return _operatorSigningKeyAtEpoch[epochNumber][operator];
    }

    function getOperatorWeightAtEpoch(
        address operator,
        uint32 epochNumber
    ) external view returns (uint256) {
        return _operatorWeightAtEpoch[epochNumber][operator];
    }

    function getThresholdWeightAtEpoch(
        uint32 epochNumber
    ) external view returns (uint256) {
        return _thresholdWeightAtEpoch[epochNumber];
    }

    function __LightStakeRegistry_init() internal onlyInitializing {
        __Ownable_init();
    }

    function _checkSignatures(
        bytes32 _dataHash,
        address[] memory _operators,
        bytes[] memory _signatures,
        uint32 _referenceEpoch
    ) internal view {
        uint256 signersLength = _operators.length;
        address currentOperator;
        address lastOperator;
        address signer;
        uint256 signedWeight;

        _validateSignaturesLength(signersLength, _signatures.length);

        for (uint256 i; i < signersLength; i++) {
            currentOperator = _operators[i];
            signer = _operatorSigningKeyAtEpoch[_referenceEpoch][currentOperator];

            _validateSortedSigners(lastOperator, currentOperator);
            _validateSignature(signer, _dataHash, _signatures[i]);

            lastOperator = currentOperator;
            signedWeight += _operatorWeightAtEpoch[_referenceEpoch][currentOperator];
        }

        _validateThresholdStake(signedWeight, _referenceEpoch);
    }

    function _validateSignaturesLength(uint256 _signersLength, uint256 _signaturesLength) internal pure {
        if (_signersLength != _signaturesLength) {
            revert LightStakeRegistry__LengthMismatch();
        }
        if (_signersLength == 0) {
            revert LightStakeRegistry__InvalidLength();
        }
    }

    function _validateSortedSigners(address _lastSigner, address _currentSigner) internal pure {
        if (_lastSigner >= _currentSigner) {
            revert LightStakeRegistry__NotSorted();
        }
    }

    function _validateSignature(address _signer, bytes32 _dataHash, bytes memory _signature) internal view {
        if (!_signer.isValidSignatureNow(_dataHash, _signature)) {
            revert LightStakeRegistry__InvalidSignature();
        }
    }

    function _validateThresholdStake(uint256 _signedWeight, uint32 _referenceEpoch) internal view {
        uint256 thresholdWeight = _thresholdWeightAtEpoch[_referenceEpoch];
        if (thresholdWeight > _signedWeight) {
            revert LightStakeRegistry__InsufficientSignedStake();
        }
    }
}
