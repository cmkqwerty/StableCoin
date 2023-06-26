import { expect } from "chai";
import { ethers } from "hardhat";
import { DepositorCoin } from "../typechain-types/DepositorCoin";
import { StableCoin } from "../typechain-types/StableCoin";

describe("StableCoin", function () {
  let ethUsdPrice: number, feeRatePercentage: number;
  let StableCoin: StableCoin;

  this.beforeEach(async () => {
    feeRatePercentage = 3;
    ethUsdPrice = 4000;

    const OracleFactory = await ethers.getContractFactory("Oracle");
    const ethUsdOracle = await OracleFactory.deploy();
    await ethUsdOracle.setPrice(ethUsdPrice);

    const StableCoinFactory = await ethers.getContractFactory("StableCoin");
    StableCoin = await StableCoinFactory.deploy(
      feeRatePercentage,
      ethUsdOracle.getAddress()
    );
    await StableCoin.waitForDeployment;
  });

  it("Should set fee rate percentage", async function () {
    expect(await StableCoin.feeRatePer()).to.equal(feeRatePercentage);
  });

  it("Should allow minting", async function () {
    const ethAmount = 1;
    const expectedMintAmount = ethAmount * ethUsdPrice;

    await StableCoin.mint({
      value: ethers.parseEther(ethAmount.toString()),
    });
    expect(await StableCoin.totalSupply()).to.equal(
      ethers.parseEther(expectedMintAmount.toString())
    );
  });

  describe("With minted tokens", function () {
    let mintAmount: number;

    this.beforeEach(async () => {
      const ethAmount = 1;
      mintAmount = ethAmount * ethUsdPrice;

      await StableCoin.mint({
        value: ethers.parseEther(ethAmount.toString()),
      });
    });

    it("Should allow burning", async function () {
      const remainingStableCoinAmount = 100;
      await StableCoin.burn(
        ethers.parseEther(
          (mintAmount - remainingStableCoinAmount).toString()
        )
      );

      expect(await StableCoin.totalSupply()).to.equal(
        ethers.parseEther(remainingStableCoinAmount.toString())
      );
    });

    it("Should prevent depositing collateral buffer below minimum", async function () {
      const expectedMinimumAmount = 0.1; // 10% one 1 ETH
      const stableCoinCollateralBuffer = 0.05; // less than minimum

      await expect(
        StableCoin.depositCollateralBuffer({
          value: ethers.parseEther(stableCoinCollateralBuffer.toString()),
        })
      ).to.be.revertedWith(
        `custom error 'InitialCollateralRatioErr("STC: Initial collateral ratio not met.", ` +
        ethers.parseEther(expectedMinimumAmount.toString()) +
        ")'"
      );
    });
  });
});