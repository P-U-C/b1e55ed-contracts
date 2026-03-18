// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ReputationRegistry} from "../src/ReputationRegistry.sol";

contract MockIdentityRegistry {
    function ownerOf(uint256) external pure returns (address) { return address(0x1234); }
    function getAgentWallet(uint256) external pure returns (address) { return address(0x1234); }
}

contract ReputationRegistryTest is Test {
    ReputationRegistry public registry;
    MockIdentityRegistry public id;
    address oracle = address(0xbeef);
    uint256 agentId = 42;

    function setUp() public {
        id = new MockIdentityRegistry();
        registry = new ReputationRegistry(address(id));
    }

    function test_giveFeedback_stores() public {
        vm.prank(oracle);
        registry.giveFeedback(agentId, 420, 2, "karma", "forecast_outcome", "ep", "uri", keccak256("data"));
        assertEq(registry.getFeedbackCount(agentId), 1);
        assertEq(registry.totalFeedbackCount(), 1);
    }

    function test_aggregateKarma() public {
        vm.startPrank(oracle);
        registry.giveFeedback(agentId, 100, 2, "karma", "t", "", "", bytes32(0));
        registry.giveFeedback(agentId, 200, 2, "karma", "t", "", "", bytes32(0));
        registry.giveFeedback(agentId, int128(-50), 2, "karma", "t", "", "", bytes32(0));
        vm.stopPrank();
        assertEq(registry.getAggregateKarma(agentId), 2_500_000);
    }

    function test_pagination() public {
        vm.startPrank(oracle);
        for (uint256 i = 0; i < 5; i++) {
            registry.giveFeedback(agentId, int128(int256(i*10)), 0, "k", "t", "", "", bytes32(i));
        }
        vm.stopPrank();
        (ReputationRegistry.FeedbackEntry[] memory entries, uint256 total) =
            registry.getFeedbackPaginated(agentId, 0, 3);
        assertEq(total, 5);
        assertEq(entries.length, 3);
    }
}
