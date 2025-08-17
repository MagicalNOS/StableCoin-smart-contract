// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console, stdError} from "forge-std/Test.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract DSCEngineIntergrationTest is Test {
    DSCEngine dscEngine;
    DecentralizedStableCoin dscToken;
    DeployDSC deployer;
    HelperConfig helperConfig;
    address weth;
    address eth_pricefeed;
    address btc_pricefeed;
    address wbtc;

    address public USER = makeAddr("user");
    uint256 public WETH_AMOUNT = 1 ether;
    uint256 public WBTC_AMOUNT = 1e8;

    function setUp() external {
        deployer = new DeployDSC();
        (dscEngine, dscToken, helperConfig) = deployer.run();

        weth = helperConfig.getCollateralTokens()[0];
        wbtc = helperConfig.getCollateralTokens()[1];

        eth_pricefeed = helperConfig.getPriceFeeds()[0];
        btc_pricefeed = helperConfig.getPriceFeeds()[1];

        ERC20Mock(weth).mint(USER, WETH_AMOUNT * 10);
        ERC20Mock(wbtc).mint(USER, WBTC_AMOUNT * 10);
    }
}
