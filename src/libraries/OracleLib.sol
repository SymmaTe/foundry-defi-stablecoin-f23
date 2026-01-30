//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title OracleLib
 * @author SymmaTe
 * @notice This library is used to check the Chainlink Oracle for stale data.
 * @dev If a price is stale, functions will revert, and render the DSCEngine unusable - this is by design.
 * We want the DSCEngine to freeze if prices become stale to prevent incorrect liquidations or minting.
 *
 * WARNING: If the Chainlink network goes down and you have money locked in the protocol,
 * you will not be able to interact with the system until prices are updated.
 */
library OracleLib {
    ///////////////////
    // Errors        //
    ///////////////////
    error OracleLib__StalePrice();

    ///////////////////
    // Constants     //
    ///////////////////
    uint256 private constant TIMEOUT = 3 hours;

    ///////////////////
    // Functions     //
    ///////////////////

    /**
     * @notice Fetches the latest round data from the price feed and checks for staleness
     * @param priceFeed The Chainlink price feed to query
     * @return roundId The round ID from the oracle
     * @return answer The price answer from the oracle
     * @return startedAt The timestamp when the round started
     * @return updatedAt The timestamp when the round was last updated
     * @return answeredInRound The round ID in which the answer was computed
     * @dev Reverts with OracleLib__StalePrice if the price data is older than TIMEOUT (3 hours)
     */
    function staleCheckLatestRoundData(AggregatorV3Interface priceFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.latestRoundData();

        uint256 secondsSince = block.timestamp - updatedAt;
        if (secondsSince > TIMEOUT) {
            revert OracleLib__StalePrice();
        }

        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }

    /**
     * @notice Returns the timeout value used for staleness check
     * @return The timeout in seconds (3 hours)
     */
    function getTimeout() public pure returns (uint256) {
        return TIMEOUT;
    }
}
