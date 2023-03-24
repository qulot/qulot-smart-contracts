// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { console } from "hardhat/console.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol, uint256 supply) ERC20(name, symbol) {
        _mint(msg.sender, supply);
    }

    function mintTokens(uint256 _amount) external {
        _mint(msg.sender, _amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal view override {
        console.log("Transfer from: %s, to: %s, amount: %s", from, to, amount);
    }
}
