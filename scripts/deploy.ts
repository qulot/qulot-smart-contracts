import { ethers } from "hardhat";

async function main() {
  const ChainLinkRandomNumberGenerator = await ethers.getContractFactory("ChainLinkRandomNumberGenerator");
  const chainLinkRandomNumberGenerator = await ChainLinkRandomNumberGenerator.deploy();
  await chainLinkRandomNumberGenerator.deployed();
  const QulotLottery = await ethers.getContractFactory("QulotLottery");
  const qulotLottery = await QulotLottery.deploy(
    "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    chainLinkRandomNumberGenerator.address,
  );
  await qulotLottery.deployed();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
