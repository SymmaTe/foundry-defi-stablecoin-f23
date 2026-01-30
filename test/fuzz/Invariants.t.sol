//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handle} from "../../test/fuzz/Handle.t.sol";

contract Invariants is StdInvariant, Test {
    DeployDSC public deployer;
    DSCEngine public dsce;
    DecentralizedStableCoin public dsc;
    HelperConfig public config;
    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;
    Handle public handle;

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc,) = config.activeNetworkConfig();
        handle = new Handle(dsce, dsc);
        targetContract(address(handle));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dsce));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(dsce));

        uint256 wethValue = dsce.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = dsce.getUsdValue(wbtc, totalWbtcDeposited);
        console.log("WETH Value:", wethValue);
        console.log("WBTC Value:", wbtcValue);
        console.log("Total Supply", totalSupply);

        assert(wbtcValue + wethValue >= totalSupply);
    }

    function invariant_getterFunctionNeverReverts() public view {
        dsce.getPrecision();
        dsce.getMinHealthFactor();
        dsce.getDsc();
        dsce.getLiquidationThreshold();
        dsce.getLiquidationBonus();
        dsce.getCollateralTokens();
    }
}
