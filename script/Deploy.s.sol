// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ReputationRegistry} from "../src/ReputationRegistry.sol";
import {ValidationRegistry} from "../src/ValidationRegistry.sol";

contract Deploy is Script {
    // ERC-8004 Identity Registry — Base mainnet singleton
    address constant IDENTITY_REGISTRY_BASE_MAINNET = 0x8004A169FB4a3325136EB29fA0ceB6D2e539a432;

    // For Base Sepolia (testnet) — same address if deployed there, or deploy a mock
    address constant IDENTITY_REGISTRY_BASE_SEPOLIA = 0x8004A169FB4a3325136EB29fA0ceB6D2e539a432;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address identityRegistry = vm.envOr("IDENTITY_REGISTRY", IDENTITY_REGISTRY_BASE_SEPOLIA);

        vm.startBroadcast(deployerPrivateKey);

        ReputationRegistry reputation = new ReputationRegistry(identityRegistry);
        ValidationRegistry validation = new ValidationRegistry(identityRegistry);

        console.log("ReputationRegistry deployed at:", address(reputation));
        console.log("ValidationRegistry deployed at:", address(validation));
        console.log("Identity Registry bound to:", identityRegistry);

        vm.stopBroadcast();
    }
}
