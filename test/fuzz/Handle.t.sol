//SPDX-License-Identifier: MIT

//What are our invariants?

// 1. The total supply of DSC should be less than the total value of collateral

// 2. Getter view functions should never revert

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract Handle is Test {
    DSCEngine public dsce;
    DecentralizedStableCoin public dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;
    MockV3Aggregator ethUsdPriceFeed;

    uint256 public constant MAX_DEPOSIT_SIZE = type(uint96).max;

    // 跟踪存过抵押品的用户
    address[] public usersWithCollateral;
    mapping(address => bool) public hasCollateral;

    constructor(DSCEngine _dsce, DecentralizedStableCoin _dsc) {
        dsce = _dsce;
        dsc = _dsc;
        address[] memory collateralTokens = dsce.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(dsce.getCollateralTokenPriceFeed(address(weth)));
    }

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);
        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(dsce), amountCollateral);
        dsce.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();

        // 记录这个用户
        if (!hasCollateral[msg.sender]) {
            usersWithCollateral.push(msg.sender);
            hasCollateral[msg.sender] = true;
        }
    }

    function mintDsc(uint256 amount, uint256 addressSeed) public {
        if (usersWithCollateral.length == 0) {
            return;
        }

        // 从存过抵押品的用户中选一个
        address sender = usersWithCollateral[addressSeed % usersWithCollateral.length];

        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(sender);
        int256 maxDscToMint = (int256(collateralValueInUsd) / 2) - int256(totalDscMinted);
        if (maxDscToMint <= 0) {
            return;
        }
        amount = bound(amount, 0, uint256(maxDscToMint));
        if (amount == 0) {
            return;
        }
        vm.prank(sender);
        dsce.mintDsc(amount);
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral, uint256 addressSeed) public {
        if (usersWithCollateral.length == 0) {
            return;
        }

        // 从存过抵押品的用户中选一个
        address sender = usersWithCollateral[addressSeed % usersWithCollateral.length];

        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem = dsce.getCollateralBalanceOfUser(sender, address(collateral));

        // 检查用户有多少 DSC 债务
        (uint256 totalDscMinted,) = dsce.getAccountInformation(sender);
        if (totalDscMinted > 0) {
            // 如果有债务，计算最多能赎回多少（保持健康因子 >= 1）
            // 需要保留的抵押品价值 = totalDscMinted * 2（200% 抵押率）
            uint256 collateralValueToKeep = totalDscMinted * 2;
            uint256 currentCollateralValue = dsce.getUsdValue(address(collateral), maxCollateralToRedeem);

            if (currentCollateralValue <= collateralValueToKeep) {
                return; // 不能赎回任何抵押品
            }

            // 可以赎回的价值
            uint256 redeemableValue = currentCollateralValue - collateralValueToKeep;
            // 转换为抵押品数量
            uint256 redeemableAmount = dsce.getTokenAmountFromUsd(address(collateral), redeemableValue);
            maxCollateralToRedeem = redeemableAmount < maxCollateralToRedeem ? redeemableAmount : maxCollateralToRedeem;
        }

        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);
        if (amountCollateral == 0) {
            return;
        }
        vm.prank(sender);
        dsce.redeemCollateral(address(collateral), amountCollateral);
    }

    // If the price of ETH & BTC becomes very low, the whole system will be broken.
    // function updateEthPriceFeed(uint96 newPrice) public {
    //     int256 newPriceInt = bound(int256(uint256(newPrice)), 100e8, 10000e8);
    //     ethUsdPriceFeed.updateAnswer(newPriceInt);
    // }

    // Helper Function //
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }
}
