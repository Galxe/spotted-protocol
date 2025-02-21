// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {RemoteChainVerifier} from "../../src/verifier/RemoteChainVerifier.sol";
import {
    IRemoteChainVerifier,
    IRemoteChainVerifierErrors,
    IRemoteChainVerifierEvents
} from "../../src/interfaces/IRemoteChainVerifier.sol";
import {IStateManager} from "../../src/interfaces/IStateManager.sol";
import {MockAbridge} from "../mock/MockAbridge.sol";
import {MockStateManager} from "../mock/MockStateManager.sol";
import {Ownable} from "@openzeppelin-v5.0.0/contracts/access/Ownable.sol";

contract RemoteChainVerifierTest is Test {
    RemoteChainVerifier public verifier;
    MockAbridge public mockBridge;
    MockStateManager public mockStateManager;
    address public owner;
    address public mainChainVerifier;
    uint256 public constant MAIN_CHAIN_ID = 1;
    uint256 public constant EXECUTE_GAS_LIMIT = 500_000;

    error OwnableUnauthorizedAccount(address account);

    function setUp() public {
        owner = makeAddr("owner");
        mainChainVerifier = makeAddr("mainChainVerifier");
        mockBridge = new MockAbridge();
        mockStateManager = new MockStateManager();

        vm.prank(owner);
        verifier = new RemoteChainVerifier(
            address(mockBridge), address(mockStateManager), MAIN_CHAIN_ID, mainChainVerifier, owner
        );

        // Authorize verifier as sender
        mockBridge.setAuthorizedSender(address(verifier), true);
        // Set route for verifier to mainChainVerifier
        mockBridge.setRoute(mainChainVerifier, address(verifier), true);
    }

    function test_Constructor() public {
        assertEq(address(verifier.abridge()), address(mockBridge));
        assertEq(address(verifier.stateManager()), address(mockStateManager));
        assertEq(verifier.mainChainId(), MAIN_CHAIN_ID);
        assertEq(verifier.mainChainVerifier(), mainChainVerifier);
        assertEq(verifier.owner(), owner);
    }

    function test_Constructor_RevertIfInvalidBridge() public {
        vm.prank(owner);
        vm.expectRevert(IRemoteChainVerifierErrors.RemoteChainVerifier__InvalidResponse.selector);
        new RemoteChainVerifier(
            address(0), address(mockStateManager), MAIN_CHAIN_ID, mainChainVerifier, owner
        );
    }

    function test_Constructor_RevertIfInvalidMainChainId() public {
        vm.prank(owner);
        vm.expectRevert(IRemoteChainVerifierErrors.RemoteChainVerifier__InvalidMainChainId.selector);
        new RemoteChainVerifier(
            address(mockBridge), address(mockStateManager), 0, mainChainVerifier, owner
        );
    }

    function test_Constructor_RevertIfInvalidMainChainVerifier() public {
        vm.prank(owner);
        vm.expectRevert(IRemoteChainVerifierErrors.RemoteChainVerifier__InvalidResponse.selector);
        new RemoteChainVerifier(
            address(mockBridge), address(mockStateManager), MAIN_CHAIN_ID, address(0), owner
        );
    }

    function test_Constructor_AllowZeroStateManager() public {
        vm.prank(owner);
        RemoteChainVerifier newVerifier = new RemoteChainVerifier(
            address(mockBridge), address(0), MAIN_CHAIN_ID, mainChainVerifier, owner
        );

        assertEq(address(newVerifier.stateManager()), address(0));
    }

    function test_VerifyState() public {
        address user = makeAddr("user");
        uint256 key = 1;
        uint256 blockNumber = 100;
        uint256 value = 123;

        // Set block number
        vm.roll(blockNumber + 1);

        // Setup mock state
        mockStateManager.setHistoryAtBlock(user, key, blockNumber, value);

        // Setup mock bridge fee
        uint256 fee = 0.01 ether;
        mockBridge.setFee(fee);

        // Should revert if insufficient fee
        vm.expectRevert(IRemoteChainVerifierErrors.RemoteChainVerifier__InsufficientFee.selector);
        verifier.verifyState(user, key, blockNumber);

        // Should succeed with sufficient fee
        bytes memory expectedMessage =
            abi.encode(MAIN_CHAIN_ID, user, key, blockNumber, value, true);

        vm.expectEmit(true, true, true, true);
        emit IRemoteChainVerifierEvents.VerificationProcessed(user, key, blockNumber, value);

        verifier.verifyState{value: fee}(user, key, blockNumber);

        // Verify bridge call
        (address target, uint128 gasLimit, bytes memory message) = mockBridge.lastSendCall();
        assertEq(target, mainChainVerifier);
        assertEq(gasLimit, EXECUTE_GAS_LIMIT);
        assertEq(keccak256(message), keccak256(expectedMessage));
    }

    function test_VerifyState_RevertIfStateManagerNotSet() public {
        // Deploy verifier without state manager
        vm.prank(owner);
        RemoteChainVerifier newVerifier = new RemoteChainVerifier(
            address(mockBridge), address(0), MAIN_CHAIN_ID, mainChainVerifier, owner
        );

        vm.expectRevert(IRemoteChainVerifierErrors.RemoteChainVerifier__StateManagerNotSet.selector);
        newVerifier.verifyState(makeAddr("user"), 1, 100);
    }

    function test_VerifyState_RevertIfBlockNumberTooHigh() public {
        address user = makeAddr("user");
        uint256 key = 1;
        uint256 currentBlock = 100;

        // Set current block
        vm.roll(currentBlock);

        // Try to verify future block
        vm.expectRevert(IRemoteChainVerifierErrors.RemoteChainVerifier__BlockNumberTooHigh.selector);
        verifier.verifyState(user, key, currentBlock + 1);
    }
}
