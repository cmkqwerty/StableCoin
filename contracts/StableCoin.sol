// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { ERC20 } from "./ERC20.sol";
import { DepositorCoin } from "./DepositorCoin.sol";
import { Oracle } from "./Oracle.sol";

contract StableCoin is ERC20 {
    DepositorCoin public depositorCoin;

    uint256 public feeRatePer; 
    Oracle public oracle;

    constructor(uint256 _feeRatePer, Oracle _oracle) ERC20("StableCoin", "STC") {
        feeRatePer = _feeRatePer;
        oracle = _oracle;
    }

    function mint() external payable {
        uint256 fee = _getFee(msg.value);
        uint256 remainingEth = msg.value - fee;
        uint256 mintStableCoinAmount = remainingEth * oracle.getPrice();
        _mint(msg.sender, mintStableCoinAmount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);

        uint256 ethBack = amount / oracle.getPrice();
        uint256 fee = _getFee(ethBack);
        uint256 ethRemainingValue = ethBack - fee;

        (bool success,) = payable(msg.sender).call{value: ethRemainingValue}("");

        require(success, "STC: Burn refund failed.");
    }

    function _getFee(uint256 amount) private view returns (uint256) {
        bool hasDeployed = (address(depositorCoin) != address(0)) && (depositorCoin.totalSupply() > 0);
        if (!hasDeployed) {
            return 0;
        }
        
        return (feeRatePer * amount) / 100;
    }
}