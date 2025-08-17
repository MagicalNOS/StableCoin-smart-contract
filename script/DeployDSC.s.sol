// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDSC is Script {
    function run() external returns (DSCEngine, DecentralizedStableCoin, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        vm.startBroadcast();
        DecentralizedStableCoin dscToken = new DecentralizedStableCoin();
        DSCEngine dscEngine = new DSCEngine(address(dscToken), config.collateralTokens, config.priceFeeds);
        dscToken.transferOwnership(address(dscEngine));
        vm.stopBroadcast();
        return (dscEngine, dscToken, helperConfig);
    }
}
