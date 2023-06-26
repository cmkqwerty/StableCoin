// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { ERC20 } from "./ERC20.sol";
import { DepositorCoin } from "./DepositorCoin.sol";
import { Oracle } from "./Oracle.sol";
import { WadLib } from "./WadLib.sol"; 

contract StableCoin is ERC20 {
    using WadLib for uint256;

    error InitialCollateralRatioErr(string message, uint256 minAmount);

    DepositorCoin public depositorCoin;

    uint256 public feeRatePer;
    uint256 public constant INITIAL_COLLATERAL_RATIO_PER = 10;

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
        int256 deficitOrSurplusInUsd = _getDeficitOrSurplusInContractInUsd();
        require(deficitOrSurplusInUsd >= 0, "STC: Currently in deficit.");

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

    function depositCollateralBuffer() external payable {
        int256 deficitOrSurplusInUsd = _getDeficitOrSurplusInContractInUsd();
        if (deficitOrSurplusInUsd <= 0) {
            uint256 deficitInUsd = uint256(deficitOrSurplusInUsd * -1);
            uint256 usdInEth = oracle.getPrice();
            uint256 deficitInEth = deficitInUsd / usdInEth;

            uint256 requiredInitialSurplusInUsd = (INITIAL_COLLATERAL_RATIO_PER * totalSupply) / 100;
            uint256 requiredInitialSurplusInEth = requiredInitialSurplusInUsd / usdInEth;

            if(msg.value < deficitInEth + requiredInitialSurplusInEth) {
                uint256 minAmount = deficitInEth + requiredInitialSurplusInEth;

                revert InitialCollateralRatioErr("STC: Initial collateral ratio not met.", minAmount);
            }

            uint256 newInitialSurplusInEth = msg.value - deficitInEth;
            uint256 newInitialSurplusInUsd = newInitialSurplusInEth * usdInEth;

            depositorCoin = new DepositorCoin();
            uint256 _mintDepositorCoinAmount = newInitialSurplusInUsd;
            depositorCoin.mint(msg.sender, _mintDepositorCoinAmount);
        }

        uint256 surplusInUsd = uint256(deficitOrSurplusInUsd);
        WadLib.Wad dtcInUsd = _getDtcInUsd(surplusInUsd);
        uint256 mintDepositorCoinAmount = (msg.value.mulWad(dtcInUsd)) / (oracle.getPrice());

        depositorCoin.mint(msg.sender, mintDepositorCoinAmount);
    }

    function withdrawCollateralBuffer(uint256 amount) external {
        require(depositorCoin.balanceOf(msg.sender) >= amount, "STC: Insufficient DPC funds.");

        depositorCoin.burn(msg.sender, amount);

        int deficitOrSurplusInUsd = _getDeficitOrSurplusInContractInUsd();
        require(deficitOrSurplusInUsd > 0, "STC: Can't withdraw.");

        uint256 surplusInUsd = uint256(deficitOrSurplusInUsd);
        WadLib.Wad dtcInUsd = _getDtcInUsd(surplusInUsd);
        uint256 refundingUsd = amount.mulWad(dtcInUsd);
        uint256 refundingEth = refundingUsd / oracle.getPrice();

        (bool success,) = payable(msg.sender).call{value: refundingEth}("");

        require(success, "STC: Withdraw refund failed.");

    }

    function _getDeficitOrSurplusInContractInUsd() private view returns (int256) {
        uint256 ethContractBalanceInUsd = (address(this).balance - msg.value) * oracle.getPrice();
        uint256 totalStableCoinBalanceInUsd = totalSupply;
        int256 deficitOrSurplus = int256(ethContractBalanceInUsd) - int256(totalStableCoinBalanceInUsd);

        return deficitOrSurplus;
    }

    function _getDtcInUsd(uint256 surplusInUsd) private view returns (WadLib.Wad) {
        return WadLib.fromFraction(depositorCoin.totalSupply(), surplusInUsd);
    }
}