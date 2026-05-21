// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {GroupDelegate} from "../../../src/GroupDelegate.sol";

contract DeployGroupDelegate is Script {
    function run() external {
        address groupAddress = vm.envAddress("GROUP_ADDRESS");

        console2.log("=== Deployment Parameters ===");
        console2.log("GROUP_ADDRESS:", groupAddress);

        vm.startBroadcast();

        GroupDelegate groupDelegate = new GroupDelegate(groupAddress);

        console2.log("GroupDelegate deployed at:", address(groupDelegate));

        vm.stopBroadcast();

        string memory network = vm.envOr("network", string("anvil"));
        string memory addressFile = string.concat("script/network/", network, "/address.group.delegate.params");

        string memory content = string.concat("groupDelegateAddress=", vm.toString(address(groupDelegate)), "\n");

        vm.writeFile(addressFile, content);
        console2.log("Address saved to:", addressFile);

        console2.log("\n=== Deployment Summary ===");
        console2.log("GroupDelegate Address:", address(groupDelegate));
        console2.log("GROUP_ADDRESS:", groupAddress);
        console2.log("Network:", network);
    }
}
