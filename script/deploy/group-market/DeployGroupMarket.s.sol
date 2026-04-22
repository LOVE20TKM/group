// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {GroupMarket} from "../../../src/GroupMarket.sol";
import {ILOVE20Group} from "../../../src/interfaces/ILOVE20Group.sol";
import {ILOVE20Token} from "../../../src/interfaces/ILOVE20Token.sol";

contract DeployGroupMarket is Script {
    function run() external {
        address groupAddress = vm.envAddress("GROUP_ADDRESS");
        address love20TokenAddress = vm.envAddress("LOVE20_TOKEN_ADDRESS");

        console2.log("=== Deployment Parameters ===");
        console2.log("GROUP_ADDRESS:", groupAddress);
        console2.log("LOVE20_TOKEN_ADDRESS:", love20TokenAddress);

        vm.startBroadcast();

        GroupMarket groupMarket = new GroupMarket(ILOVE20Group(groupAddress), ILOVE20Token(love20TokenAddress));

        console2.log("GroupMarket deployed at:", address(groupMarket));

        vm.stopBroadcast();

        string memory network = vm.envOr("network", string("anvil"));
        string memory addressFile = string.concat(
            "script/network/",
            network,
            "/address.group.market.params"
        );

        string memory content = string.concat(
            "groupMarketAddress=",
            vm.toString(address(groupMarket)),
            "\n"
        );

        vm.writeFile(addressFile, content);
        console2.log("Address saved to:", addressFile);

        console2.log("\n=== Deployment Summary ===");
        console2.log("GroupMarket Address:", address(groupMarket));
        console2.log("GROUP_ADDRESS:", groupAddress);
        console2.log("LOVE20_TOKEN_ADDRESS:", love20TokenAddress);
        console2.log("Network:", network);
    }
}
