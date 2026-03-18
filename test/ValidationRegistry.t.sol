// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ValidationRegistry} from "../src/ValidationRegistry.sol";

contract MockIdentityRegistry {
    function ownerOf(uint256) external pure returns (address) { return address(0x1234); }
}

contract ValidationRegistryTest is Test {
    ValidationRegistry public registry;
    MockIdentityRegistry public id;
    address council = address(0xc0de);
    uint256 agentId = 1;

    function setUp() public {
        id = new MockIdentityRegistry();
        registry = new ValidationRegistry(address(id));
    }

    function test_postValidation_pass() public {
        vm.prank(council);
        registry.postValidation(agentId, "pass", "https://github.com/P-U-C/b1e55ed/pull/353", "uri", keccak256("v"));
        assertEq(registry.getValidationCount(agentId), 1);
        (uint256 passes, uint256 total) = registry.getPassRate(agentId);
        assertEq(passes, 1);
        assertEq(total, 1);
    }

    function test_all_verdicts() public {
        vm.startPrank(council);
        registry.postValidation(agentId, "pass", "c", "u", bytes32(0));
        registry.postValidation(agentId, "concern", "c", "u", bytes32(0));
        registry.postValidation(agentId, "block", "c", "u", bytes32(0));
        registry.postValidation(agentId, "human-required", "c", "u", bytes32(0));
        vm.stopPrank();
        assertEq(registry.getValidationCount(agentId), 4);
    }

    function test_invalid_verdict_reverts() public {
        vm.prank(council);
        vm.expectRevert();
        registry.postValidation(agentId, "invalid", "c", "u", bytes32(0));
    }
}
