// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {RegistryStateSender} from "../../src/avs/RegistryStateSender.sol";
import {
    IRegistryStateSender,
    IRegistryStateSenderErrors
} from "../../src/interfaces/IRegistryStateSender.sol";
import {IEpochManager} from "../../src/interfaces/IEpochManager.sol";
import {MockAbridge} from "../mock/MockAbridge.sol";
import {Ownable} from "@openzeppelin-v5.0.0/contracts/access/Ownable.sol";

contract RegistryStateSenderTest is Test {
    RegistryStateSender public stateSender;
    MockAbridge public mockBridge;
    address public owner;
    address public epochManager;
    address public receiver;

    // Test constants
    uint256 public constant CHAIN_ID = 1;
    uint256 public constant EXECUTE_GAS_LIMIT = 500_000;

    error OwnableUnauthorizedAccount(address account);

    function setUp() public {
        owner = makeAddr("owner");
        epochManager = makeAddr("epochManager");
        receiver = makeAddr("receiver");
        mockBridge = new MockAbridge();

        // Setup initial bridge configuration
        uint256[] memory chainIds = new uint256[](1);
        address[] memory bridges = new address[](1);
        address[] memory receivers = new address[](1);

        chainIds[0] = CHAIN_ID;
        bridges[0] = address(mockBridge);
        receivers[0] = receiver;

        vm.prank(owner);
        stateSender = new RegistryStateSender(chainIds, bridges, receivers, owner, epochManager);

        // Fund the test contract with ETH for gas fees
        vm.deal(epochManager, 100 ether);
    }

    function test_Constructor() public {
        assertEq(address(stateSender.epochManager()), epochManager);

        IRegistryStateSender.BridgeInfo memory info = stateSender.getBridgeInfoByChainId(CHAIN_ID);
        assertEq(info.bridge, address(mockBridge));
        assertEq(info.receiver, receiver);

        assertEq(stateSender.supportedChainIds(0), CHAIN_ID);
    }

    function test_AddBridge() public {
        uint256 newChainId = 2;
        address newBridge = makeAddr("newBridge");
        address newReceiver = makeAddr("newReceiver");

        vm.prank(owner);
        stateSender.addBridge(newChainId, newBridge, newReceiver);

        IRegistryStateSender.BridgeInfo memory info = stateSender.getBridgeInfoByChainId(newChainId);
        assertEq(info.bridge, newBridge);
        assertEq(info.receiver, newReceiver);
    }

    function test_AddBridge_RevertIfNotOwner() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        stateSender.addBridge(2, address(0), address(0));
    }

    function test_AddBridge_RevertIfInvalidAddresses() public {
        vm.startPrank(owner);

        vm.expectRevert(IRegistryStateSenderErrors.RegistryStateSender__InvalidBridgeInfo.selector);
        stateSender.addBridge(2, address(0), makeAddr("receiver"));

        vm.expectRevert(IRegistryStateSenderErrors.RegistryStateSender__InvalidBridgeInfo.selector);
        stateSender.addBridge(2, makeAddr("bridge"), address(0));

        vm.stopPrank();
    }

    function test_AddBridge_RevertIfBridgeExists() public {
        vm.prank(owner);
        vm.expectRevert(IRegistryStateSenderErrors.RegistryStateSender__BridgeAlreadyExists.selector);
        stateSender.addBridge(CHAIN_ID, makeAddr("bridge"), makeAddr("receiver"));
    }

    function test_RemoveBridge() public {
        vm.prank(owner);
        stateSender.removeBridge(CHAIN_ID);

        IRegistryStateSender.BridgeInfo memory info = stateSender.getBridgeInfoByChainId(CHAIN_ID);
        assertEq(info.bridge, address(0));
        assertEq(info.receiver, address(0));
    }

    function test_RemoveBridge_RevertIfNotOwner() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        stateSender.removeBridge(CHAIN_ID);
    }

    function test_RemoveBridge_RevertIfChainNotSupported() public {
        vm.prank(owner);
        vm.expectRevert(IRegistryStateSenderErrors.RegistryStateSender__ChainNotSupported.selector);
        stateSender.removeBridge(999);
    }

    function test_ModifyBridge() public {
        address newBridge = makeAddr("newBridge");
        address newReceiver = makeAddr("newReceiver");

        vm.prank(owner);
        stateSender.modifyBridge(CHAIN_ID, newBridge, newReceiver);

        IRegistryStateSender.BridgeInfo memory info = stateSender.getBridgeInfoByChainId(CHAIN_ID);
        assertEq(info.bridge, newBridge);
        assertEq(info.receiver, newReceiver);
    }

    function test_ModifyBridge_RevertIfNotOwner() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        stateSender.modifyBridge(CHAIN_ID, address(0), address(0));
    }

    function test_ModifyBridge_RevertIfInvalidAddresses() public {
        vm.startPrank(owner);

        vm.expectRevert(IRegistryStateSenderErrors.RegistryStateSender__InvalidBridgeInfo.selector);
        stateSender.modifyBridge(CHAIN_ID, address(0), makeAddr("receiver"));

        vm.expectRevert(IRegistryStateSenderErrors.RegistryStateSender__InvalidBridgeInfo.selector);
        stateSender.modifyBridge(CHAIN_ID, makeAddr("bridge"), address(0));

        vm.stopPrank();
    }

    function test_ModifyBridge_RevertIfChainNotSupported() public {
        vm.prank(owner);
        vm.expectRevert(IRegistryStateSenderErrors.RegistryStateSender__ChainNotSupported.selector);
        stateSender.modifyBridge(999, makeAddr("bridge"), makeAddr("receiver"));
    }

    function test_SendState() public {
        // Create test data
        uint32 epochNumber = 1;
        address[] memory operators = new address[](1);
        address[] memory signingKeys = new address[](1);
        uint256[] memory weights = new uint256[](1);
        uint256 thresholdWeight = 100;

        operators[0] = makeAddr("operator");
        signingKeys[0] = makeAddr("signingKey");
        weights[0] = 200;

        bytes memory data = abi.encode(
            epochNumber,
            operators,
            signingKeys,
            weights,
            thresholdWeight
        );

        // Authorize sender in mock bridge
        mockBridge.setAuthorizedSender(address(stateSender), true);
        // Set route in mock bridge
        mockBridge.setRoute(receiver, address(stateSender), true);

        vm.prank(epochManager);
        stateSender.sendState{value: 0.01 ether}(epochNumber, CHAIN_ID, data);
    }

    function test_SendState_RevertIfNotEpochManager() public {
        bytes memory data = "";
        vm.expectRevert(IRegistryStateSenderErrors.RegistryStateSender__InvalidSender.selector);
        stateSender.sendState(1, CHAIN_ID, data);
    }

    function test_SendState_RevertIfChainNotSupported() public {
        bytes memory data = "";
        vm.prank(epochManager);
        vm.expectRevert(IRegistryStateSenderErrors.RegistryStateSender__ChainNotSupported.selector);
        stateSender.sendState(1, 999, data);
    }

    function test_SendState_RevertIfInsufficientFee() public {
        // Create test data
        uint32 epochNumber = 1;
        address[] memory operators = new address[](1);
        address[] memory signingKeys = new address[](1);
        uint256[] memory weights = new uint256[](1);
        uint256 thresholdWeight = 100;

        operators[0] = makeAddr("operator");
        signingKeys[0] = makeAddr("signingKey");
        weights[0] = 200;

        bytes memory data = abi.encode(
            epochNumber,
            operators,
            signingKeys,
            weights,
            thresholdWeight
        );

        // Authorize sender in mock bridge
        mockBridge.setAuthorizedSender(address(stateSender), true);
        // Set route in mock bridge
        mockBridge.setRoute(receiver, address(stateSender), true);

        vm.prank(epochManager);
        vm.expectRevert(IRegistryStateSenderErrors.RegistryStateSender__InsufficientFee.selector);
        stateSender.sendState{value: 0.009 ether}(epochNumber, CHAIN_ID, data);
    }
}
