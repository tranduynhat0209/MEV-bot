//SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CloneBNB is ERC20 {
    constructor() ERC20("cloneBNB", "BNBS") {
        _mint(address(this), 10**18);
    }

    function mint(uint256 amount) public {
        _mint(address(msg.sender), amount);
    }

    function _disable_mint() public {}
}

