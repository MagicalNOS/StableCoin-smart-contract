// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address[] collateralTokens;
        address[] priceFeeds;
    }

    NetworkConfig private activeNetworkConfig;

    function getCollateralTokens() external view returns (address[] memory) {
        return activeNetworkConfig.collateralTokens;
    }

    function getPriceFeeds() external view returns (address[] memory) {
        return activeNetworkConfig.priceFeeds;
    }

    function getConfig() external returns (NetworkConfig memory) {
        if (block.chainid == 43113) {
            activeNetworkConfig = getFujiConfig();
        } else if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
        } else if (block.chainid == 1) {
            activeNetworkConfig = getMainnetConfig();
        } else {
            activeNetworkConfig = getAnvilConfig();
        }

        return activeNetworkConfig;
    }

    function getFujiConfig() internal pure returns (NetworkConfig memory) {
        address ETH_USD = 0x86d67c3D38D2bCeE722E601025C25a575021c6EA;
        address BTC_USD = 0x31CF013A08c6Ac228C94551d535d5BAfE19c602a;

        address WETH = 0x416bE990e917D3C4A37E98F883997177A713E956;
        address WBTC = 0x6659540010416B8482b316d81364c0800EFdc573;

        NetworkConfig memory fujiConfig;
        fujiConfig.collateralTokens = new address[](2);
        fujiConfig.collateralTokens[0] = WETH;
        fujiConfig.collateralTokens[1] = WBTC;

        fujiConfig.priceFeeds = new address[](2);
        fujiConfig.priceFeeds[0] = ETH_USD;
        fujiConfig.priceFeeds[1] = BTC_USD;

        return fujiConfig;
    }

    function getSepoliaConfig() internal pure returns (NetworkConfig memory) {
        address ETH_USD = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
        address BTC_USD = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;

        address WETH = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
        address WBTC = 0xBc84804aF5962b6aA9aDb1A5855298fD98018EE7;

        NetworkConfig memory sepoliaConfig;
        sepoliaConfig.collateralTokens = new address[](2);
        sepoliaConfig.collateralTokens[0] = WETH;
        sepoliaConfig.collateralTokens[1] = WBTC;

        sepoliaConfig.priceFeeds = new address[](2);
        sepoliaConfig.priceFeeds[0] = ETH_USD;
        sepoliaConfig.priceFeeds[1] = BTC_USD;

        return sepoliaConfig;
    }

    function getAnvilConfig() internal returns (NetworkConfig memory) {
        address ETH_USD = address(new MockV3Aggregator(8, 473344752324));
        address BTC_USD = address(new MockV3Aggregator(8, 12183727828922));
        address WETH = address(new ERC20Mock("Wrapped Ether", "WETH", msg.sender, 1000e8));
        address WBTC = address(new ERC20Mock("Wrapped Bitcoin", "WBTC", msg.sender, 1000e8));

        NetworkConfig memory anvilConfig;
        anvilConfig.collateralTokens = new address[](2);
        anvilConfig.collateralTokens[0] = WETH;
        anvilConfig.collateralTokens[1] = WBTC;

        anvilConfig.priceFeeds = new address[](2);
        anvilConfig.priceFeeds[0] = ETH_USD;
        anvilConfig.priceFeeds[1] = BTC_USD;

        return anvilConfig;
    }

    function getMainnetConfig() internal pure returns (NetworkConfig memory) {
        address ETH_USD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
        address BTC_USD = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;

        address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

        NetworkConfig memory MainnetConfig;
        MainnetConfig.collateralTokens = new address[](2);
        MainnetConfig.collateralTokens[0] = WETH;
        MainnetConfig.collateralTokens[1] = WBTC;

        MainnetConfig.priceFeeds = new address[](2);
        MainnetConfig.priceFeeds[0] = ETH_USD;
        MainnetConfig.priceFeeds[1] = BTC_USD;

        return MainnetConfig;
    }
}
