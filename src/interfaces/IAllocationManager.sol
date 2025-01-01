// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./IStrategy.sol";

interface IAllocationManager {
    struct SlashingParams {
        address operator;
        uint32 operatorSetId;
        IStrategy[] strategies;
        uint256[] wadsToSlash;
        string description;
    }

    function slashOperator(address avs, SlashingParams calldata params) external;
}
