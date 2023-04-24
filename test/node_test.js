const { expect } = require("chai");
const { BigNumber, utils } = require("ethers");
const { ethers, waffle } = require("hardhat");
const provider = waffle.provider;

const Deployy = async () => {
    [owner, account1, account2, account3, bot, treasury] = await ethers.getSigners();

    let Token = await ethers.getContractFactory("TestnetUSDC");
    let token = await Token.deploy();

    let Security = await ethers.getContractFactory(
        "CicleoSubscriptionSecurity"
    );
    let security = await upgrades.deployProxy(Security);
    await security.deployed();

    let Factory = await ethers.getContractFactory("CicleoSubscriptionFactory");
    let factory = await upgrades.deployProxy(Factory, [security.address]);
    await factory.deployed();

    let Router = await ethers.getContractFactory("CicleoSubscriptionRouter");
    let router = await upgrades.deployProxy(Router, [
        factory.address,
        treasury.address,
        15,
        bot.address,
    ]);
    await router.deployed();

    await security.setFactory(factory.address);

    await factory.setRouterSubscription(router.address);

    return [token, factory, router, security, owner, account1, account2, account3];
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
    let account3;

    beforeEach(async function () {
        [token, factory, router, security, owner, account1, account2, account3] =
            await Deployy();

        await factory.createSubscriptionManager(
            "Test",
            token.address,
            account2.address,
            86400 * 30
        );
        await factory.createSubscriptionManager(
            "Test2",
            token.address,
            account2.address,
            86400 * 30
        );

        await token.connect(account1).mint(utils.parseEther("100"));

        let SubManager = await ethers.getContractFactory(
            "CicleoSubscriptionManager"
        );
        subManager = await SubManager.attach(await factory.ids(1));

        await router.newSubscription(1, utils.parseEther("10"), "Test");

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
            .changeSubscriptionLimit(utils.parseEther("10"));
        await router
            .connect(account1)
            .subscribe(1, 1, ethers.constants.AddressZero);

        expect(await token.balanceOf(account1.address)).to.be.equal(
            utils.parseEther("90")
        );

        expect(
            (await subManager.getUserSubscriptionStatus(account1.address))[0]
        ).to.be.equal(1);
        expect(
            (await subManager.getUserSubscriptionStatus(account1.address))[1]
        ).to.be.equal(true);
    });

    it("Pay with wrong subscription type", async function () {
        await expect(
            router
                .connect(account1)
                .subscribe(1, 0, ethers.constants.AddressZero)
        ).to.be.revertedWith("Wrong sub type");
        await expect(
            router
                .connect(account1)
                .subscribe(1, 2, ethers.constants.AddressZero)
        ).to.be.revertedWith("Wrong sub type");
    });

    it("Subscription expiration", async function () {
        await subManager
            .connect(account1)
            .changeSubscriptionLimit(utils.parseEther("10"));
        await router
            .connect(account1)
            .subscribe(1, 1, ethers.constants.AddressZero);

        expect(
            (await subManager.getUserSubscriptionStatus(account1.address))[0]
        ).to.be.equal(1);
        expect(
            (await subManager.getUserSubscriptionStatus(account1.address))[1]
        ).to.be.equal(true);

        await network.provider.send("evm_increaseTime", [31 * 86400]);
        await network.provider.send("evm_mine");

        expect(
            (await subManager.getUserSubscriptionStatus(account1.address))[1]
        ).to.be.equal(false);
    });

    it("Subscription approval", async function () {
        await expect(
            router
                .connect(account1)
                .subscribe(1, 1, ethers.constants.AddressZero)
        ).to.be.revertedWith(
            "You need to approve our contract to spend this amount of token"
        );

        await subManager
            .connect(account1)
            .changeSubscriptionLimit(utils.parseEther("10"));

        await router
            .connect(account1)
            .subscribe(1, 1, ethers.constants.AddressZero);

        await router.editSubscription(
            1,
            1,
            utils.parseEther("20"),
            true,
            "Test"
        );

        await network.provider.send("evm_increaseTime", [31 * 86400]);
        await network.provider.send("evm_mine");

        await expect(
            router.connect(bot).subscriptionRenew(1, account1.address)
        ).to.be.revertedWith(
            "You need to approve our contract to spend this amount of tokens"
        );

        expect(
            (await subManager.getUserSubscriptionStatus(account1.address))[1]
        ).to.be.equal(false);
    });

    it("Get Subscription", async function () {
        expect((await router.getSubscriptions(1))[0][0]).to.be.equal(
            utils.parseEther("10")
        );
        expect((await router.getSubscriptions(1))[0][1]).to.be.equal(true);
        expect((await router.getSubscriptions(1))[0][2]).to.be.equal("Test");
    });

    it("Subscription renew", async function () {
        expect(await token.balanceOf(account1.address)).to.be.equal(
            utils.parseEther("100")
        );

        await subManager
            .connect(account1)
            .changeSubscriptionLimit(utils.parseEther("10"));
        await router
            .connect(account1)
            .subscribe(1, 1, ethers.constants.AddressZero);

        expect(await token.balanceOf(account1.address)).to.be.equal(
            utils.parseEther("90")
        );

        await expect(
            router.subscriptionRenew(1, account1.address)
        ).to.be.revertedWith("Not allowed to");

        await expect(
            router.connect(bot).subscriptionRenew(1, account1.address)
        ).to.be.revertedWith(
            "You can't renew before the end of your subscription"
        );

        await network.provider.send("evm_increaseTime", [31 * 86400]);
        await network.provider.send("evm_mine");

        await expect(
            router.subscriptionRenew(1, account1.address)
        ).to.be.revertedWith("Not allowed to");

        expect(
            (await subManager.getUserSubscriptionStatus(account1.address))[1]
        ).to.be.equal(false);

        expect(await token.balanceOf(account1.address)).to.be.equal(
            utils.parseEther("90")
        );

        await router.connect(bot).subscriptionRenew(1, account1.address);

        expect(await token.balanceOf(account1.address)).to.be.equal(
            utils.parseEther("80")
        );

        expect(
            (await subManager.getUserSubscriptionStatus(account1.address))[1]
        ).to.be.equal(true);
    });

    it("Subscription renew 30 days", async function () {
        expect(await token.balanceOf(account1.address)).to.be.equal(
            utils.parseEther("100")
        );

        await subManager
            .connect(account1)
            .changeSubscriptionLimit(utils.parseEther("10"));
        await router
            .connect(account1)
            .subscribe(1, 1, ethers.constants.AddressZero);

        expect(await token.balanceOf(account1.address)).to.be.equal(
            utils.parseEther("90")
        );

        await expect(
            router.subscriptionRenew(1, account1.address)
        ).to.be.revertedWith("Not allowed to");

        await expect(
            router.connect(bot).subscriptionRenew(1, account1.address)
        ).to.be.revertedWith(
            "You can't renew before the end of your subscription"
        );

        await network.provider.send("evm_increaseTime", [30 * 86400]);
        await network.provider.send("evm_mine");

        await expect(
            router.subscriptionRenew(1, account1.address)
        ).to.be.revertedWith("Not allowed to");

        expect(await token.balanceOf(account1.address)).to.be.equal(
            utils.parseEther("90")
        );

        await router.connect(bot).subscriptionRenew(1, account1.address);

        expect(await token.balanceOf(account1.address)).to.be.equal(
            utils.parseEther("80")
        );

        expect(
            (await subManager.getUserSubscriptionStatus(account1.address))[1]
        ).to.be.equal(true);
    });

    it("Subscription Tax", async function () {
        expect(await token.balanceOf(treasury.address)).to.be.equal(0);
        expect(await token.balanceOf(account2.address)).to.be.equal(0);

        await subManager
            .connect(account1)
            .changeSubscriptionLimit(utils.parseEther("10"));
        await router
            .connect(account1)
            .subscribe(1, 1, ethers.constants.AddressZero);

        expect(await token.balanceOf(treasury.address)).to.be.equal(
            utils.parseEther("0.15")
        );
        expect(await token.balanceOf(account2.address)).to.be.equal(
            utils.parseEther("9.85")
        );
    });

    it("Active Subscription Count", async function () {
        await router.newSubscription(1, utils.parseEther("10"), "Test");
        await router.editSubscription(
            1,
            1,
            utils.parseEther("10"),
            "Test",
            false
        );

        expect(await router.getActiveSubscriptionCount(1)).to.be.equal(1);

        await router.editSubscription(
            1,
            2,
            utils.parseEther("10"),
            "Test",
            false
        );

        expect(await router.getActiveSubscriptionCount(1)).to.be.equal(0);
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

    it("Pay subscription type", async function () {
        expect(await token.balanceOf(account1.address)).to.be.equal(
            utils.parseEther("100")
        );

        await subManager
            .connect(account1)
            .changeSubscriptionLimit(utils.parseEther("10"));
        await router
            .connect(account1)
            .subscribe(1, 1, ethers.constants.AddressZero);
        await router.newSubscription(1, utils.parseEther("50"), "Test");

        await network.provider.send("evm_increaseTime", [15 * 86400]);
        await network.provider.send("evm_mine");

        expect(
            await router.getChangeSubscriptionPrice(1, account1.address, 2)
        ).to.be.equal(utils.parseEther("19.999976851851851851"));
    });

    it("Referral test without being subscribed", async function () {
        expect(await token.balanceOf(account3.address)).to.be.equal(0);

        //Set referral percent to 1%
        await router.setReferralPercent(1, 10);
        await subManager
            .connect(account1)
            .changeSubscriptionLimit(utils.parseEther("10"));
        await router.connect(account1).subscribe(1, 1, account3.address);

        expect(await token.balanceOf(account3.address)).to.be.equal(0); //utils.parseEther("0.0985")
    });

    it("Referral test", async function () {
        expect(await token.balanceOf(account3.address)).to.be.equal(0);

        //Set referral percent to 1%
        await router.setReferralPercent(1, 10);

        await router.editAccount(1, account3.address, Math.ceil(Date.now() / 1000) + 86400, 1);

        console.log("jfjur")
        await subManager
            .connect(account1)
            .changeSubscriptionLimit(utils.parseEther("10"));
        await router.connect(account1).subscribe(1, 1, account3.address);

        expect(await token.balanceOf(account3.address)).to.be.equal(0); //utils.parseEther("0.0985")
    });

    it("Free subscription test", async function () {
        await router.newSubscription(1, utils.parseEther("0"), "Test");

        expect(await token.balanceOf(account1.address)).to.be.equal(utils.parseEther("100"));

        await subManager
            .connect(account1)
            .changeSubscriptionLimit(utils.parseEther("10"));
        await router.connect(account1).subscribe(1, 2, ethers.constants.AddressZero);

        expect(await token.balanceOf(account1.address)).to.be.equal(utils.parseEther("100"));

        await network.provider.send("evm_increaseTime", [90 * 86400]);
        await network.provider.send("evm_mine");

        const res = await subManager.getUserSubscriptionStatus(account1.address);

        expect(res.isActive).to.equal(true);

        await router.connect(account1).subscribe(1, 1, ethers.constants.AddressZero);

        expect((await subManager.getUserSubscriptionStatus(account1.address))[1]).to.equal(true);

        await network.provider.send("evm_increaseTime", [30 * 86400]);
        await network.provider.send("evm_mine");

        expect((await subManager.getUserSubscriptionStatus(account1.address))[1]).to.equal(false);
    });

    /* it("Refund Upgrade", async function () { 
        expect(await token.balanceOf(account1.address)).to.be.equal(utils.parseEther("100"));
        await router.newSubscription(utils.parseEther("15"), "Test");

        await subManager
            .connect(account1)
            .changeSubscriptionLimit(utils.parseEther("10"));
        await subManager.connect(account1).payment(1);

        expect(await token.balanceOf(account1.address)).to.be.equal(utils.parseEther("90"));

        const userData = await subManager.users(account1.address);

        await network.provider.send("evm_increaseTime", [10 * 86400]);
        await network.provider.send("evm_mine");

        await subManager
            .connect(account1)
            .changeSubscriptionLimit(utils.parseEther("15"));
        await subManager.connect(account1).payment(2);

        const userDataThen = await subManager.users(account1.address);

        expect(userDataThen.subscriptionEndDate).to.be.equal(userData.subscriptionEndDate);
        expect(await token.balanceOf(account1.address)).to.be.equal(utils.parseEther("86.666666666666666660"));

        await subManager.connect(account1).payment(1);

        expect(userDataThen.subscriptionEndDate).to.be.equal(userData.subscriptionEndDate);
        expect(await token.balanceOf(account1.address)).to.be.equal(utils.parseEther("86.666666666666666660"));
    }); */
});
