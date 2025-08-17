// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// 1. The total supply of DSC should be less than the total value of collateral
// 2. Getter view function should never revert

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {Handler} from "test/fuzz/Handler.t.sol";

contract Invariants is StdInvariant, Test {
    DSCEngine dscEngine;
    DecentralizedStableCoin dscToken;
    DeployDSC deployer;
    HelperConfig helperConfig;
    Handler handler;
    address weth;
    address eth_pricefeed;
    address btc_pricefeed;
    address wbtc;
    address USER = makeAddr("user");

    function setUp() external {
        deployer = new DeployDSC();
        (dscEngine, dscToken, helperConfig) = deployer.run();

        weth = helperConfig.getCollateralTokens()[0];
        wbtc = helperConfig.getCollateralTokens()[1];
        eth_pricefeed = helperConfig.getPriceFeeds()[0];
        btc_pricefeed = helperConfig.getPriceFeeds()[1];
        
        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, 1 ether * 10);
        ERC20Mock(weth).approve(address(dscEngine), 1 ether * 10);
        dscEngine.depositCollateralAndMintDsc(weth, 1 ether, 500 ether);
        vm.stopPrank();
        // targetContract(address(dscEngine));

        handler = new Handler(dscEngine, dscToken, helperConfig);
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        uint256 totalSupply = dscToken.totalSupply();
        uint256 totalWethDeposit = IERC20(weth).balanceOf(address(dscEngine));
        uint256 totalWbtcDeposit = IERC20(wbtc).balanceOf(address(dscEngine));
        uint256 wethValue = dscEngine.getUSD(eth_pricefeed, totalWethDeposit, weth);
        uint256 wbtcValue = dscEngine.getUSD(btc_pricefeed, totalWbtcDeposit, wbtc);
        uint256 totalCollateralValue = wethValue + wbtcValue;

        console.log(dscToken.totalSupply());
        console.log(handler.timesMintIsCalled());
        assert(totalCollateralValue > totalSupply);
    }



}