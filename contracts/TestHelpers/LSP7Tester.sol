// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '../LSP7/LSP7.sol';

contract LSP7Tester is LSP7 {
    constructor(
      string memory name,
      string memory symbol,
      address newOwner
    ) LSP7(name, symbol, newOwner) {}

    function mint(address to, uint256 amount, bool force, bytes memory data) public {
        _mint(to, amount, force, data);
    }

    function burn(address from, uint256 amount, bytes memory data) public {
        _burn(from, amount, data);
    }
}