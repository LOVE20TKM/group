// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {GroupDefaults} from "../../../src/GroupDefaults.sol";

contract DeployGroupDefaults is Script {
    function run() external {
        address groupAddress = vm.envAddress("GROUP_ADDRESS");

        console2.log("=== Deployment Parameters ===");
        console2.log("GROUP_ADDRESS:", groupAddress);

        vm.startBroadcast();

        GroupDefaults groupDefaults = new GroupDefaults(groupAddress);

        console2.log("GroupDefaults deployed at:", address(groupDefaults));

        vm.stopBroadcast();

        string memory network = vm.envOr("network", string("anvil"));
        string memory addressFile = string.concat("script/network/", network, "/address.group.defaults.params");

        string memory content = string.concat("groupDefaultsAddress=", vm.toString(address(groupDefaults)), "\n");

        vm.writeFile(addressFile, content);
        console2.log("Address saved to:", addressFile);

        console2.log("\n=== Deployment Summary ===");
        console2.log("GroupDefaults Address:", address(groupDefaults));
        console2.log("GROUP_ADDRESS:", groupAddress);
        console2.log("Network:", network);
    }
}
