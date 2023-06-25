// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "./ERC20.sol";

contract DepositorCoin is ERC20 {
    address public owner;

    constructor() ERC20("DepositorCoin", "DTC") {
        owner = msg.sender;
    }
}