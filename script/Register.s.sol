// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";

interface IIdentityRegistry {
    function register(string calldata agentURI) external returns (uint256 agentId);
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract Register is Script {
    address constant IDENTITY_REGISTRY_BASE_MAINNET = 0x8004A169FB4a3325136EB29fA0ceB6D2e539a432;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address identityRegistry = vm.envOr("IDENTITY_REGISTRY", IDENTITY_REGISTRY_BASE_MAINNET);
        string memory agentURI = vm.envOr(
            "AGENT_URI",
            string("https://oracle.b1e55ed.permanentupperclass.com/.well-known/agent-registration.json")
        );

        vm.startBroadcast(deployerPrivateKey);

        IIdentityRegistry registry = IIdentityRegistry(identityRegistry);
        uint256 agentId = registry.register(agentURI);

        console.log("b1e55ed registered! agentId:", agentId);
        console.log("Identity Registry:", identityRegistry);
        console.log("Agent URI:", agentURI);

        vm.stopBroadcast();
    }
}
