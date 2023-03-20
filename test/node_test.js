const { expect } = require("chai");
const { BigNumber, utils } = require("ethers");
const { ethers, waffle } = require("hardhat");
const provider = waffle.provider;

const Deployy = async () => {
    [owner, account1, account2, bot, treasury] = await ethers.getSigners();

    let Token = await ethers.getContractFactory("TestnetUSDC");
    let token = await Token.deploy();

    let Security = await ethers.getContractFactory(
        "CicleoSubscriptionSecurity"
    );
    let security = await upgrades.deployProxy(Security);
    await security.deployed();

    let Factory = await ethers.getContractFactory("CicleoSubscriptionFactory");
    let factory = await upgrades.deployProxy(Factory, [
        bot.address,
        15,
        treasury.address,
        security.address,
        security.address,
    ]);
    await factory.deployed();

    let Router = await ethers.getContractFactory("CicleoSubscriptionRouter");
    let router = await upgrades.deployProxy(Router, [factory.address]);
    await router.deployed();

    await security.setFactory(factory.address);

    return [token, factory, router, security, owner, account1, account2];
};

describe("Subscription Test", function () {
    let token;
    let factory;
    let router;
    let security;
    let subManager;
    let owner;
    let account1;
    let account2;

    beforeEach(async function () {
        [token, factory, router, security, owner, account1, account2] =
            await Deployy();

        await factory.createSubscriptionManager(
            "Test",
            token.address,
            account2.address
        );
        await factory.createSubscriptionManager(
            "Test2",
            token.address,
            account2.address
        );

        await token.connect(account1).mint(utils.parseEther("100"));

        let SubManager = await ethers.getContractFactory(
            "CicleoSubscriptionManager"
        );
        subManager = await SubManager.attach(await factory.ids(1));

        await subManager.newSubscription(utils.parseEther("10"), "Test");

        await token
            .connect(account1)
            .approve(subManager.address, utils.parseEther("100"));
    });

    it("Verify if factory return good name", async function () {
        const subManagerStruct = await router.getSubscriptionsManager(
            owner.address
        );

        expect(subManagerStruct[0][0]).to.equal(1);
        expect(subManagerStruct[0][1]).to.equal("Test");

        expect(subManagerStruct[1][0]).to.equal(2);
        expect(subManagerStruct[1][1]).to.equal("Test2");
    });

    it("Verify if got nfts", async function () {
        expect(await security.balanceOf(owner.address)).to.be.equal(2);
    });

    it("Pay subscription type", async function () {
        expect(await token.balanceOf(account1.address)).to.be.equal(
            utils.parseEther("100")
        );

        await subManager
            .connect(account1)
            .approveSubscription(utils.parseEther("10"));
        await subManager.connect(account1).payment(1);

        expect(await token.balanceOf(account1.address)).to.be.equal(
            utils.parseEther("90")
        );

        expect(
            (await subManager.getSubscriptionStatus(account1.address))[0]
        ).to.be.equal(1);
        expect(
            (await subManager.getSubscriptionStatus(account1.address))[1]
        ).to.be.equal(true);
    });

    it("Pay with wrong subscription type", async function () {
        await expect(
            subManager.connect(account1).payment(0)
        ).to.be.revertedWith("Wrong sub type");
        await expect(
            subManager.connect(account1).payment(2)
        ).to.be.revertedWith("Wrong sub type");
    });

    it("Subscription expiration", async function () {
        await subManager
            .connect(account1)
            .approveSubscription(utils.parseEther("10"));
        await subManager.connect(account1).payment(1);

        expect(
            (await subManager.getSubscriptionStatus(account1.address))[0]
        ).to.be.equal(1);
        expect(
            (await subManager.getSubscriptionStatus(account1.address))[1]
        ).to.be.equal(true);

        await network.provider.send("evm_increaseTime", [31 * 86400]);
        await network.provider.send("evm_mine");

        expect(
            (await subManager.getSubscriptionStatus(account1.address))[1]
        ).to.be.equal(false);
    });

    it("Subscription approval", async function () {
        await expect(
            subManager.connect(account1).payment(1)
        ).to.be.revertedWith(
            "You need to approve our contract to spend this amount of token"
        );

        await subManager
            .connect(account1)
            .approveSubscription(utils.parseEther("10"));
        await subManager.connect(account1).payment(1);

        await subManager.editSubscription(
            1,
            utils.parseEther("20"),
            true,
            "Test"
        );

        await network.provider.send("evm_increaseTime", [31 * 86400]);
        await network.provider.send("evm_mine");

        await subManager.connect(bot).subscriptionRenew(account1.address);

        expect(
            (await subManager.getSubscriptionStatus(account1.address))[1]
        ).to.be.equal(false);
    });

    it("Get Subscription", async function () {
        expect((await subManager.getSubscriptions())[0][0]).to.be.equal(
            utils.parseEther("10")
        );
        expect((await subManager.getSubscriptions())[0][1]).to.be.equal(true);
        expect((await subManager.getSubscriptions())[0][2]).to.be.equal("Test");
    });

    it("Subscription renew", async function () {
        expect(await token.balanceOf(account1.address)).to.be.equal(utils.parseEther("100"));   

        await subManager
            .connect(account1)
            .approveSubscription(utils.parseEther("10"));
        await subManager.connect(account1).payment(1);

        expect(await token.balanceOf(account1.address)).to.be.equal(utils.parseEther("90"));  

        await expect(
            subManager.subscriptionRenew(account1.address)
        ).to.be.revertedWith("Not allowed to");

        await expect(
            subManager.connect(bot).subscriptionRenew(account1.address)
        ).to.be.revertedWith("You can't renew subscription before 30 days");

        await network.provider.send("evm_increaseTime", [31 * 86400]);
        await network.provider.send("evm_mine");

        await expect(
            subManager.subscriptionRenew(account1.address)
        ).to.be.revertedWith("Not allowed to");

        expect(
            (await subManager.getSubscriptionStatus(account1.address))[1]
        ).to.be.equal(false);

        expect(await token.balanceOf(account1.address)).to.be.equal(utils.parseEther("90"));  

        await subManager.connect(bot).subscriptionRenew(account1.address);

        expect(await token.balanceOf(account1.address)).to.be.equal(utils.parseEther("80"));  

        expect(
            (await subManager.getSubscriptionStatus(account1.address))[1]
        ).to.be.equal(true);

    });


    it("Subscription renew 30 days", async function () {
        expect(await token.balanceOf(account1.address)).to.be.equal(utils.parseEther("100"));   

        await subManager
            .connect(account1)
            .approveSubscription(utils.parseEther("10"));
        await subManager.connect(account1).payment(1);

        expect(await token.balanceOf(account1.address)).to.be.equal(utils.parseEther("90"));  

        await expect(
            subManager.subscriptionRenew(account1.address)
        ).to.be.revertedWith("Not allowed to");

        await expect(
            subManager.connect(bot).subscriptionRenew(account1.address)
        ).to.be.revertedWith("You can't renew subscription before 30 days");

        await network.provider.send("evm_increaseTime", [30 * 86400]);
        await network.provider.send("evm_mine");

        await expect(
            subManager.subscriptionRenew(account1.address)
        ).to.be.revertedWith("Not allowed to");

        expect(await token.balanceOf(account1.address)).to.be.equal(utils.parseEther("90"));  

        await subManager.connect(bot).subscriptionRenew(account1.address);

        expect(await token.balanceOf(account1.address)).to.be.equal(utils.parseEther("80"));  

        expect(
            (await subManager.getSubscriptionStatus(account1.address))[1]
        ).to.be.equal(true);

    });

    it("Subscription Tax", async function () {
        expect(await token.balanceOf(treasury.address)).to.be.equal(0);
        expect(await token.balanceOf(account2.address)).to.be.equal(0);

        await subManager
            .connect(account1)
            .approveSubscription(utils.parseEther("10"));
        await subManager.connect(account1).payment(1);

        expect(await token.balanceOf(treasury.address)).to.be.equal(
            utils.parseEther("0.15")
        );
        expect(await token.balanceOf(account2.address)).to.be.equal(
            utils.parseEther("9.85")
        );
    });

    it("Active Subscription Count", async function () {
        await subManager.newSubscription(utils.parseEther("10"), "Test");
        await subManager.editSubscription(
            1,
            utils.parseEther("10"),
            "Test",
            false
        );

        expect(await subManager.getActiveSubscriptionCount()).to.be.equal(1);

        await subManager.editSubscription(
            2,
            utils.parseEther("10"),
            "Test",
            false
        );

        expect(await subManager.getActiveSubscriptionCount()).to.be.equal(0);
    });

    it("Delete SubManager", async function () {
        expect(await security.balanceOf(owner.address)).to.be.equal(2);

        await subManager.deleteSubManager();

        expect(await security.balanceOf(owner.address)).to.be.equal(1);

        await expect(security.deleteSubManager()).to.be.revertedWith(
            "Only subManager can burn"
        );
    });

    it("Get Owners", async function () { 
        const subManagerInfo = await router.getSubscriptionManager(1);

        expect(subManagerInfo.owners[0]).to.be.equal(owner.address);
    });

    it("Refund Upgrade", async function () { 
        expect(await token.balanceOf(account1.address)).to.be.equal(utils.parseEther("100"));
        await subManager.newSubscription(utils.parseEther("15"), "Test");

        await subManager
            .connect(account1)
            .approveSubscription(utils.parseEther("10"));
        await subManager.connect(account1).payment(1);

        expect(await token.balanceOf(account1.address)).to.be.equal(utils.parseEther("90"));

        const userData = await subManager.users(account1.address);

        await network.provider.send("evm_increaseTime", [10 * 86400]);
        await network.provider.send("evm_mine");

        await subManager
            .connect(account1)
            .approveSubscription(utils.parseEther("15"));
        await subManager.connect(account1).payment(2);

        const userDataThen = await subManager.users(account1.address);

        expect(userDataThen.subscriptionEndDate).to.be.equal(userData.subscriptionEndDate);
        expect(await token.balanceOf(account1.address)).to.be.equal(utils.parseEther("86.666666666666666660"));

        await subManager.connect(account1).payment(1);

        expect(userDataThen.subscriptionEndDate).to.be.equal(userData.subscriptionEndDate);
        expect(await token.balanceOf(account1.address)).to.be.equal(utils.parseEther("86.666666666666666660"));
    });
});
