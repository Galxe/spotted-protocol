// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {RegistryStateReceiver} from "../../src/avs/RegistryStateReceiver.sol";
import {IRegistryStateReceiver} from "../../src/interfaces/IRegistryStateReceiver.sol";
import {IEpochManager} from "../../src/interfaces/IEpochManager.sol";
import {MockAbridge} from "../mock/MockAbridge.sol";
import {MockLightStakeRegistry} from "../mock/MockLightStakeRegistry.sol";
import {Ownable} from "@openzeppelin-v5.0.0/contracts/access/Ownable.sol";
import {IAbridgeMessageHandler} from "../../src/interfaces/IAbridge.sol";

contract RegistryStateReceiverTest is Test {
    RegistryStateReceiver public stateReceiver;
    MockAbridge public mockBridge;
    MockLightStakeRegistry public mockStakeRegistry;
    address public owner;
    address public sender;

    error OwnableUnauthorizedAccount(address account);

    function setUp() public {
        owner = makeAddr("owner");
        sender = makeAddr("sender");
        
        // Deploy mock contracts
        mockBridge = new MockAbridge();
        mockStakeRegistry = new MockLightStakeRegistry();

        vm.prank(owner);
        stateReceiver = new RegistryStateReceiver(
            address(mockBridge),
            sender,
            address(mockStakeRegistry),
            owner
        );
    }

    function test_Constructor() public view {
        assertEq(address(stateReceiver.abridge()), address(mockBridge));
        assertEq(stateReceiver.sender(), sender);
        assertEq(address(stateReceiver.stakeRegistry()), address(mockStakeRegistry));
        assertEq(stateReceiver.owner(), owner);
    }

    function test_HandleMessage() public {
        // Create test data
        IEpochManager.StateUpdate[] memory updates = new IEpochManager.StateUpdate[](1);
        updates[0] = IEpochManager.StateUpdate({
            updateType: IEpochManager.MessageType.REGISTER,
            data: "test"
        });
        
        bytes memory message = abi.encode(1, updates); // epoch 1
        bytes32 guid = keccak256("test");

        // Should revert when not called by bridge
        vm.expectRevert(IRegistryStateReceiver.RegistryStateReceiver__InvalidSender.selector);
        stateReceiver.handleMessage(sender, message, guid);

        // Should revert when called with wrong sender
        vm.prank(address(mockBridge));
        vm.expectRevert(IRegistryStateReceiver.RegistryStateReceiver__InvalidSender.selector);
        stateReceiver.handleMessage(makeAddr("wrongSender"), message, guid);

        // Should succeed with correct parameters
        vm.prank(address(mockBridge));
        bytes4 response = stateReceiver.handleMessage(sender, message, guid);
        assertEq(response, IAbridgeMessageHandler.handleMessage.selector);

        // Should revert on duplicate message
        vm.prank(address(mockBridge));
        vm.expectRevert(IRegistryStateReceiver.RegistryStateReceiver__MessageAlreadyProcessed.selector);
        stateReceiver.handleMessage(sender, message, guid);

        // Verify epoch was updated
        assertEq(stateReceiver.getCurrentEpoch(), 1);
    }

    function test_UpdateRoute() public {
        // Should revert when not called by owner
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        stateReceiver.updateRoute(false);

        // Should succeed when called by owner
        vm.prank(owner);
        stateReceiver.updateRoute(false);
    }

    function test_HandleMessage_BatchUpdateFailed() public {
        // Create test data
        IEpochManager.StateUpdate[] memory updates = new IEpochManager.StateUpdate[](1);
        updates[0] = IEpochManager.StateUpdate({
            updateType: IEpochManager.MessageType.REGISTER,
            data: "test"
        });
        
        bytes memory message = abi.encode(1, updates);
        bytes32 guid = keccak256("test");

        // Make stake registry revert
        mockStakeRegistry.setShouldRevert(true);

        // Should revert with BatchUpdateFailed
        vm.prank(address(mockBridge));
        vm.expectRevert(IRegistryStateReceiver.RegistryStateReceiver__BatchUpdateFailed.selector);
        stateReceiver.handleMessage(sender, message, guid);
    }
} 