// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IAbridge} from "../interfaces/IAbridge.sol";
import {IECDSAStakeRegistry} from "../interfaces/IECDSAStakeRegistry.sol";
import {Ownable2Step, Ownable} from "@openzeppelin-v5.0.0/contracts/access/Ownable2Step.sol";

contract RegistryStateSender is Ownable2Step {
    IECDSAStakeRegistry public immutable stakeRegistry;
    IAbridge public immutable abridge;
    address public immutable receiver;

    // gas limit for cross chain message
    uint128 private constant EXECUTE_GAS_LIMIT = 500_000;

    error InsufficientFee();
    error WithdrawFailed();

    constructor(
        address _stakeRegistry,
        address _abridge,
        address _receiver,
        address _owner
    ) Ownable(_owner) {
        stakeRegistry = IECDSAStakeRegistry(_stakeRegistry);
        abridge = IAbridge(_abridge);
        receiver = _receiver;
    }

    receive() external payable {}

    // Withdraw unused bridge fees
    function withdraw(
        address to
    ) external onlyOwner {
        uint256 amount = address(this).balance;
        (bool success,) = to.call{value: amount}("");
        if (!success) revert WithdrawFailed();
        emit FundsWithdrawn(to, amount);
    }

    // sync all operators state
    function syncAllOperators() external payable {
        // get all operators data
        (address[] memory operators, uint256[] memory weights, address[] memory signingKeys) =
            getAllOperatorsData();

        // encode data
        bytes memory operatorsData = abi.encode(operators, weights, signingKeys);

        // estimate fee
        (, uint256 fee) = abridge.estimateFee(receiver, EXECUTE_GAS_LIMIT, operatorsData);
        if (msg.value < fee) revert InsufficientFee();

        // send through bridge
        abridge.send{value: msg.value}(receiver, EXECUTE_GAS_LIMIT, operatorsData);
    }

    // get all operators data
    function getAllOperatorsData()
        public
        view
        returns (address[] memory operators, uint256[] memory weights, address[] memory signingKeys)
    {
        // Get total operators count from registry
        uint256 totalOperators = stakeRegistry.minimumWeight();

        // Initialize arrays
        operators = new address[](totalOperators);
        weights = new uint256[](totalOperators);
        signingKeys = new address[](totalOperators);

        // Collect data for each operator
        uint256 index = 0;
        for (uint256 i = 0; i < totalOperators;) {
            if (stakeRegistry.operatorRegistered(operators[i])) {
                operators[index] = operators[i];
                weights[index] = stakeRegistry.getLastCheckpointOperatorWeight(operators[i]);
                signingKeys[index] = stakeRegistry.getLastestOperatorSigningKey(operators[i]);
                index++;
            }
            unchecked {
                ++i;
            }
        }

        // resize arrays to actual size
        assembly {
            mstore(operators, index)
            mstore(weights, index)
            mstore(signingKeys, index)
        }
    }

    event FundsWithdrawn(address indexed to, uint256 amount);
}
