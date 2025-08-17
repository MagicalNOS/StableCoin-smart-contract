// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console, stdError} from "forge-std/Test.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract DSCEngineTest is Test {
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

    modifier onlyFork() {
        if (block.chainid == 31337) {
            return;
        }
        _;
    }

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

    function testDeployDSCEngineArrayLengthMismatch() external {
        address[] memory collateralTokens = new address[](2);
        address[] memory priceFeeds = new address[](1); // Mismatched length
        collateralTokens[0] = weth;
        collateralTokens[1] = wbtc;
        priceFeeds[0] = eth_pricefeed;

        vm.expectRevert(DSCEngine.DSCEngine__ArrayLengthMismatch.selector);
        new DSCEngine(address(dscToken), collateralTokens, priceFeeds);
    }

    //////////////////
    //view functions//
    //////////////////
    function testGetWETHTokenAmountFromUSD() external {
        uint256 usdAmount = (473344752324 * 1e10);
        uint256 expectedWETHAmount = 1e18;
        uint256 actualWETHAmount = dscEngine.getTokenAmountFromUSD(weth, usdAmount);
        assertEq(expectedWETHAmount, actualWETHAmount);
    }

    function testGetWBTCTokenAmountFromUSD() external {
        uint256 usdAmount = 12183727828922 * 1e10;
        uint256 expectedWBTCAmount = 1e18;
        uint256 actualWBTCAmount = dscEngine.getTokenAmountFromUSD(wbtc, usdAmount);
        assertEq(expectedWBTCAmount, actualWBTCAmount);
    }

    function testGetETHUSDValue() public view {
        uint256 expectedValue = (473344752324 * 1e10 * WETH_AMOUNT) / 1e18;
        uint256 actualValue = dscEngine.getUSD(eth_pricefeed, WETH_AMOUNT, weth);
        assertEq(actualValue, expectedValue);
    }

    function testGetBTCUSDValue() public view {
        uint256 expectedValue = (12183727828922 * 1e10 * WBTC_AMOUNT) / 1e18;
        console.log(ERC20Mock(wbtc).decimals());
        uint256 actualValue = dscEngine.getUSD(btc_pricefeed, WBTC_AMOUNT, wbtc);
        assertEq(actualValue, expectedValue);
    }

    function testGetWBTCUSDValueWith8Bit() public view onlyFork {
        uint256 expectedValue = (12183727828922 * 1e10 * 1e10 * WBTC_AMOUNT) / 1e18;
        uint256 actualValue = dscEngine.getUSD(btc_pricefeed, WBTC_AMOUNT, wbtc);
        assertEq(actualValue, expectedValue);
    }

    function testGetCollateralBalanceOfUser() external {
        // Setup: Deposit some collateral first
        uint256 collateralAmount = 10e18;
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), collateralAmount);
        dscEngine.depositCollateral(weth, collateralAmount);
        vm.stopPrank();

        // Test: Check balance
        uint256 actualBalance = dscEngine.getCollateralBalanceOfUser(USER, weth);
        uint256 expectedBalance = collateralAmount;
        assertEq(actualBalance, expectedBalance);
    }

    function testGetCollateralBalanceOfUserWithZeroBalance() external {
        // Test: Check balance for user who hasn't deposited
        uint256 actualBalance = dscEngine.getCollateralBalanceOfUser(USER, weth);
        uint256 expectedBalance = 0;
        assertEq(actualBalance, expectedBalance);
    }

    function testGetCollateralBalanceOfUserWithMultipleTokens() external {
        // Setup: Deposit different collateral tokens
        uint256 wethAmount = 5e18;
        uint256 wbtcAmount = 2e18;

        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, wethAmount);
        ERC20Mock(wbtc).mint(USER, wbtcAmount);
        ERC20Mock(weth).approve(address(dscEngine), wethAmount);
        ERC20Mock(wbtc).approve(address(dscEngine), wbtcAmount);
        dscEngine.depositCollateral(weth, wethAmount);
        dscEngine.depositCollateral(wbtc, wbtcAmount);
        vm.stopPrank();

        // Test: Check balances for both tokens
        uint256 actualWethBalance = dscEngine.getCollateralBalanceOfUser(USER, weth);
        uint256 actualWbtcBalance = dscEngine.getCollateralBalanceOfUser(USER, wbtc);

        assertEq(actualWethBalance, wethAmount);
        assertEq(actualWbtcBalance, wbtcAmount);
    }

    function testGetAccountInformation() external {
        // Setup: Deposit collateral and mint DSC
        uint256 collateralAmount = 20e18;
        uint256 dscToMint = 1000e18;

        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, collateralAmount);
        ERC20Mock(weth).approve(address(dscEngine), collateralAmount);
        dscEngine.depositCollateralAndMintDsc(weth, collateralAmount, dscToMint);
        vm.stopPrank();

        // Test: Get account information
        (uint256 totalCollateralValue, uint256 totalDscMinted) = dscEngine.getAccountInformation(USER);

        uint256 expectedCollateralValue = (473344752324 * 1e10 * collateralAmount) / 1e18;
        uint256 expectedDscMinted = dscToMint;

        assertEq(totalCollateralValue, expectedCollateralValue);
        assertEq(totalDscMinted, expectedDscMinted);
    }

    function testGetAccountInformationWithNoActivity() external {
        // Test: Get account information for user with no activity
        (uint256 totalCollateralValue, uint256 totalDscMinted) = dscEngine.getAccountInformation(USER);

        assertEq(totalCollateralValue, 0);
        assertEq(totalDscMinted, 0);
    }

    function testGetCollateralTokens() external {
        // Test: Get collateral tokens array
        address[] memory collateralTokens = dscEngine.getCollateralTokens();

        // Assuming weth and wbtc are the collateral tokens
        assertEq(collateralTokens.length, 2);
        assertEq(collateralTokens[0], weth);
        assertEq(collateralTokens[1], wbtc);
    }

    function testGetPriceFeed() external {
        // Test: Get price feed for WETH
        address actualWethPriceFeed = dscEngine.getPriceFeed(weth);
        assertEq(actualWethPriceFeed, eth_pricefeed);

        // Test: Get price feed for WBTC
        address actualWbtcPriceFeed = dscEngine.getPriceFeed(wbtc);
        assertEq(actualWbtcPriceFeed, btc_pricefeed);
    }

    function testGetPriceFeedRevertsForInvalidToken() external {
        // Test: Should revert for non-allowed token
        address invalidToken = makeAddr("invalidToken");

        vm.expectRevert();
        dscEngine.getPriceFeed(invalidToken);
    }

    function testGetDscToken() external {
        // Test: Get DSC token address
        DecentralizedStableCoin actualDscToken = dscEngine.getDscToken();
        assertEq(address(actualDscToken), address(dscToken));
    }

    function testGetLiquidationThreshold() external view {
        // Test: Get liquidation threshold (assuming it's 50%)
        uint256 actualThreshold = dscEngine.getLiquidationThreshold();
        uint256 expectedThreshold = 50; // 50%
        assertEq(actualThreshold, expectedThreshold);
    }

    function testGetLiquidationThresholdPrecision() external view {
        // Test: Get liquidation threshold precision
        uint256 actualPrecision = dscEngine.getLiquidationThresholdPrecision();
        uint256 expectedPrecision = 100; // Precision for percentage calculation
        assertEq(actualPrecision, expectedPrecision);
    }

    function testGetLiquidationBonus() external view {
        // Test: Get liquidation bonus (assuming it's 10%)
        uint256 actualBonus = dscEngine.getLiquidationBonus();
        uint256 expectedBonus = 10; // 10%
        assertEq(actualBonus, expectedBonus);
    }

    function testGetLiquidationBonusPrecision() external view {
        // Test: Get liquidation bonus precision
        uint256 actualPrecision = dscEngine.getLiquidationBonusPrecision();
        uint256 expectedPrecision = 100; // Precision for percentage calculation
        assertEq(actualPrecision, expectedPrecision);
    }

    function testGetMinHealthFactor() external view {
        // Test: Get minimum health factor (assuming it's 1e18)
        uint256 actualMinHealthFactor = dscEngine.getMinHealthFactor();
        uint256 expectedMinHealthFactor = 1e18; // 1.0 with 18 decimals
        assertEq(actualMinHealthFactor, expectedMinHealthFactor);
    }

    function testGetCollateralBalanceOfUserRevertsForInvalidToken() external {
        // Test: Should revert for non-allowed token
        address invalidToken = makeAddr("invalidToken");

        vm.expectRevert();
        dscEngine.getCollateralBalanceOfUser(USER, invalidToken);
    }

    function testGetAccountInformationWithMultipleCollaterals() external {
        // Setup: Deposit multiple types of collateral
        uint256 wethAmount = 10e18;
        uint256 wbtcAmount = 1e18;
        uint256 dscToMint = 5000e18;

        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, wethAmount);
        ERC20Mock(wbtc).mint(USER, wbtcAmount);
        ERC20Mock(weth).approve(address(dscEngine), wethAmount);
        ERC20Mock(wbtc).approve(address(dscEngine), wbtcAmount);

        dscEngine.depositCollateral(weth, wethAmount);
        dscEngine.depositCollateral(wbtc, wbtcAmount);
        dscEngine.mintDsc(dscToMint);
        vm.stopPrank();

        // Test: Get account information
        (uint256 totalCollateralValue, uint256 totalDscMinted) = dscEngine.getAccountInformation(USER);

        uint256 expectedWethValue = (473344752324 * 1e10 * wethAmount) / 1e18;
        uint256 expectedWbtcValue = (12183727828922 * 1e10 * wbtcAmount) / 1e18;
        uint256 expectedTotalCollateralValue = expectedWethValue + expectedWbtcValue;

        assertEq(totalCollateralValue, expectedTotalCollateralValue);
        assertEq(totalDscMinted, dscToMint);
    }

    /////////////////////
    //depositCollateral//
    /////////////////////
    function testDepositCollateralZeroAmount() external {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        dscEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testDepositCollateralNotAllowedToken() external {
        vm.startBroadcast();
        ERC20Mock notAllowedToken = new ERC20Mock("Not Allowed Token", "NAT", USER, 100 ether);
        vm.stopBroadcast();

        vm.prank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dscEngine.depositCollateral(address(notAllowedToken), 10 ether);
    }

    function testDepositCollateral() external {
        uint256 beforeDeposit = ERC20Mock(weth).balanceOf(USER);
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), WETH_AMOUNT);
        dscEngine.depositCollateral(weth, WETH_AMOUNT);
        vm.stopPrank();
        uint256 afterDeposit = ERC20Mock(weth).balanceOf(USER);
        assertEq(ERC20Mock(weth).balanceOf(address(dscEngine)), WETH_AMOUNT);
        assertEq(afterDeposit, beforeDeposit - WETH_AMOUNT);
    }

    /////////////////////
    //     mintDSC     //
    /////////////////////
    function testMintFailedDscWithoutCollateral() external {
        vm.expectRevert(abi.encodeWithSignature("DSCEngine__BreakHealthFactor(uint256)", 0));
        dscEngine.mintDsc(1 ether);
    }

    function testMintDscDirectly() external {
        vm.expectRevert((abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", USER)));
        vm.prank(USER);
        dscToken.mint(msg.sender, 1 ether);
    }

    function testMintDscOverCollateralValue() external {
        uint256 expectedHealthFactor =
            (dscEngine.getUSD(eth_pricefeed, WETH_AMOUNT, weth) * 50 * 1e18) / (100 * 5000 ether);
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), WETH_AMOUNT);
        dscEngine.depositCollateral(weth, WETH_AMOUNT);
        vm.expectRevert(abi.encodeWithSignature("DSCEngine__BreakHealthFactor(uint256)", expectedHealthFactor));
        dscEngine.mintDsc(5000 ether);
    }

    /////////////////////
    // redeemCollateral//
    /////////////////////
    function testRedeemCollateralWithoutDeposit() external {
        vm.startPrank(USER);
        vm.expectRevert(stdError.arithmeticError);
        dscEngine.redeemCollateral(weth, WETH_AMOUNT);
    }

    function testRedeemCollateralUserBalanceNotEnough() external {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), WETH_AMOUNT);
        dscEngine.depositCollateral(weth, WETH_AMOUNT);

        vm.expectRevert(stdError.arithmeticError);
        dscEngine.redeemCollateral(weth, WETH_AMOUNT * 2);
    }

    function testRedeemCollateral() external {
        uint256 beforeBalance = ERC20Mock(weth).balanceOf(USER);
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), WETH_AMOUNT);
        dscEngine.depositCollateral(weth, WETH_AMOUNT);
        dscEngine.redeemCollateral(weth, WETH_AMOUNT);
        vm.stopPrank();
        uint256 afterBalance = ERC20Mock(weth).balanceOf(USER);
        assertEq(ERC20Mock(weth).balanceOf(address(dscEngine)), 0);
        assertEq(afterBalance, beforeBalance);
    }

    /////////////////////
    //     burnDsc     //
    /////////////////////
    function testBurnDscWithoutEnoughBalance() external {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), WETH_AMOUNT);
        dscEngine.depositCollateral(weth, WETH_AMOUNT);
        dscEngine.mintDsc(100 ether);
        vm.expectRevert(stdError.arithmeticError);
        dscEngine.burnDsc(200 ether);
    }

    function testBurnDscWithoutDeposit() external {
        vm.startPrank(USER);
        vm.expectRevert(stdError.arithmeticError);
        dscEngine.burnDsc(100 ether);
    }

    function testBurnDsc() external {
        uint256 beforeBalance = dscToken.balanceOf(USER);
        uint256 beforeTotalSupply = dscToken.totalSupply();
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), WETH_AMOUNT);
        dscEngine.depositCollateral(weth, WETH_AMOUNT);
        dscEngine.mintDsc(100 ether);
        dscToken.approve(address(dscEngine), 10000 ether);
        dscEngine.burnDsc(50 ether);
        vm.stopPrank();
        uint256 afterBalance = dscToken.balanceOf(USER);
        assertEq(afterBalance, beforeBalance + 50 ether);
        assertEq(dscToken.totalSupply(), beforeTotalSupply + 50 ether);
    }

    function testRedeemCollateralForDsc() external {
        uint256 beforeETHBalance = ERC20Mock(weth).balanceOf(USER);
        uint256 beforeDscTokenBalance = dscToken.balanceOf(USER);
        vm.startPrank(USER);
        dscToken.approve(address(dscEngine), 10000 ether);
        ERC20Mock(weth).approve(address(dscEngine), WETH_AMOUNT);
        dscEngine.depositCollateral(weth, WETH_AMOUNT);
        dscEngine.mintDsc(100 ether);
        dscEngine.redeemCollateralForDsc(weth, WETH_AMOUNT, 100 ether);
        vm.stopPrank();

        assertEq(ERC20Mock(weth).balanceOf(USER), beforeETHBalance);
        assertEq(dscToken.balanceOf(USER), beforeDscTokenBalance);
        assertEq(ERC20Mock(weth).balanceOf(address(dscEngine)), 0);
        assertEq(dscToken.balanceOf(address(dscEngine)), 0);
    }

    /////////////////////
    //     liquidate   //
    /////////////////////
    function testLiquidateHealthUser() external {
        address liquidator = makeAddr("liquidator");
        vm.startPrank(liquidator);
        ERC20Mock(weth).mint(liquidator, WETH_AMOUNT * 10);
        ERC20Mock(weth).approve(address(dscEngine), WETH_AMOUNT * 10);
        dscEngine.depositCollateral(weth, WETH_AMOUNT * 10);
        dscEngine.mintDsc(10000 ether);
        dscToken.approve(address(dscEngine), 10000 ether);
        vm.stopPrank();

        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), WETH_AMOUNT);
        dscEngine.depositCollateral(weth, WETH_AMOUNT);
        dscEngine.mintDsc(2000 ether);
        vm.stopPrank();

        MockV3Aggregator(eth_pricefeed).updateAnswer(3900e8); // Simulate slump
        vm.startPrank(liquidator);
        dscEngine.liquidate(weth, USER, 1500 ether);
        vm.stopPrank();

        // profit is 150$, approximately
        console.log(dscEngine.getUSD(eth_pricefeed, ERC20Mock(weth).balanceOf(liquidator), weth));
    }
}
