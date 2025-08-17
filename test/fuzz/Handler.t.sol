// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";

contract Handler is Test {
    DSCEngine dscEngine;
    DecentralizedStableCoin dscToken;
    HelperConfig helperConfig;

    uint256 public timesMintIsCalled = 0;
    address[] userWithDeposits;
    

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dscToken, HelperConfig _helperConfig) {
        dscEngine = _dscEngine;
        dscToken = _dscToken;
        helperConfig = _helperConfig;
    }

    function mintDsc(uint256 amount, uint256 addressSeed) public {
        if(userWithDeposits.length == 0) return;
        address user = userWithDeposits[addressSeed % userWithDeposits.length];
        (uint256 collateralValueInUSD, uint256 DscMinted) = dscEngine.getAccountInformation(user);
        int256 maxDscToMinted = int256((collateralValueInUSD / 2) - DscMinted);
        vm.assume(maxDscToMinted > 0);
        vm.assume(amount < uint256(maxDscToMinted) && amount > 0 && amount < 1e32);

        vm.prank(user);
        dscEngine.mintDsc(amount);
        timesMintIsCalled++;
    }

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        vm.assume(amountCollateral > 0 && amountCollateral < 1e32);
        address[] memory collateralTokens = helperConfig.getCollateralTokens();
        uint256 index = collateralSeed % collateralTokens.length;

        vm.startPrank(msg.sender);
        ERC20Mock(collateralTokens[index]).mint(msg.sender, amountCollateral);
        ERC20Mock(collateralTokens[index]).approve(address(dscEngine), amountCollateral);
        dscEngine.depositCollateral(collateralTokens[index], amountCollateral);
        vm.stopPrank();
        userWithDeposits.push(msg.sender);
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        address[] memory collateralTokens = helperConfig.getCollateralTokens();
        address[] memory priceFeeds = helperConfig.getPriceFeeds();

        uint256 index = collateralSeed % collateralTokens.length;
        uint256 maxRedeem = dscEngine.getCollateralBalanceOfUser(msg.sender, collateralTokens[index]);
        vm.assume(amountCollateral > 0 && amountCollateral <= maxRedeem);

        (uint256 collateralValueInUSD, uint256 DscMinted) = dscEngine.getAccountInformation(msg.sender);
        uint256 afterRedeemCollateralValueInUSD = collateralValueInUSD - dscEngine.getUSD(priceFeeds[index], amountCollateral, collateralTokens[index]);

        uint256 healthFactor = type(uint256).max;
        if (DscMinted > 0) {
            healthFactor = (afterRedeemCollateralValueInUSD * 50) / (100 * DscMinted) * 1e18;
        }
        vm.assume(healthFactor >= 1e18);

        vm.prank(msg.sender);
        dscEngine.redeemCollateral(collateralTokens[index], amountCollateral);
    }

    // function updateETHPrice(uint96 newPrice) public {
    //     address[] memory collateralTokens = helperConfig.getCollateralTokens();
    //     MockV3Aggregator ethPriceFeed = MockV3Aggregator(helperConfig.getPriceFeeds()[0]);
    //     ethPriceFeed.updateAnswer(int256(uint256(newPrice)));
    // }

}
