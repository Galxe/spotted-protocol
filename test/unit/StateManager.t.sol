// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {StateManager} from "../../src/state-manager/StateManager.sol";
import {
    IStateManager,
    IStateManagerTypes,
    IStateManagerErrors
} from "../../src/interfaces/IStateManager.sol";

contract StateManagerTest is Test {
    StateManager public stateManager;
    address public user;
    uint256 public constant KEY = 1;
    uint256 public constant VALUE = 100;

    function setUp() public {
        stateManager = new StateManager();
        user = address(this);
    }

    function test_SetValue() public {
        stateManager.setValue(KEY, VALUE);

        IStateManagerTypes.History[] memory history = stateManager.getHistory(user, KEY);
        assertEq(history.length, 1);
        assertEq(history[0].value, VALUE);
        assertEq(history[0].blockNumber, block.number);
        assertEq(history[0].timestamp, block.timestamp);
    }

    function test_BatchSetValues() public {
        IStateManagerTypes.SetValueParams[] memory params = new IStateManagerTypes.SetValueParams[](2);
        params[0] = IStateManagerTypes.SetValueParams({key: 1, value: 100});
        params[1] = IStateManagerTypes.SetValueParams({key: 2, value: 200});

        stateManager.batchSetValues(params);

        IStateManagerTypes.History[] memory history1 = stateManager.getHistory(user, 1);
        IStateManagerTypes.History[] memory history2 = stateManager.getHistory(user, 2);

        assertEq(history1.length, 1);
        assertEq(history2.length, 1);
        assertEq(history1[0].value, 100);
        assertEq(history2[0].value, 200);
    }

    function test_BatchSetValues_RevertWhenTooLarge() public {
        IStateManagerTypes.SetValueParams[] memory params = new IStateManagerTypes.SetValueParams[](101);

        vm.expectRevert(IStateManagerErrors.StateManager__BatchTooLarge.selector);
        stateManager.batchSetValues(params);
    }

    function test_GetHistoryBetweenBlockNumbers() public {
        // Set values at different blocks with larger gaps
        stateManager.setValue(KEY, 100); // block 1
        vm.roll(5);
        stateManager.setValue(KEY, 200); // block 5
        vm.roll(10);
        stateManager.setValue(KEY, 300); // block 10

        // Test full range
        IStateManagerTypes.History[] memory history1 =
            stateManager.getHistoryBetweenBlockNumbers(user, KEY, 1, 10);
        assertEq(history1.length, 3);
        assertEq(history1[0].value, 100);
        assertEq(history1[1].value, 200);
        assertEq(history1[2].value, 300);

        // Test partial range
        IStateManagerTypes.History[] memory history2 =
            stateManager.getHistoryBetweenBlockNumbers(user, KEY, 4, 9);
        assertEq(history2.length, 1);
        assertEq(history2[0].value, 200);

        // Test boundary case
        IStateManagerTypes.History[] memory history3 =
            stateManager.getHistoryBetweenBlockNumbers(user, KEY, 5, 10);
        assertEq(history3.length, 2);
        assertEq(history3[0].value, 200);
        assertEq(history3[1].value, 300);
    }

    function test_GetHistoryAtBlock() public {
        stateManager.setValue(KEY, 100);
        vm.roll(2);
        stateManager.setValue(KEY, 200);

        IStateManagerTypes.History memory historyAt1 = stateManager.getHistoryAtBlock(user, KEY, 1);

        assertEq(historyAt1.value, 100);
        assertEq(historyAt1.blockNumber, 1);

        IStateManagerTypes.History memory historyAt2 = stateManager.getHistoryAtBlock(user, KEY, 2);
        assertEq(historyAt2.value, 200);
        assertEq(historyAt2.blockNumber, 2);
    }

    function test_GetHistoryCount() public {
        assertEq(stateManager.getHistoryCount(user, KEY), 0);

        stateManager.setValue(KEY, 100);
        assertEq(stateManager.getHistoryCount(user, KEY), 1);

        stateManager.setValue(KEY, 200);
        assertEq(stateManager.getHistoryCount(user, KEY), 2);
    }

    function test_GetHistoryAt() public {
        stateManager.setValue(KEY, 100);
        stateManager.setValue(KEY, 200);

        IStateManagerTypes.History memory history = stateManager.getHistoryAt(user, KEY, 1);
        assertEq(history.value, 200);
    }

    function test_GetHistoryAt_RevertWhenOutOfBounds() public {
        vm.expectRevert(IStateManagerErrors.StateManager__IndexOutOfBounds.selector);
        stateManager.getHistoryAt(user, KEY, 0);
    }

    function test_GetHistoryBeforeOrAtBlockNumber() public {
        stateManager.setValue(KEY, 100); // block 1
        vm.roll(5);
        stateManager.setValue(KEY, 200); // block 5
        vm.roll(10);
        stateManager.setValue(KEY, 300); // block 10

        // Test normal case - query block 6
        IStateManagerTypes.History[] memory history1 =
            stateManager.getHistoryBeforeOrAtBlockNumber(user, KEY, 6);
        assertEq(history1.length, 2);
        assertEq(history1[0].value, 100); // record at block 1
        assertEq(history1[1].value, 200); // record at block 5

        // Test boundary case - query block 5
        IStateManagerTypes.History[] memory history2 =
            stateManager.getHistoryBeforeOrAtBlockNumber(user, KEY, 5);
        assertEq(history2.length, 2); // should return records from block 1 and 5
        assertEq(history2[0].value, 100);
        assertEq(history2[1].value, 200);

        // Test too early block case - query block 0
        vm.expectRevert(IStateManagerErrors.StateManager__NoHistoryFound.selector);
        stateManager.getHistoryBeforeOrAtBlockNumber(user, KEY, 0);
    }

    function test_GetHistoryAfterOrAtBlockNumber() public {
        stateManager.setValue(KEY, 100); // block 1
        vm.roll(5);
        stateManager.setValue(KEY, 200); // block 5
        vm.roll(10);
        stateManager.setValue(KEY, 300); // block 10

        // Test normal case
        IStateManagerTypes.History[] memory history1 =
            stateManager.getHistoryAfterOrAtBlockNumber(user, KEY, 4);
        assertEq(history1.length, 2);
        assertEq(history1[0].value, 200);
        assertEq(history1[1].value, 300);

        // Test boundary case
        IStateManagerTypes.History[] memory history2 =
            stateManager.getHistoryAfterOrAtBlockNumber(user, KEY, 1);
        assertEq(history2.length, 2);

        // Test case with no records after
        vm.expectRevert(IStateManagerErrors.StateManager__NoHistoryFound.selector);
        stateManager.getHistoryAfterOrAtBlockNumber(user, KEY, 10);
    }

    function test_NoHistoryFound() public {
        vm.expectRevert(IStateManagerErrors.StateManager__NoHistoryFound.selector);
        stateManager.getHistoryBetweenBlockNumbers(user, KEY, 1, 2);

        vm.expectRevert(IStateManagerErrors.StateManager__NoHistoryFound.selector);
        stateManager.getHistoryBeforeOrAtBlockNumber(user, KEY, 1);

        vm.expectRevert(IStateManagerErrors.StateManager__NoHistoryFound.selector);
        stateManager.getHistoryAfterOrAtBlockNumber(user, KEY, 1);
    }

    function test_InvalidRanges() public {
        vm.expectRevert(IStateManagerErrors.StateManager__InvalidBlockRange.selector);
        stateManager.getHistoryBetweenBlockNumbers(user, KEY, 2, 1);
    }

    function test_GetHistoryBetweenBlockNumbers_EdgeCases() public {
        stateManager.setValue(KEY, 100); // block 1
        vm.roll(5);
        stateManager.setValue(KEY, 200); // block 5

        // Test fromBlock less than earliest record
        IStateManagerTypes.History[] memory history1 =
            stateManager.getHistoryBetweenBlockNumbers(user, KEY, 0, 5);
        assertEq(history1.length, 2);
        assertEq(history1[0].value, 100);
        assertEq(history1[1].value, 200);

        // Test toBlock greater than latest record but with valid results
        IStateManagerTypes.History[] memory history2 =
            stateManager.getHistoryBetweenBlockNumbers(user, KEY, 1, 6);
        assertEq(history2.length, 2);

        // Test range with no records
        vm.expectRevert(IStateManagerErrors.StateManager__NoHistoryFound.selector);
        stateManager.getHistoryBetweenBlockNumbers(user, KEY, 6, 8);
    }

    function test_BinarySearch_EdgeCases() public {
        // Test empty history
        vm.expectRevert(IStateManagerErrors.StateManager__NoHistoryFound.selector);
        stateManager.getHistoryAtBlock(user, KEY, 1);

        // Test single record
        stateManager.setValue(KEY, 100);
        IStateManagerTypes.History memory history = stateManager.getHistoryAtBlock(user, KEY, 1);
        assertEq(history.value, 100);

        // Test block number less than first record
        vm.expectRevert(IStateManagerErrors.StateManager__BlockNotFound.selector);
        stateManager.getHistoryAtBlock(user, KEY, 0);

        // Test block number equal to first record
        history = stateManager.getHistoryAtBlock(user, KEY, 1);
        assertEq(history.value, 100);
        assertEq(history.blockNumber, 1);

        // Add second record at block 3
        vm.roll(3);
        stateManager.setValue(KEY, 200);

        // Test block number between two records
        history = stateManager.getHistoryAtBlock(user, KEY, 2);
        assertEq(history.value, 100); // should return the nearest record less than or equal to target block

        // Test block number greater than last record
        history = stateManager.getHistoryAtBlock(user, KEY, 4);
        assertEq(history.value, 200); // should return the last record
    }
}
