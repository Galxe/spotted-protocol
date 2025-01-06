// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import {MathUpgradeable} from "@openzeppelin-upgrades/contracts/utils/math/MathUpgradeable.sol";
import {SafeCastUpgradeable} from
    "@openzeppelin-upgrades/contracts/utils/math/SafeCastUpgradeable.sol";
import {IRegistryStateReceiver} from "../interfaces/IRegistryStateReceiver.sol";

/// Library for tracking value changes by epoch number for cross-chain compatibility
library LightEpochCheckpointsUpgradeable {
    error InvalidEpoch();

    address public constant STATE_RECEIVER = 0x0000000000000000000000000000000000000000; // 需要替换为实际地址

    struct Checkpoint {
        uint32 _epochNumber;
        uint224 _value;
    }

    struct History {
        Checkpoint[] _checkpoints;
    }

    // Returns the latest checkpoint value
    function latest(
        History storage self
    ) internal view returns (uint256) {
        uint256 pos = self._checkpoints.length;
        return pos == 0 ? 0 : self._checkpoints[pos - 1]._value;
    }

    // Returns the value at a given epoch
    function getAtEpoch(
        History storage self,
        uint256 epochNumber
    ) internal view returns (uint256) {
        // get current epoch from StateReceiver
        uint256 currentEpoch = IRegistryStateReceiver(STATE_RECEIVER).getCurrentEpoch();
        if (epochNumber > currentEpoch) {
            revert InvalidEpoch();
        }

        uint256 high = self._checkpoints.length;
        uint256 low = 0;

        while (low < high) {
            uint256 mid = MathUpgradeable.average(low, high);
            if (self._checkpoints[mid]._epochNumber > epochNumber) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        return high == 0 ? 0 : self._checkpoints[high - 1]._value;
    }

    // Pushes a new value checkpoint for the current epoch
    function push(History storage self, uint256 value) internal returns (uint256, uint256) {
        uint256 pos = self._checkpoints.length;
        uint256 old = latest(self);

        // get current epoch from StateReceiver
        uint32 currentEpoch = uint32(IRegistryStateReceiver(STATE_RECEIVER).getCurrentEpoch());

        if (pos > 0 && self._checkpoints[pos - 1]._epochNumber == currentEpoch) {
            self._checkpoints[pos - 1]._value = SafeCastUpgradeable.toUint224(value);
        } else {
            self._checkpoints.push(
                Checkpoint({
                    _epochNumber: currentEpoch,
                    _value: SafeCastUpgradeable.toUint224(value)
                })
            );
        }
        return (old, value);
    }

    // Pushes a new value using a binary operation
    function push(
        History storage self,
        function(uint256, uint256) view returns (uint256) op,
        uint256 delta
    ) internal returns (uint256, uint256) {
        return push(self, op(latest(self), delta));
    }
}
