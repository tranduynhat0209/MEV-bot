const { ethers } = require("hardhat");
const hre = require("hardhat");
describe("Full test for ABCSwapV2Pair", async () => {
  let deployer;
  it("Set up", async () => {
    deployer = await hre.ethers.getSigner();
    //console.log("Deploper's address =", deployer.address);
  });
});
