// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestnetUSDC is ERC20 {
    constructor() ERC20("BUSD", "BUSD") {}

    function mint(uint256 _amount) public {
        _mint(msg.sender, _amount);
    }
}
