import { expect } from "chai";
import { ethers } from "hardhat";
import { ERC20 } from "../typechain-types";

describe("ERC20Contract", function () {
  let myERC20Contract: ERC20;
  let otherAddress1: ethers.HardhatEthersSigner;
  let otherAddress2: ethers.HardhatEthersSigner;

  beforeEach(async function () {
    const ERC20ContractFactory = await ethers.getContractFactory("ERC20");
    myERC20Contract = await ERC20ContractFactory.deploy("Oxyr", "OXY");
    await myERC20Contract.deploymentTransaction();

    otherAddress1 = (await ethers.getSigners())[1];
    otherAddress2 = (await ethers.getSigners())[2];
  });

  describe("Case: Have 10 tokens", function () {
    beforeEach(async function () {
      await myERC20Contract.transfer(otherAddress1.address, 10);
    });

    describe("Case: Transfer 10 tokens.", function () {
      it("Should transfer tokens correctly.", async function () {
        await myERC20Contract.connect(otherAddress1).transfer(otherAddress2.address, 10);
        expect(await myERC20Contract.balanceOf(otherAddress2)).to.equal(10);
      });
    });

    describe("Case: Transfer 15 tokens.", function () {
      it("Shouldn't transfer tokens correctly.", async function () {
        await expect(myERC20Contract.connect(otherAddress1).transfer(otherAddress2.address, 15)).to.be.revertedWith("ERC20: Transfer amount exceeded.");
      });
    });
  });
});