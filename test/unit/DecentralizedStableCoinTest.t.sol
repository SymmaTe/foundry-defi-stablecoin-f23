//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";

contract DecentralizedStableCoinTest is Test {
    DecentralizedStableCoin public dsc;
    address public OWNER = makeAddr("owner");
    address public USER = makeAddr("user");

    function setUp() external {
        vm.prank(OWNER);
        dsc = new DecentralizedStableCoin(OWNER);
    }

    // mint tests
    function testMintSuccess() public {
        vm.prank(OWNER);
        bool success = dsc.mint(USER, 100 ether);
        assertTrue(success);
        assertEq(dsc.balanceOf(USER), 100 ether);
    }

    function testMintRevertsIfNotOwner() public {
        vm.prank(USER);
        vm.expectRevert();
        dsc.mint(USER, 100 ether);
    }

    function testMintRevertsIfZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__NotZeroAddress.selector);
        dsc.mint(address(0), 100 ether);
    }

    function testMintRevertsIfZeroAmount() public {
        vm.prank(OWNER);
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__MustBeMoreThanZero.selector);
        dsc.mint(USER, 0);
    }

    // burn tests
    function testBurnSuccess() public {
        vm.startPrank(OWNER);
        dsc.mint(OWNER, 100 ether);
        dsc.burn(50 ether);
        vm.stopPrank();
        assertEq(dsc.balanceOf(OWNER), 50 ether);
    }

    function testBurnRevertsIfNotOwner() public {
        vm.prank(OWNER);
        dsc.mint(USER, 100 ether);

        vm.prank(USER);
        vm.expectRevert();
        dsc.burn(50 ether);
    }

    function testBurnRevertsIfZeroAmount() public {
        vm.startPrank(OWNER);
        dsc.mint(OWNER, 100 ether);
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__MustBeMoreThanZero.selector);
        dsc.burn(0);
        vm.stopPrank();
    }

    function testBurnRevertsIfExceedsBalance() public {
        vm.startPrank(OWNER);
        dsc.mint(OWNER, 100 ether);
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__BurnAmountExceedsBalance.selector);
        dsc.burn(200 ether);
        vm.stopPrank();
    }
}
