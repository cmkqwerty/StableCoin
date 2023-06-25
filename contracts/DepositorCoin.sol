// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "./ERC20.sol";

contract DepositorCoin is ERC20 {
    address public owner;

    constructor() ERC20("DepositorCoin", "DTC") {
        owner = msg.sender;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == owner, "DTC: Only owner can mint.");

        _mint(to, amount);
    }
    
    function burn(address from, uint256 amount) external {
        require(msg.sender == owner, "DTC: Only owner can burn.");

        _burn(from, amount);
    }

}