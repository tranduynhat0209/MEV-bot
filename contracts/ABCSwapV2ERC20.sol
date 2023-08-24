// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./libraries/SafeMath.sol";
contract ABCSwapV2 is ERC20 {
    constructor() ERC20("ABCSwapV2", "ABCS") {
        _mint(address(this), 10**18);
    }
}