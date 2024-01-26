// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { ERC20 } from "@openzeppelin-contracts/token/ERC20/ERC20.sol";

contract ZeroSwapToken1 is ERC20 {
    // UselessToken is deployed as a test token and holds no monetary value.
    constructor(address thisAddr) ERC20("ZeroSwapToken1", "ZST1") {
        _mint(thisAddr, 10 ** 8 * 10 ** 18);
    }
}
