// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {EpochManager} from "../../src/avs/EpochManager.sol";
import {
    IEpochManager,
    IEpochManagerErrors,
    IEpochManagerEvents
} from "../../src/interfaces/IEpochManager.sol";
import {IRegistryStateSender} from "../../src/interfaces/IRegistryStateSender.sol";
import {MockRegistryStateSender} from "../../test/mock/MockRegistryStateSender.sol";

contract EpochManagerTest is Test {
    EpochManager public epochManager;
    address public stakeRegistry;
    address public registryStateSender;

    // Test constants
    uint64 public constant EPOCH_LENGTH = 45_000;
    uint64 public constant GRACE_PERIOD = 6400;

    function setUp() public {
        // Deploy mock contracts
        registryStateSender = address(new MockRegistryStateSender());
        stakeRegistry = makeAddr("stakeRegistry");

        // Deploy EpochManager
        vm.prank(makeAddr("owner"));
        epochManager = new EpochManager(registryStateSender, stakeRegistry);
    }

    function test_Constructor() public {
        assertEq(epochManager.GENESIS_BLOCK(), block.number);
        assertEq(epochManager.EPOCH_LENGTH(), EPOCH_LENGTH);
        assertEq(epochManager.GRACE_PERIOD(), GRACE_PERIOD);
        assertEq(address(epochManager.REGISTRY_STATE_SENDER()), registryStateSender);
        assertEq(address(epochManager.STAKE_REGISTRY()), stakeRegistry);
    }

    function test_SnapshotAndSendState() public {
        // Prepare test data
        address[] memory operators = new address[](2);
        operators[0] = makeAddr("operator1");
        operators[1] = makeAddr("operator2");
        uint32 epochNumber = 1;
        uint256 chainId = 1;

        // Should succeed with sufficient fee
        vm.deal(address(this), 1 ether);
        epochManager.snapshotAndSendState{value: 0.1 ether}(operators, epochNumber, chainId);

        // Verify event was emitted
        vm.expectEmit(true, true, true, true);
        emit IEpochManagerEvents.StateSnapshotSent(epochNumber, chainId, operators);
    }

    function test_EpochCalculations() public {
        // Test initial state
        assertEq(epochManager.getCurrentEpoch(), 0);
        assertEq(epochManager.getCurrentEpochStartBlock(), epochManager.GENESIS_BLOCK());
        assertEq(epochManager.getNextEpochStartBlock(), epochManager.GENESIS_BLOCK() + EPOCH_LENGTH);

        // Roll to middle of epoch
        vm.roll(block.number + EPOCH_LENGTH / 2);
        assertEq(epochManager.getCurrentEpoch(), 0);

        // Roll to next epoch
        vm.roll(block.number + EPOCH_LENGTH / 2 + 1);
        assertEq(epochManager.getCurrentEpoch(), 1);
    }

    function test_GracePeriod() public {
        // Not in grace period initially
        assertFalse(epochManager.isInGracePeriod());

        // Roll to just before grace period
        uint256 graceStart = epochManager.getNextEpochStartBlock() - GRACE_PERIOD;
        vm.roll(graceStart - 1);
        assertFalse(epochManager.isInGracePeriod());

        // Roll to start of grace period
        vm.roll(graceStart);
        assertTrue(epochManager.isInGracePeriod());

        // Check effective epoch during grace period
        assertEq(epochManager.getEffectiveEpoch(), epochManager.getCurrentEpoch() + 2);
    }

    function test_BlocksUntilNextEpoch() public {
        uint64 nextEpochStartBlock = epochManager.getNextEpochStartBlock();

        // At start
        assertEq(epochManager.blocksUntilNextEpoch(), EPOCH_LENGTH);

        // Middle of epoch
        vm.roll(block.number + EPOCH_LENGTH / 2);
        assertEq(epochManager.blocksUntilNextEpoch(), nextEpochStartBlock - uint64(block.number));

        // At epoch boundary
        vm.roll(nextEpochStartBlock - 1);
        assertEq(epochManager.blocksUntilNextEpoch(), 1);
    }

    function test_BlocksUntilGracePeriod() public {
        uint64 graceStart = epochManager.getNextEpochStartBlock() - GRACE_PERIOD;

        // At start
        assertEq(epochManager.blocksUntilGracePeriod(), graceStart - uint64(block.number));

        // Just before grace period
        vm.roll(graceStart - 1);
        assertEq(epochManager.blocksUntilGracePeriod(), 1);

        // During grace period
        vm.roll(graceStart);
        assertEq(epochManager.blocksUntilGracePeriod(), 0);
    }

    function test_GetEpochInterval() public {
        // Test epoch 0
        (uint64 startBlock, uint64 graceBlock, uint64 endBlock) = epochManager.getEpochInterval(0);
        assertEq(startBlock, epochManager.GENESIS_BLOCK());
        assertEq(endBlock, startBlock + EPOCH_LENGTH);
        assertEq(graceBlock, endBlock - GRACE_PERIOD);

        // Test future epoch
        uint32 futureEpoch = 5;
        (startBlock, graceBlock, endBlock) = epochManager.getEpochInterval(futureEpoch);
        assertEq(startBlock, epochManager.GENESIS_BLOCK() + (futureEpoch * EPOCH_LENGTH));
        assertEq(endBlock, startBlock + EPOCH_LENGTH);
        assertEq(graceBlock, endBlock - GRACE_PERIOD);
    }

    function test_GetEffectiveEpochForBlock() public {
        uint64 genesisBlock = epochManager.GENESIS_BLOCK();

        // Test block in first epoch (not in grace period)
        uint64 blockInFirstEpoch = genesisBlock + EPOCH_LENGTH / 2;
        assertEq(epochManager.getEffectiveEpochForBlock(blockInFirstEpoch), 1);

        // Test block in grace period
        uint64 blockInGracePeriod = genesisBlock + EPOCH_LENGTH - GRACE_PERIOD / 2;
        assertEq(epochManager.getEffectiveEpochForBlock(blockInGracePeriod), 2);

        // Test block in future epoch
        uint64 futureBlock = genesisBlock + (5 * EPOCH_LENGTH) + EPOCH_LENGTH / 2;
        assertEq(epochManager.getEffectiveEpochForBlock(futureBlock), 6);
    }
}
