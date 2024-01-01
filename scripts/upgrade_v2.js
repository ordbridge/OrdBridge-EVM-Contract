// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {

  const contractAddress = process.env.CONTRACT_ADDRESS;

  if (!contractAddress) {
    console.error("Contract address not provided in the environment variable.");
    process.exit(1);
  }

  const OrdBridgeV2 = await hre.ethers.getContractFactory("OrdBridgeV2");

  console.log("Upgrading OrdBridgeV2...");

  await hre.upgrades.upgradeProxy(contractAddress, OrdBridgeV2);

  console.log(
    `upgraded`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
