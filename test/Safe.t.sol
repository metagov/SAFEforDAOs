// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Safe.sol";

contract SafeTest is Test {
    Safe public safe;

    function setUp() public {
        safe = new Safe();
    }

    function testPercent() public {}

}
