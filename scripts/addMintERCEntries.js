// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const { parseUnits } = require("ethers");
const hre = require("hardhat");

async function main() {
  const [owner] = await ethers.getSigners();

  const contractAddress = process.env.CONTRACT_ADDRESS;

  const instance = await hre.ethers.getContractAt("OrdBridgeV2", contractAddress);
  //await instance.updateFeeRecipient(owner.address);

  // const tx1 = await instance.addMintERCEntries(["ordi"], [1000], [parseUnits("1000", 18)], [owner.address], ["tx000001"], [parseUnits("21000000", 18)]);
  // console.log(tx1);

  const tx2 = await instance.claimERCEntryForWallet('ordi', 1000);
  console.log(tx2);
  // await instance.burnERCTokenForBRC("avax", "ordi", 1000, "1000", other.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
