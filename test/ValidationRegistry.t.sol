// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ValidationRegistry} from "../src/ValidationRegistry.sol";

contract MockIdentityRegistry {
    function ownerOf(uint256) external pure returns (address) {
        return address(0x1234);
    }
}

contract ValidationRegistryTest is Test {
    ValidationRegistry public registry;
    MockIdentityRegistry public identityRegistry;

    address council = address(0xc0de);
    uint256 agentId = 1;

    function setUp() public {
        identityRegistry = new MockIdentityRegistry();
        registry = new ValidationRegistry(address(identityRegistry));
    }

    function test_postValidation_pass() public {
        vm.prank(council);
        registry.postValidation(
            agentId,
            "pass",
            "https://github.com/P-U-C/b1e55ed/pull/353",
            "https://oracle.b1e55ed.permanentupperclass.com/api/v1/reviews/353",
            keccak256("verdict_json")
        );

        assertEq(registry.getValidationCount(agentId), 1);
        assertEq(registry.totalValidationCount(), 1);
        (uint256 passes, uint256 total) = registry.getPassRate(agentId);
        assertEq(passes, 1);
        assertEq(total, 1);
    }

    function test_postValidation_allVerdicts() public {
        string[4] memory verdicts = ["pass", "concern", "block", "human-required"];
        vm.startPrank(council);
        for (uint256 i = 0; i < verdicts.length; i++) {
            registry.postValidation(agentId, verdicts[i], "context", "uri", bytes32(i));
        }
        vm.stopPrank();

        assertEq(registry.getValidationCount(agentId), 4);
    }

    function test_invalidVerdict_reverts() public {
        vm.prank(council);
        vm.expectRevert();
        registry.postValidation(agentId, "invalid", "ctx", "uri", bytes32(0));
    }

    function test_emitsValidationPostedEvent() public {
        bytes32 hash = keccak256("v");
        vm.prank(council);
        vm.expectEmit(true, true, false, true);
        emit ValidationRegistry.ValidationPosted(
            agentId, council, ValidationRegistry.Verdict.Pass, "ctx", "uri", hash
        );
        registry.postValidation(agentId, "pass", "ctx", "uri", hash);
    }

    function test_verdictCounts_trackCorrectly() public {
        vm.startPrank(council);
        registry.postValidation(agentId, "pass", "ctx", "uri", bytes32(0));
        registry.postValidation(agentId, "pass", "ctx", "uri", bytes32(0));
        registry.postValidation(agentId, "concern", "ctx", "uri", bytes32(0));
        registry.postValidation(agentId, "block", "ctx", "uri", bytes32(0));
        vm.stopPrank();

        (uint256 passes, uint256 total) = registry.getPassRate(agentId);
        assertEq(passes, 2);
        assertEq(total, 4);
    }

    function test_identityRegistry_address() public view {
        assertEq(registry.getIdentityRegistry(), address(identityRegistry));
    }

    function test_getValidations_returnsAll() public {
        vm.startPrank(council);
        registry.postValidation(agentId, "pass", "ctx1", "uri1", bytes32(uint256(1)));
        registry.postValidation(agentId, "concern", "ctx2", "uri2", bytes32(uint256(2)));
        vm.stopPrank();

        ValidationRegistry.ValidationEntry[] memory entries = registry.getValidations(agentId);
        assertEq(entries.length, 2);
        assertEq(entries[0].verdictStr, "pass");
        assertEq(entries[1].verdictStr, "concern");
    }
}
