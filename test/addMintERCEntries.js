const { expect } = require("chai");

describe("addMintERCEntries", function () {
    it('works', async () => {
        const OrdBridge = await ethers.getContractFactory("OrdBridge");
        const OrdBridgeV2 = await ethers.getContractFactory("OrdBridgeV2");

        const [owner, other] = await ethers.getSigners();

        const instance = await upgrades.deployProxy(OrdBridge);
        await instance.updateFeeRecipient(owner.address);
        await instance.addMintERCEntries(["ordi"], ['1000'], [other.address], ["btc000001"], ['100000000']);
        await instance.connect(other).claimERCEntryForWallet('ordi');
        await instance.connect(other).burnERCTokenForBRC("avax", "ordi", "1000", other.address);

        console.log(await instance.getBurnForBRCEntriesToProcess(10));

        const ordiTokenAddr = await instance.tokenContracts('ORDI')
        console.log(ordiTokenAddr)
        const ordiToken = await ethers.getContractAt("ZUTToken", ordiTokenAddr)
        console.log(await ordiToken.name(), await ordiToken.symbol());

        const upgraded = await upgrades.upgradeProxy(await instance.getAddress(), OrdBridgeV2);
        await upgraded.addMintERCEntries(["ordi"], [100], ['1000'], [other.address], ["btc000002"], ['100000000']);
        await upgraded.connect(other).claimERCEntryForWallet('ordi', 100);
        await upgraded.connect(other).burnERCTokenForBRC("avax", "ordi", 100, "1000", other.address);
        
        console.log(await upgraded.getBurnForBRCEntriesToProcess(10));

        const ordiX100TokenAddr = await upgraded.tokenContracts('ORDI(x100)')
        console.log(ordiX100TokenAddr)
        const ordiX100Token = await ethers.getContractAt("ZUTToken", ordiX100TokenAddr);
        console.log(await ordiX100Token.name(), await ordiX100Token.symbol());
    });
});
