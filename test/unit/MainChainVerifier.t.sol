// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {MainChainVerifier} from "../../src/verifier/MainChainVerifier.sol";
import {IMainChainVerifier} from "../../src/interfaces/IMainChainVerifier.sol";
import {MockAbridge} from "../mock/MockAbridge.sol";
import {IAbridgeMessageHandler} from "../../src/interfaces/IAbridge.sol";
import {Ownable} from "@openzeppelin-v5.0.0/contracts/access/Ownable.sol";

contract MainChainVerifierTest is Test {
    MainChainVerifier public verifier;
    MockAbridge public mockBridge;
    address public owner;
    address public remoteVerifier;
    uint256 public constant CHAIN_ID = 1;

    error OwnableUnauthorizedAccount(address account);

    function setUp() public {
        owner = makeAddr("owner");
        remoteVerifier = makeAddr("remoteVerifier");
        mockBridge = new MockAbridge();

        vm.prank(owner);
        verifier = new MainChainVerifier(
            address(mockBridge),
            owner
        );
    }

    function test_Constructor() public view {
        assertEq(address(verifier.abridge()), address(mockBridge));
        assertEq(verifier.owner(), owner);
    }

    function test_Constructor_RevertIfInvalidBridge() public {
        vm.prank(owner);
        vm.expectRevert(IMainChainVerifier.MainChainVerifier__InvalidResponse.selector);
        new MainChainVerifier(address(0), owner);
    }

    function test_SetRemoteVerifier() public {
        vm.prank(owner);
        verifier.setRemoteVerifier(CHAIN_ID, remoteVerifier);

        assertEq(verifier.remoteVerifiers(CHAIN_ID), remoteVerifier);
        assertTrue(verifier.isRemoteVerifier(remoteVerifier));
    }

    function test_SetRemoteVerifier_RevertIfNotOwner() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        verifier.setRemoteVerifier(CHAIN_ID, remoteVerifier);
    }

    function test_SetRemoteVerifier_UpdateExisting() public {
        address newVerifier = makeAddr("newVerifier");

        // Set initial verifier
        vm.startPrank(owner);
        verifier.setRemoteVerifier(CHAIN_ID, remoteVerifier);
        
        // Update to new verifier
        verifier.setRemoteVerifier(CHAIN_ID, newVerifier);
        vm.stopPrank();

        // Check old verifier is removed
        assertFalse(verifier.isRemoteVerifier(remoteVerifier));
        
        // Check new verifier is set
        assertEq(verifier.remoteVerifiers(CHAIN_ID), newVerifier);
        assertTrue(verifier.isRemoteVerifier(newVerifier));
    }

    function test_HandleMessage() public {
        // Setup remote verifier
        vm.prank(owner);
        verifier.setRemoteVerifier(CHAIN_ID, remoteVerifier);

        // Prepare test data
        address user = makeAddr("user");
        uint256 key = 1;
        uint256 blockNumber = 100;
        uint256 value = 123;
        bool exist = true;

        bytes memory message = abi.encode(
            CHAIN_ID,
            user,
            key,
            blockNumber,
            value,
            exist
        );

        // Should revert when not called by bridge
        vm.expectRevert(IMainChainVerifier.MainChainVerifier__OnlyAbridge.selector);
        verifier.handleMessage(remoteVerifier, message, bytes32(0));

        // Should revert when called by unauthorized remote verifier
        vm.prank(address(mockBridge));
        vm.expectRevert(IMainChainVerifier.MainChainVerifier__UnauthorizedRemoteVerifier.selector);
        verifier.handleMessage(makeAddr("unauthorized"), message, bytes32(0));

        // Should succeed with correct parameters
        vm.prank(address(mockBridge));
        bytes4 response = verifier.handleMessage(remoteVerifier, message, bytes32(0));
        assertEq(response, IAbridgeMessageHandler.handleMessage.selector);

        // Verify state was stored
        (uint256 storedValue, bool storedExist) = verifier.getVerifiedState(
            CHAIN_ID,
            user,
            key,
            blockNumber
        );
        assertEq(storedValue, value);
        assertEq(storedExist, exist);
    }

    function test_GetVerifiedState() public {
        // Setup remote verifier
        vm.prank(owner);
        verifier.setRemoteVerifier(CHAIN_ID, remoteVerifier);

        // Store a state
        address user = makeAddr("user");
        uint256 key = 1;
        uint256 blockNumber = 100;
        uint256 value = 123;
        bool exist = true;

        bytes memory message = abi.encode(
            CHAIN_ID,
            user,
            key,
            blockNumber,
            value,
            exist
        );

        vm.prank(address(mockBridge));
        verifier.handleMessage(remoteVerifier, message, bytes32(0));

        // Test getting existing state
        (uint256 storedValue, bool storedExist) = verifier.getVerifiedState(
            CHAIN_ID,
            user,
            key,
            blockNumber
        );
        assertEq(storedValue, value);
        assertEq(storedExist, exist);

        // Test getting non-existent state
        (storedValue, storedExist) = verifier.getVerifiedState(
            CHAIN_ID,
            user,
            key,
            blockNumber + 1
        );
        assertEq(storedValue, 0);
        assertEq(storedExist, false);
    }
} 