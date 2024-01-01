const { expect } = require("chai");

describe("OrdBridge", function () {
    it('works', async () => {
        const OrdBridge = await ethers.getContractFactory("OrdBridge");
        const OrdBridgeV2 = await ethers.getContractFactory("OrdBridgeV2");

        const [owner] = await ethers.getSigners();

        const instance = await upgrades.deployProxy(OrdBridge);
        await instance.updateFeeRecipient(owner.address);

        const upgraded = await upgrades.upgradeProxy(await instance.getAddress(), OrdBridgeV2);

        const _feeAddr = await upgraded.feeRecipient();
        expect(_feeAddr.toString()).to.equal(owner.address);
    });
});