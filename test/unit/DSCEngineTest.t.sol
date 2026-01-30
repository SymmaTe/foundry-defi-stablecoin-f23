//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
    DeployDSC public deploy;
    DecentralizedStableCoin public dsc;
    DSCEngine public dscEngine;
    HelperConfig public config;
    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;

    address public USER = makeAddr("user");
    uint256 public constant COLLATERAL_AMOUNT = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);

    event CollateralRedeemed(
        address indexed redeemFrom, address indexed redeemTo, address indexed token, uint256 amount
    );

    function setUp() external {
        deploy = new DeployDSC();
        (dsc, dscEngine, config) = deploy.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    // Constructor Test //
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    // Price Feed Tests //
    function testGetUsdValue() public view {
        // Arrange
        uint256 ethAmount = 15e18; // 15 ETH

        // Act
        uint256 usdValue = dscEngine.getUsdValue(weth, ethAmount);
        uint256 expectedUsdValue = 30000e18; // 15 ETH * $2000/ETH = $30000

        // Assert
        assertEq(usdValue, expectedUsdValue);
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;

        uint256 ethValue = dscEngine.getTokenAmountFromUsd(weth, usdAmount);
        uint256 expectedEthValue = 0.05 ether; // $100 / $2000/ETH = 0.05 ETH

        assertEq(ethValue, expectedEthValue);
    }

    // Deposit Collateral Tests //
    modifier depositCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        dscEngine.depositCollateral(weth, COLLATERAL_AMOUNT);
        vm.stopPrank();
        _;
    }

    function testRevertsIfNotApproved() public {
        vm.startPrank(USER);
        vm.expectRevert();
        dscEngine.depositCollateral(weth, COLLATERAL_AMOUNT);
        vm.stopPrank();
    }

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsIfTokenNotAllowed() public {
        ERC20Mock ranToken = new ERC20Mock("RAN", "RAN", 18);
        ERC20Mock(ranToken).mint(USER, STARTING_ERC20_BALANCE);
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dscEngine.depositCollateral(address(ranToken), COLLATERAL_AMOUNT);
        vm.stopPrank();
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(USER);
        uint256 expectedTotalDscMinted = 0;
        uint256 expectedCollateralValueInUsd = dscEngine.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(COLLATERAL_AMOUNT, expectedCollateralValueInUsd);
    }

    function testEmitCollateralDeposited() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        vm.expectEmit(true, true, false, true, address(dscEngine));
        emit CollateralDeposited(USER, weth, COLLATERAL_AMOUNT);
        dscEngine.depositCollateral(weth, COLLATERAL_AMOUNT);
        vm.stopPrank();
    }

    function testDepositCollateralUpdatesContractBalance() public depositCollateral {
        uint256 contractBalance = ERC20Mock(weth).balanceOf(address(dscEngine));
        assertEq(contractBalance, COLLATERAL_AMOUNT);
    }

    function testCanDepositMultipleTimes() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        dscEngine.depositCollateral(weth, COLLATERAL_AMOUNT / 2);
        dscEngine.depositCollateral(weth, COLLATERAL_AMOUNT / 2);
        vm.stopPrank();

        (, uint256 collateralValue) = dscEngine.getAccountInformation(USER);
        uint256 expectedValue = dscEngine.getUsdValue(weth, COLLATERAL_AMOUNT);
        assertEq(collateralValue, expectedValue);
    }

    function testCanDepositBothWethAndWbtc() public {
        // Arrange - 给 USER mint wbtc
        ERC20Mock(wbtc).mint(USER, COLLATERAL_AMOUNT);

        // Act - 质押 weth 和 wbtc
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        ERC20Mock(wbtc).approve(address(dscEngine), COLLATERAL_AMOUNT);
        dscEngine.depositCollateral(weth, COLLATERAL_AMOUNT);
        dscEngine.depositCollateral(wbtc, COLLATERAL_AMOUNT);
        vm.stopPrank();

        // Assert - 验证总价值 = weth价值 + wbtc价值
        (, uint256 totalCollateralValue) = dscEngine.getAccountInformation(USER);
        uint256 expectedWethValue = dscEngine.getUsdValue(weth, COLLATERAL_AMOUNT);
        uint256 expectedWbtcValue = dscEngine.getUsdValue(wbtc, COLLATERAL_AMOUNT);
        uint256 expectedTotalValue = expectedWethValue + expectedWbtcValue;

        assertEq(totalCollateralValue, expectedTotalValue);

        // Assert - 验证合约余额
        uint256 wethBalance = ERC20Mock(weth).balanceOf(address(dscEngine));
        uint256 wbtcBalance = ERC20Mock(wbtc).balanceOf(address(dscEngine));
        assertEq(wethBalance, COLLATERAL_AMOUNT);
        assertEq(wbtcBalance, COLLATERAL_AMOUNT);
    }

    // mint DSC test //
    // 10 ETH * $2000 = $20000 抵押物
    // 200% 超额抵押率，最多铸造 $10000 DSC
    uint256 public constant AMOUNT_TO_MINT = 100 ether; // $100 DSC

    function testRevertsIfMintAmountIsZero() public depositCollateral {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.mintDsc(0);
        vm.stopPrank();
    }

    function testRevertsIfMintBreaksHealthFactor() public depositCollateral {
        // 10 ETH = $20000, 超额抵押率200%，最多铸造 $10000
        // 尝试铸造超过限制的 DSC
        uint256 collateralValueInUsd = dscEngine.getUsdValue(weth, COLLATERAL_AMOUNT);
        // 计算最大可铸造量 (50% of collateral value)
        uint256 maxMintable = collateralValueInUsd / 2;
        uint256 amountToMint = maxMintable + 1; // 超过限制

        vm.startPrank(USER);
        vm.expectRevert();
        dscEngine.mintDsc(amountToMint);
        vm.stopPrank();
    }

    function testCanMintDsc() public depositCollateral {
        vm.startPrank(USER);
        dscEngine.mintDsc(AMOUNT_TO_MINT);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, AMOUNT_TO_MINT);
    }

    function testMintDscUpdatesAccountInfo() public depositCollateral {
        vm.startPrank(USER);
        dscEngine.mintDsc(AMOUNT_TO_MINT);
        vm.stopPrank();

        (uint256 totalDscMinted,) = dscEngine.getAccountInformation(USER);
        assertEq(totalDscMinted, AMOUNT_TO_MINT);
    }

    // redeemCollateral test //
    function testRevertsIfRedeemAmountIsZero() public depositCollateral {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testCanRedeemCollateral() public depositCollateral {
        vm.startPrank(USER);
        dscEngine.redeemCollateral(weth, COLLATERAL_AMOUNT);
        vm.stopPrank();

        uint256 userBalance = ERC20Mock(weth).balanceOf(USER);
        assertEq(userBalance, COLLATERAL_AMOUNT);
    }

    function testRedeemCollateralUpdatesAccountInfo() public depositCollateral {
        vm.startPrank(USER);
        dscEngine.redeemCollateral(weth, COLLATERAL_AMOUNT);
        vm.stopPrank();

        (, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(USER);
        assertEq(collateralValueInUsd, 0);
    }

    function testEmitCollateralRedeemed() public depositCollateral {
        vm.startPrank(USER);
        vm.expectEmit(true, true, true, true, address(dscEngine));
        emit CollateralRedeemed(USER, USER, weth, COLLATERAL_AMOUNT);
        dscEngine.redeemCollateral(weth, COLLATERAL_AMOUNT);
        vm.stopPrank();
    }

    // 质押并铸币后，赎回会破坏 health factor
    modifier depositAndMint() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        dscEngine.depositCollateral(weth, COLLATERAL_AMOUNT);
        dscEngine.mintDsc(AMOUNT_TO_MINT);
        vm.stopPrank();
        _;
    }

    function testRevertsIfRedeemBreaksHealthFactor() public depositAndMint {
        vm.startPrank(USER);
        vm.expectRevert();
        dscEngine.redeemCollateral(weth, COLLATERAL_AMOUNT); // 全部赎回会破坏 health factor
        vm.stopPrank();
    }

    // burnDsc test //
    function testRevertsIfBurnAmountIsZero() public depositAndMint {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.burnDsc(0);
        vm.stopPrank();
    }

    function testCanBurnDsc() public depositAndMint {
        vm.startPrank(USER);
        dsc.approve(address(dscEngine), AMOUNT_TO_MINT);
        dscEngine.burnDsc(AMOUNT_TO_MINT);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, 0);
    }

    function testBurnDscUpdatesAccountInfo() public depositAndMint {
        vm.startPrank(USER);
        dsc.approve(address(dscEngine), AMOUNT_TO_MINT);
        dscEngine.burnDsc(AMOUNT_TO_MINT);
        vm.stopPrank();

        (uint256 totalDscMinted,) = dscEngine.getAccountInformation(USER);
        assertEq(totalDscMinted, 0);
    }

    function testRevertsIfBurnMoreThanUserHas() public depositAndMint {
        vm.startPrank(USER);
        dsc.approve(address(dscEngine), AMOUNT_TO_MINT + 1);
        vm.expectRevert();
        dscEngine.burnDsc(AMOUNT_TO_MINT + 1);
        vm.stopPrank();
    }

    // depositCollateralAndMintDSC test //
    function testCanDepositCollateralAndMintDsc() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        dscEngine.depositCollateralAndMintDSC(weth, COLLATERAL_AMOUNT, AMOUNT_TO_MINT);
        vm.stopPrank();

        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(USER);
        assertEq(totalDscMinted, AMOUNT_TO_MINT);
        assertEq(collateralValueInUsd, dscEngine.getUsdValue(weth, COLLATERAL_AMOUNT));
    }

    // redeemCollateralForDSC test //
    function testCanRedeemCollateralForDsc() public depositAndMint {
        vm.startPrank(USER);
        dsc.approve(address(dscEngine), AMOUNT_TO_MINT);
        dscEngine.redeemCollateralForDSC(weth, COLLATERAL_AMOUNT, AMOUNT_TO_MINT);
        vm.stopPrank();

        uint256 userWethBalance = ERC20Mock(weth).balanceOf(USER);
        uint256 userDscBalance = dsc.balanceOf(USER);
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(USER);

        assertEq(userWethBalance, COLLATERAL_AMOUNT);
        assertEq(userDscBalance, 0);
        assertEq(totalDscMinted, 0);
        assertEq(collateralValueInUsd, 0);
    }

    // liquidate test //
    address public LIQUIDATOR = makeAddr("liquidator");
    uint256 public constant LIQUIDATOR_COLLATERAL = 100 ether;

    function testRevertsIfLiquidateAmountIsZero() public depositAndMint {
        vm.startPrank(LIQUIDATOR);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.liquidate(weth, USER, 0);
        vm.stopPrank();
    }

    function testRevertsIfHealthFactorOk() public depositAndMint {
        // USER is healthy, can't be liquidated
        ERC20Mock(weth).mint(LIQUIDATOR, LIQUIDATOR_COLLATERAL);
        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(dscEngine), LIQUIDATOR_COLLATERAL);
        dscEngine.depositCollateralAndMintDSC(weth, LIQUIDATOR_COLLATERAL, AMOUNT_TO_MINT);
        dsc.approve(address(dscEngine), AMOUNT_TO_MINT);

        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        dscEngine.liquidate(weth, USER, AMOUNT_TO_MINT);
        vm.stopPrank();
    }

    uint256 public constant USER_DEBT = 8000 ether; // $8000 DSC (leaves room for liquidation bonus)

    modifier liquidationSetup() {
        // USER deposits 10 ETH and mints $8000 DSC (not max, to leave room for bonus)
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        dscEngine.depositCollateral(weth, COLLATERAL_AMOUNT);
        dscEngine.mintDsc(USER_DEBT);
        vm.stopPrank();

        // Setup liquidator with collateral and DSC
        ERC20Mock(weth).mint(LIQUIDATOR, LIQUIDATOR_COLLATERAL);
        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(dscEngine), LIQUIDATOR_COLLATERAL);
        dscEngine.depositCollateralAndMintDSC(weth, LIQUIDATOR_COLLATERAL, USER_DEBT);
        vm.stopPrank();

        // Price drops: $2000 -> $1000 (USER becomes undercollateralized)
        // Collateral: 10 ETH @ $1000 = $10,000
        // Debt: $8,000
        // HF = ($10,000 * 50%) / $8,000 = 0.625 < 1 (undercollateralized)
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(1000e8);
        _;
    }

    function testCanLiquidate() public liquidationSetup {
        // USER health factor is now < 1, can be liquidated
        vm.startPrank(LIQUIDATOR);
        dsc.approve(address(dscEngine), USER_DEBT);
        dscEngine.liquidate(weth, USER, USER_DEBT);
        vm.stopPrank();

        // Verify USER's debt is cleared
        (uint256 userDscMinted,) = dscEngine.getAccountInformation(USER);
        assertEq(userDscMinted, 0);
    }

    function testLiquidatorGetsCollateralWithBonus() public liquidationSetup {
        uint256 liquidatorWethBefore = ERC20Mock(weth).balanceOf(LIQUIDATOR);

        vm.startPrank(LIQUIDATOR);
        dsc.approve(address(dscEngine), USER_DEBT);
        dscEngine.liquidate(weth, USER, USER_DEBT);
        vm.stopPrank();

        uint256 liquidatorWethAfter = ERC20Mock(weth).balanceOf(LIQUIDATOR);

        // At $1000/ETH: $8000 debt = 8 ETH
        // 10% bonus = 0.8 ETH
        // Total = 8.8 ETH
        uint256 expectedCollateral = dscEngine.getTokenAmountFromUsd(weth, USER_DEBT);
        uint256 expectedBonus = expectedCollateral / 10; // 10% bonus
        uint256 expectedTotal = expectedCollateral + expectedBonus;

        assertEq(liquidatorWethAfter - liquidatorWethBefore, expectedTotal);
    }

    function testLiquidationImprovesHealthFactor() public liquidationSetup {
        vm.startPrank(LIQUIDATOR);
        dsc.approve(address(dscEngine), USER_DEBT);
        dscEngine.liquidate(weth, USER, USER_DEBT);
        vm.stopPrank();

        // After liquidation: debt = 0, so health factor = infinite (type(uint256).max)
        // USER still has some collateral left (10 - 8.8 = 1.2 ETH)
        // At $1000/ETH: 1.2 ETH = $1200
        (, uint256 collateralValueAfter) = dscEngine.getAccountInformation(USER);

        // Calculate expected remaining: 10 ETH - 8.8 ETH = 1.2 ETH
        uint256 collateralTaken = dscEngine.getTokenAmountFromUsd(weth, USER_DEBT);
        uint256 bonus = collateralTaken / 10;
        uint256 totalTaken = collateralTaken + bonus; // 8.8 ETH
        uint256 remainingCollateral = COLLATERAL_AMOUNT - totalTaken; // 1.2 ETH
        uint256 expectedValue = dscEngine.getUsdValue(weth, remainingCollateral); // $1200

        assertEq(collateralValueAfter, expectedValue);
    }

    // Multi-collateral liquidation test
    function testCanLiquidateWithMultipleCollaterals() public {
        // USER deposits both WETH and WBTC
        ERC20Mock(wbtc).mint(USER, COLLATERAL_AMOUNT);

        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), COLLATERAL_AMOUNT);
        ERC20Mock(wbtc).approve(address(dscEngine), COLLATERAL_AMOUNT);
        dscEngine.depositCollateral(weth, COLLATERAL_AMOUNT); // 10 ETH @ $2000 = $20,000
        dscEngine.depositCollateral(wbtc, COLLATERAL_AMOUNT); // 10 BTC @ $1000 = $10,000
        // Total collateral: $30,000, max mint = $15,000
        dscEngine.mintDsc(12000 ether); // Mint $12,000 DSC
        vm.stopPrank();

        // Setup liquidator
        ERC20Mock(weth).mint(LIQUIDATOR, LIQUIDATOR_COLLATERAL);
        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(dscEngine), LIQUIDATOR_COLLATERAL);
        dscEngine.depositCollateralAndMintDSC(weth, LIQUIDATOR_COLLATERAL, 12000 ether);
        vm.stopPrank();

        // Price drops: ETH $2000 -> $800 (USER becomes undercollateralized)
        // New collateral value: 10 ETH @ $800 + 10 BTC @ $1000 = $8,000 + $10,000 = $18,000
        // HF = ($18,000 * 50%) / $12,000 = 0.75 < 1 (undercollateralized)
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(800e8);

        // Liquidator chooses to take WBTC (not WETH)
        // Must cover enough debt so user's health factor goes above 1
        // Covering $9000: takes 9.9 BTC, leaves user with $8000 ETH + $100 BTC = $8100
        // HF = ($8100 * 0.5) / $3000 = 1.35 > 1
        uint256 debtToCover = 9000 ether;
        uint256 liquidatorBtcBefore = ERC20Mock(wbtc).balanceOf(LIQUIDATOR);

        vm.startPrank(LIQUIDATOR);
        dsc.approve(address(dscEngine), debtToCover);
        dscEngine.liquidate(wbtc, USER, debtToCover); // <-- Choose WBTC as collateral
        vm.stopPrank();

        uint256 liquidatorBtcAfter = ERC20Mock(wbtc).balanceOf(LIQUIDATOR);

        // At $1000/BTC: $9000 debt = 9 BTC + 10% bonus = 9.9 BTC
        uint256 expectedBtc = dscEngine.getTokenAmountFromUsd(wbtc, debtToCover);
        uint256 expectedBonus = expectedBtc / 10;
        uint256 expectedTotal = expectedBtc + expectedBonus;

        assertEq(liquidatorBtcAfter - liquidatorBtcBefore, expectedTotal);

        // USER's debt is reduced
        (uint256 userDebt,) = dscEngine.getAccountInformation(USER);
        assertEq(userDebt, 3000 ether); // 12000 - 9000 = 3000
    }
}
