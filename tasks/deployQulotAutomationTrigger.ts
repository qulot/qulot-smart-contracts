import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

const WAIT_CONFIRMATION_BLOCKS = 4;

task("deploy:QulotAutomationTrigger", "Deploy the Qulot automation trigger").setAction(async function (
  _: TaskArguments,
  { ethers, run },
) {
  const [__, operator] = await ethers.getSigners();

  // Deploy Qulot automation trigger contract
  console.warn("Trying deploy QulotAutomationTrigger contract...");
  const QulotAutomationTrigger = await ethers.getContractFactory("QulotAutomationTrigger");
  const qulotAutomationTrigger = await QulotAutomationTrigger.deploy();
  await qulotAutomationTrigger.deployTransaction.wait(WAIT_CONFIRMATION_BLOCKS);
  console.log(`QulotAutomationTrigger deployed to: ${qulotAutomationTrigger.address}`);

  await qulotAutomationTrigger.setOperatorAddress(operator.address);

  // Verify ChainLink random number contract
  console.log(`Trying verify QulotAutomationTrigger contract to: ${qulotAutomationTrigger.address}`);
  await run("verify:verify", {
    address: qulotAutomationTrigger.address,
    constructorArguments: [],
  });
});
