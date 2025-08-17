// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.18;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "src/libraries/OracleLib.sol";

contract DSCEngine is ReentrancyGuard {
    error DSCEngine__MustBeMoreThanZero();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreakHealthFactor(uint256 healthFactor);
    error DSCEngine__ArrayLengthMismatch();
    error DSCEngine__MintFailed();
    error DSCEngine__BurnFailed();
    error DSCEngine__NotZeroAddress();
    error DSCEngine__HealthNotImproved();
    error DSCEngine__HealthFactorBelowThreshold();

    using OracleLib for AggregatorV3Interface;

    // To price feed
    DecentralizedStableCoin private immutable i_dscToken;
    mapping(address => address) private s_priceFeeds;
    mapping(address => mapping(address => uint256)) private s_collateralDeposits;
    // USER->TokenAddress->Amount
    mapping(address => uint256) private s_dscMinted;
    address[] private s_collateralTokens;
    uint256 private constant ADDITIONAL_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_THRESHOLD_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10;
    uint256 private constant LIQUIDATION_BONUS_PRECISION = 100;

    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralWithdrawn(address indexed user, address indexed token, uint256 amount);
    event CollateralRedeemed(
        address indexed token, uint256 amount, address indexed redeemFrom, address indexed redeemTo
    );

    modifier moreThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert DSCEngine__MustBeMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address _token) {
        if (s_priceFeeds[_token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    constructor(address _dscToken, address[] memory tokenAddress, address[] memory priceFeedAddress) {
        if (tokenAddress.length != priceFeedAddress.length) {
            revert DSCEngine__ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < tokenAddress.length; i++) {
            s_priceFeeds[tokenAddress[i]] = priceFeedAddress[i];
            s_collateralTokens.push(tokenAddress[i]);
        }
        i_dscToken = DecentralizedStableCoin(_dscToken);
    }

    /**
     * @notice Deposit collateral and mint DSC in a single transaction
     * @param collateralToken The address of the collateral token
     * @param amountCollateral The amount of collateral to deposit
     * @param amountDscToMint The amount of DSC to mint
     */
    function depositCollateralAndMintDsc(address collateralToken, uint256 amountCollateral, uint256 amountDscToMint)
        external
    {
        depositCollateral(collateralToken, amountCollateral);
        mintDsc(amountDscToMint);
    }

    /**
     * @notice follow CEI()
     * @param tokenCollateralAddress The address of the collateral token
     * @param amountCollateral The amount of collateral to deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        // Logic to deposit collateral
        s_collateralDeposits[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /**
     * @param tokenCollateral The address of the collateral token
     * @param amountCollateral The amount of collateral to redeem
     * @param amountDscToBurn The amount of DSC to burn
     */
    function redeemCollateralForDsc(address tokenCollateral, uint256 amountCollateral, uint256 amountDscToBurn)
        external
        moreThanZero(amountCollateral)
        moreThanZero(amountDscToBurn)
        isAllowedToken(tokenCollateral)
    {
        burnDsc(amountDscToBurn);
        redeemCollateral(tokenCollateral, amountCollateral);
    }

    /**
     * @notice Redeem collateral
     * @param tokenCollateral The address of the collateral token
     * @param amount The amount of collateral to redeem
     */
    function redeemCollateral(address tokenCollateral, uint256 amount) public nonReentrant() {
        _redeemCollateral(tokenCollateral, amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsLow(msg.sender);
    }

    function burnDsc(uint256 amountDscToBurn) public nonReentrant {
        _burnDsc(amountDscToBurn, msg.sender, msg.sender);
        _revertIfHealthFactorIsLow(msg.sender);
    }

    /**
     * @notice follow CEI()
     * @param amountDscToMint The amount of decentralized stable coin to mint
     * @notice they must have more collateral value than the minimum threshold
     */
    function mintDsc(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {
        s_dscMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsLow(msg.sender);
        bool minted = i_dscToken.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    /**
     * @param collateral The address of the collateral token
     * @param user The address of the user to liquidate (healthFactor is to low)
     * @param debtToCover The amount of dsc you want to burn to improve the users health
     * @notice If the protocol were 100% or less collateralized, the user would be incentivized to liquidate.
     *         For example, the collateral price slump before people liquidate.
     */
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        isAllowedToken(collateral)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(user);

        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorBelowThreshold();
        }

        // Liquidation Steps:
        // 1. take their collateral
        // 2. and burn the dsc
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUSD(collateral, debtToCover);
        // give 10% bonus to liquidator
        uint256 bonusAmount = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_BONUS_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusAmount;
        _redeemCollateral(collateral, totalCollateralToRedeem, user, msg.sender);
        _burnDsc(debtToCover, user, msg.sender);
        uint256 endingUserHealthFactor = _healthFactor(user);

        if (endingUserHealthFactor <= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthNotImproved();
        }
        _revertIfHealthFactorIsLow(msg.sender);
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }
    /**
     * @dev Low-level internal function, do not call unless checking for health factors being brokens
     */

    function _burnDsc(uint256 amountDscToBurn, address onBehalfOf, address dscFrom)
        internal
        moreThanZero(amountDscToBurn)
    {
        s_dscMinted[onBehalfOf] -= amountDscToBurn;
        bool success = i_dscToken.transferFrom(dscFrom, address(this), amountDscToBurn);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dscToken.burn(amountDscToBurn);
    }

    function _redeemCollateral(address tokenCollateral, uint256 amount, address from, address to)
        internal
        moreThanZero(amount)
        isAllowedToken(tokenCollateral)
    {
        s_collateralDeposits[from][tokenCollateral] -= amount;
        emit CollateralRedeemed(tokenCollateral, amount, from, to);
        bool success = IERC20(tokenCollateral).transfer(to, amount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function _getAccountInformation(address user)
        internal
        view
        returns (uint256 totalCollateralValue, uint256 totalDscMinted)
    {
        totalCollateralValue = getAccountCollateralValue(user);
        totalDscMinted = s_dscMinted[user];
        return (totalCollateralValue, totalDscMinted);
    }

    function _healthFactor(address user) internal view returns (uint256) {
        // total DSC minted
        // total collateral VALUE

        (uint256 totalCollateralValue, uint256 totalDscMinted) = _getAccountInformation(user);
        // return (totalCollateralValue / totalDscMinted);
        if (totalDscMinted == 0) {
            return type(uint256).max; // No DSC minted, health factor is max
        }
        uint256 valueAdjustedForThreshold =
            (totalCollateralValue * LIQUIDATION_THRESHOLD) / LIQUIDATION_THRESHOLD_PRECISION;
        return (valueAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    function _revertIfHealthFactorIsLow(address user) internal view {
        uint256 healthFactor = _healthFactor(user);
        if (healthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreakHealthFactor(healthFactor);
        }
    }

    function getAccountCollateralValue(address user) public view returns (uint256) {
        uint256 totalCollateralValue = 0;
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address collateralToken = s_collateralTokens[i];
            uint256 collateralAmount = s_collateralDeposits[user][collateralToken];
            if (collateralAmount > 0) {
                address priceFeed = s_priceFeeds[collateralToken];
                totalCollateralValue += getUSD(priceFeed, collateralAmount, collateralToken);
            }
        }
        return totalCollateralValue;
    }

    function getUSD(address priceFeed, uint256 amount, address collateralToken) public view returns (uint256) {
        AggregatorV3Interface priceFeedInterface = AggregatorV3Interface(priceFeed);
        (, int256 answer,,,) = priceFeedInterface.stalePriceCheck();
        uint256 tokenPrice = uint256(answer);
        uint8 tokenDecimals = IERC20Metadata(collateralToken).decimals();
        return (tokenPrice * ADDITIONAL_PRECISION * amount * 1e18) / (PRECISION * (10 ** tokenDecimals));
    }

    function getTokenAmountFromUSD(address token, uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeedInterface = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 answer,,,) = priceFeedInterface.stalePriceCheck();
        uint256 tokenPrice = uint256(answer);
        uint256 tokenDecimals = IERC20Metadata(token).decimals();
        return (usdAmountInWei * PRECISION * (10 ** tokenDecimals)) / (tokenPrice * ADDITIONAL_PRECISION * 1e18);
    }

    function getCollateralBalanceOfUser(address user, address collateralToken)
        external
        view
        isAllowedToken(collateralToken)
        returns (uint256)
    {
        return s_collateralDeposits[user][collateralToken];
    }

    function getAccountInformation(address user) external view returns(uint256, uint256){
        (uint256 totalCollateralValue, uint256 totalDscMinted) = _getAccountInformation(user);
        return (totalCollateralValue, totalDscMinted);
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getPriceFeed(address collateralToken) external view isAllowedToken(collateralToken) returns (address) {
        return s_priceFeeds[collateralToken];
    }

    function getDscToken() external view returns (DecentralizedStableCoin) {
        return i_dscToken;
    }

    function getLiquidationThreshold() external view returns(uint256){
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationThresholdPrecision() external view returns(uint256){
        return LIQUIDATION_THRESHOLD_PRECISION;
    }

    function getLiquidationBonus() external view returns(uint256){
        return LIQUIDATION_BONUS;
    }

    function getLiquidationBonusPrecision() external view returns(uint256){
        return LIQUIDATION_BONUS_PRECISION;
    }

    function getMinHealthFactor() external view returns(uint256){
        return MIN_HEALTH_FACTOR;
    }
}