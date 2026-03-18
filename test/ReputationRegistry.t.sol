// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ReputationRegistry} from "../src/ReputationRegistry.sol";

contract MockIdentityRegistry {
    function ownerOf(uint256) external pure returns (address) {
        return address(0x1234);
    }
    function getAgentWallet(uint256) external pure returns (address) {
        return address(0x1234);
    }
}

contract ReputationRegistryTest is Test {
    ReputationRegistry public registry;
    MockIdentityRegistry public identityRegistry;

    address oracle = address(0xbeef);
    uint256 agentId = 42;

    function setUp() public {
        identityRegistry = new MockIdentityRegistry();
        registry = new ReputationRegistry(address(identityRegistry));
    }

    function test_giveFeedback_storesFeedback() public {
        vm.prank(oracle);
        registry.giveFeedback(
            agentId,
            int128(420),      // 4.20 karma
            uint8(2),
            "karma",
            "forecast_outcome",
            "https://oracle.b1e55ed.permanentupperclass.com",
            "https://oracle.b1e55ed.permanentupperclass.com/api/v1/outcomes/f-abc123",
            keccak256("outcome_json")
        );

        assertEq(registry.getFeedbackCount(agentId), 1);
        assertEq(registry.totalFeedbackCount(), 1);
    }

    function test_aggregateKarma_accumulates() public {
        vm.startPrank(oracle);
        registry.giveFeedback(agentId, 100, 2, "karma", "forecast_outcome", "", "", bytes32(0));
        registry.giveFeedback(agentId, 200, 2, "karma", "forecast_outcome", "", "", bytes32(0));
        registry.giveFeedback(agentId, int128(-50), 2, "karma", "forecast_outcome", "", "", bytes32(0));
        vm.stopPrank();

        // (100 + 200 - 50) * 10^(6-2) = 250 * 10000 = 2_500_000
        assertEq(registry.getAggregateKarma(agentId), 2_500_000);
    }

    function test_getFeedback_returnsPaginated() public {
        vm.startPrank(oracle);
        for (uint256 i = 0; i < 5; i++) {
            registry.giveFeedback(agentId, int128(int256(i * 10)), 0, "karma", "test", "", "", bytes32(i));
        }
        vm.stopPrank();

        (ReputationRegistry.FeedbackEntry[] memory entries, uint256 total) =
            registry.getFeedbackPaginated(agentId, 0, 3);
        assertEq(total, 5);
        assertEq(entries.length, 3);
    }

    function test_giveFeedback_happyPath_noRevert() public {
        // MockIdentityRegistry always returns a valid owner, so this should not revert.
        // Tests the full happy path with the identity check passing.
        registry.giveFeedback(agentId, 100, 2, "k", "t", "", "", bytes32(0));
        assertEq(registry.getFeedbackCount(agentId), 1);
    }

    function test_emitsFeedbackGivenEvent() public {
        bytes32 hash = keccak256("data");
        vm.prank(oracle);
        vm.expectEmit(true, true, false, true);
        emit ReputationRegistry.FeedbackGiven(agentId, oracle, 100, 2, "karma", "forecast_outcome", "uri", hash);
        registry.giveFeedback(agentId, 100, 2, "karma", "forecast_outcome", "ep", "uri", hash);
    }

    function test_getPaginatedFeedback_offsetBeyondTotal() public {
        vm.prank(oracle);
        registry.giveFeedback(agentId, 10, 0, "karma", "test", "", "", bytes32(0));

        (ReputationRegistry.FeedbackEntry[] memory entries, uint256 total) =
            registry.getFeedbackPaginated(agentId, 10, 5);
        assertEq(total, 1);
        assertEq(entries.length, 0);
    }

    function test_identityRegistry_address() public view {
        assertEq(registry.getIdentityRegistry(), address(identityRegistry));
    }
}
