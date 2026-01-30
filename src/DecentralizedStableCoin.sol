//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Decentralized Stable Coin
 * @author SymmaTe
 * @notice This is the ERC20 implementation of the decentralized stablecoin
 * @dev Collateral: Exogenous (wBTC, wETH)
 *      Minting: Algorithmically controlled
 *      Stability: Pegged to $1 USD
 *
 * This contract is governed by DSCEngine and only implements the ERC20 functionality.
 * DSCEngine acts as the owner to control minting and burning.
 */
contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    ///////////////////
    // Errors        //
    ///////////////////
    error DecentralizedStableCoin__MustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    ///////////////////
    // Functions     //
    ///////////////////

    /**
     * @notice Constructor initializes the token name and symbol
     * @param _owner The DSCEngine contract address that will control minting and burning
     */
    constructor(address _owner) ERC20("Decentralized Stable Coin", "DSC") Ownable(_owner) {}

    /**
     * @notice Burns DSC tokens
     * @param _amount The amount of tokens to burn
     * @dev Only the owner (DSCEngine) can call this function
     */
    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        // NOTE: uint256 cannot be < 0, so <= 0 is equivalent to == 0
        if (_amount == 0) {
            revert DecentralizedStableCoin__MustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    /**
     * @notice Mints new DSC tokens
     * @param _to The address to receive the minted tokens
     * @param _amount The amount of tokens to mint
     * @return bool True if minting was successful
     * @dev Only the owner (DSCEngine) can call this function
     */
    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin__NotZeroAddress();
        }
        // NOTE: uint256 cannot be < 0, so <= 0 is equivalent to == 0
        if (_amount == 0) {
            revert DecentralizedStableCoin__MustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}
