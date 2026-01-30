//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {OracleLib} from "../../src/libraries/OracleLib.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract OracleLibTest is Test {
    MockV3Aggregator public mockPriceFeed;

    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_PRICE = 2000e8;

    function setUp() external {
        mockPriceFeed = new MockV3Aggregator(DECIMALS, INITIAL_PRICE);
    }

    function testStaleCheckLatestRoundDataReturnsCorrectData() public view {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            OracleLib.staleCheckLatestRoundData(AggregatorV3Interface(address(mockPriceFeed)));

        assertEq(answer, INITIAL_PRICE);
        assertGt(roundId, 0);
        assertGt(startedAt, 0);
        assertGt(updatedAt, 0);
        assertGt(answeredInRound, 0);
    }

    function testRevertsOnStalePrice() public {
        // Fast forward time by more than 3 hours (TIMEOUT)
        vm.warp(block.timestamp + 4 hours);

        vm.expectRevert(OracleLib.OracleLib__StalePrice.selector);
        OracleLib.staleCheckLatestRoundData(AggregatorV3Interface(address(mockPriceFeed)));
    }

    function testDoesNotRevertIfPriceIsNotStale() public {
        // Fast forward time by less than 3 hours
        vm.warp(block.timestamp + 2 hours);

        // Should not revert
        (, int256 answer,,,) = OracleLib.staleCheckLatestRoundData(AggregatorV3Interface(address(mockPriceFeed)));
        assertEq(answer, INITIAL_PRICE);
    }
}
