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

  const data = {
    requestedBRCTickers: ["ordi"],
    multiples: [1000],
    amounts: [parseUnits("1000", 18)],
    users: ["0x1041c5FBA31403a7Abb0574B71659811e96922A0"],
    txIds: ["tx00000246"],
    initialMaxSupplies: [parseUnits("21000000", 18)]
};

const signatures = ["0xfe78410ed5ed2cc5b1830f90b0f8bc64fc84235b85b8765e0fbdfa2a637098fd3aac80a0955df95e3d40d902f280a01dd8e75171e611b57ae8e2b7cb0378ec8d1b",
"0xfe78410ed5ed2cc5b1830f90b0f8bc64fc84235b85b8765e0fbdfa2a637098fd3aac80a0955df95e3d40d902f280a01dd8e75171e611b57ae8e2b7cb0378ec8d1b"]

  const instance = await hre.ethers.getContractAt("OrdBridgeV2", contractAddress);
  //await instance.updateFeeRecipient(owner.address);

  const tx1 = await instance.addMintERCEntries(data,signatures);
  console.log(tx1);

  // const tx2 = await instance.claimERCEntryForWallet('ordi', 1000);
  // console.log(tx2);
  // await instance.burnERCTokenForBRC("avax", "ordi", 1000, "1000", other.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
