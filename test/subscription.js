const { expect } = require("chai");
const { BigNumber, utils } = require("ethers");
const { ethers, waffle } = require("hardhat");
const {
    getSelectors,
    FacetCutAction,
} = require("../scripts/deploy/libraries/diamond.js");
const provider = waffle.provider;

function sign(signer, data) {
    return signer.signMessage(data);
}

const deployDiamond = async (contractOwner) => {
    // deploy DiamondCutFacet
    const DiamondCutFacet = await ethers.getContractFactory("DiamondCutFacet");
    const diamondCutFacet = await DiamondCutFacet.deploy();
    await diamondCutFacet.deployed();
    //const diamondCutFacet = await ethers.getContractAt("DiamondCutFacet", "0xCBf4077c4919fcC019d0B47F157480C4CC985c7d")

    //console.log("DiamondCutFacet deployed:", diamondCutFacet.address);

    // deploy Diamond
    const Diamond = await ethers.getContractFactory(
        "CicleoSubscriptionDiamond"
    );
    const diamond = await Diamond.deploy(
        contractOwner.address,
        diamondCutFacet.address
    );
    await diamond.deployed();
    //console.log("Diamond deployed:", diamond.address);

    // deploy DiamondInit
    // DiamondInit provides a function that is called when the diamond is upgraded to initialize state variables
    // Read about how the diamondCut function works here: https://eips.ethereum.org/EIPS/eip-2535#addingreplacingremoving-functions
    const DiamondInit = await ethers.getContractFactory("DiamondInit");
    const diamondInit = await DiamondInit.deploy();
    await diamondInit.deployed();

    const FacetNames = {
        DiamondLoupeFacet: "DiamondLoupeFacet",
        AdminFacet: "contracts/Subscription/Facets/AdminFacet.sol:AdminFacet",
        BridgeFacet:
            "contracts/Subscription/Facets/BridgeFacet.sol:BridgeFacet",
        PaymentFacet:
            "contracts/Subscription/Facets/PaymentFacet.sol:PaymentFacet",
        SubscriptionTypesFacet: "SubscriptionTypesFacet",
    };
    const cut = [];
    const facets = {};
    for (const FacetName in FacetNames) {
        const Facet = await ethers.getContractFactory(FacetNames[FacetName]);
        const facet = await Facet.deploy();
        await facet.deployed();
        //console.log(`${FacetName} deployed: ${facet.address}`);
        cut.push({
            facetAddress: facet.address,
            action: FacetCutAction.Add,
            functionSelectors: getSelectors(facet),
        });
        facets[FacetName] = await ethers.getContractAt(
            FacetNames[FacetName],
            diamond.address
        );
    }

    // upgrade diamond with facets
    //console.log("");
    // console.log("Diamond Cut:", cut);
    const diamondCut = await ethers.getContractAt(
        "IDiamondCut",
        diamond.address
    );
    let tx;
    let receipt;
    // call to init function
    let functionCall = diamondInit.interface.encodeFunctionData("init");
    tx = await diamondCut.diamondCut(cut, diamondInit.address, functionCall);
    //console.log("Diamond cut tx: ", tx.hash);
    receipt = await tx.wait();
    if (!receipt.status) {
        throw Error(`Diamond upgrade failed: ${tx.hash}`);
    }
    //console.log("Completed diamond cut");

    return [diamond, facets];
};

const Deployy = async () => {
    [owner, account1, account2, account3, bot, treasury] =
        await ethers.getSigners();

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

    const [router, facets] = await deployDiamond(owner);

    await facets.AdminFacet.setFactory(factory.address);
    await facets.PaymentFacet.setTaxRate(15);
    await facets.PaymentFacet.setBotAccount(bot.address);
    await facets.PaymentFacet.setTax(treasury.address);

    await security.setFactory(factory.address);

    await factory.setRouterSubscription(router.address);

    return [
        token,
        factory,
        facets,
        security,
        owner,
        account1,
        account2,
        account3,
    ];
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
        [
            token,
            factory,
            router,
            security,
            owner,
            account1,
            account2,
            account3,
        ] = await Deployy();

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

        await router.SubscriptionTypesFacet.newSubscription(
            1,
            utils.parseEther("10"),
            "Test"
        );

        await token
            .connect(account1)
            .approve(subManager.address, utils.parseEther("100"));
    });

    it("Verify if factory return good name", async function () {
        const subManagerStruct =
            await router.SubscriptionTypesFacet.getSubscriptionsManager(
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
        await router.PaymentFacet.connect(account1).subscribe(
            1,
            1,
            ethers.constants.AddressZero
        );

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
            router.PaymentFacet.connect(account1).subscribe(
                1,
                0,
                ethers.constants.AddressZero
            )
        ).to.be.revertedWith("Wrong sub type");
        await expect(
            router.PaymentFacet.connect(account1).subscribe(
                1,
                2,
                ethers.constants.AddressZero
            )
        ).to.be.revertedWith("Wrong sub type");
    });

    it("Subscription expiration", async function () {
        await subManager
            .connect(account1)
            .changeSubscriptionLimit(utils.parseEther("10"));
        await router.PaymentFacet.connect(account1).subscribe(
            1,
            1,
            ethers.constants.AddressZero
        );

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
            router.PaymentFacet.connect(account1).subscribe(
                1,
                1,
                ethers.constants.AddressZero
            )
        ).to.be.revertedWith(
            "You need to approve our contract to spend this amount of token"
        );

        await subManager
            .connect(account1)
            .changeSubscriptionLimit(utils.parseEther("10"));

        await router.PaymentFacet.connect(account1).subscribe(
            1,
            1,
            ethers.constants.AddressZero
        );

        await router.SubscriptionTypesFacet.editSubscription(
            1,
            1,
            utils.parseEther("20"),
            true,
            "Test"
        );

        await network.provider.send("evm_increaseTime", [31 * 86400]);
        await network.provider.send("evm_mine");

        await expect(
            router.PaymentFacet.connect(bot).subscriptionRenew(
                1,
                account1.address
            )
        ).to.be.revertedWith(
            "You need to approve our contract to spend this amount of tokens"
        );

        expect(
            (await subManager.getUserSubscriptionStatus(account1.address))[1]
        ).to.be.equal(false);
    });

    it("Get Subscription", async function () {
        expect(
            (await router.SubscriptionTypesFacet.getSubscriptions(1))[0][0]
        ).to.be.equal(utils.parseEther("10"));
        expect(
            (await router.SubscriptionTypesFacet.getSubscriptions(1))[0][1]
        ).to.be.equal(true);
        expect(
            (await router.SubscriptionTypesFacet.getSubscriptions(1))[0][2]
        ).to.be.equal("Test");
    });

    it("Subscription renew", async function () {
        expect(await token.balanceOf(account1.address)).to.be.equal(
            utils.parseEther("100")
        );

        await subManager
            .connect(account1)
            .changeSubscriptionLimit(utils.parseEther("10"));
        await router.PaymentFacet.connect(account1).subscribe(
            1,
            1,
            ethers.constants.AddressZero
        );

        expect(await token.balanceOf(account1.address)).to.be.equal(
            utils.parseEther("90")
        );

        await expect(
            router.PaymentFacet.connect(bot).subscriptionRenew(
                1,
                account1.address
            )
        ).to.be.revertedWith(
            "You can't renew before the end of your subscription"
        );

        await network.provider.send("evm_increaseTime", [31 * 86400]);
        await network.provider.send("evm_mine");

        await expect(
            router.PaymentFacet.subscriptionRenew(1, account1.address)
        ).to.be.revertedWith("Only bot");

        expect(
            (await subManager.getUserSubscriptionStatus(account1.address))[1]
        ).to.be.equal(false);

        expect(await token.balanceOf(account1.address)).to.be.equal(
            utils.parseEther("90")
        );

        await router.PaymentFacet.connect(bot).subscriptionRenew(
            1,
            account1.address
        );

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
        await router.PaymentFacet.connect(account1).subscribe(
            1,
            1,
            ethers.constants.AddressZero
        );

        expect(await token.balanceOf(account1.address)).to.be.equal(
            utils.parseEther("90")
        );

        await expect(
            router.PaymentFacet.connect(bot).subscriptionRenew(
                1,
                account1.address
            )
        ).to.be.revertedWith(
            "You can't renew before the end of your subscription"
        );

        await network.provider.send("evm_increaseTime", [30 * 86400]);
        await network.provider.send("evm_mine");

        expect(await token.balanceOf(account1.address)).to.be.equal(
            utils.parseEther("90")
        );

        await router.PaymentFacet.connect(bot).subscriptionRenew(
            1,
            account1.address
        );

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
        await router.PaymentFacet.connect(account1).subscribe(
            1,
            1,
            ethers.constants.AddressZero
        );

        expect(await token.balanceOf(treasury.address)).to.be.equal(
            utils.parseEther("0.15")
        );
        expect(await token.balanceOf(account2.address)).to.be.equal(
            utils.parseEther("9.85")
        );
    });

    it("Active Subscription Count", async function () {
        await router.SubscriptionTypesFacet.newSubscription(
            1,
            utils.parseEther("10"),
            "Test"
        );
        await router.SubscriptionTypesFacet.editSubscription(
            1,
            1,
            utils.parseEther("10"),
            "Test",
            false
        );

        expect(
            await router.SubscriptionTypesFacet.getActiveSubscriptionCount(1)
        ).to.be.equal(1);

        await router.SubscriptionTypesFacet.editSubscription(
            1,
            2,
            utils.parseEther("10"),
            "Test",
            false
        );

        expect(
            await router.SubscriptionTypesFacet.getActiveSubscriptionCount(1)
        ).to.be.equal(0);
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
        const subManagerInfo =
            await router.SubscriptionTypesFacet.getSubscriptionManager(1);

        expect(subManagerInfo.owners[0]).to.be.equal(owner.address);
    });

    it("Pay subscription type", async function () {
        expect(await token.balanceOf(account1.address)).to.be.equal(
            utils.parseEther("100")
        );

        await subManager
            .connect(account1)
            .changeSubscriptionLimit(utils.parseEther("10"));
        await router.PaymentFacet.connect(account1).subscribe(
            1,
            1,
            ethers.constants.AddressZero
        );
        await router.SubscriptionTypesFacet.newSubscription(
            1,
            utils.parseEther("50"),
            "Test"
        );

        await network.provider.send("evm_increaseTime", [15 * 86400]);
        await network.provider.send("evm_mine");

        expect(
            await router.PaymentFacet.getChangeSubscriptionPrice(
                1,
                account1.address,
                2
            )
        ).to.be.equal(utils.parseEther("19.999984567901234567"));
    });

    it("Referral test without being subscribed", async function () {
        expect(await token.balanceOf(account3.address)).to.be.equal(0);

        //Set referral percent to 1%
        await router.PaymentFacet.setReferralPercent(1, 10);
        await subManager
            .connect(account1)
            .changeSubscriptionLimit(utils.parseEther("10"));
        await router.PaymentFacet.connect(account1).subscribe(
            1,
            1,
            account3.address
        );

        expect(await token.balanceOf(account3.address)).to.be.equal(0); //utils.parseEther("0.0985")
    });

    it("Referral test", async function () {
        expect(await token.balanceOf(account3.address)).to.be.equal(0);

        //Set referral percent to 1%
        await router.PaymentFacet.setReferralPercent(1, 10);

        await router.AdminFacet.editAccount(
            1,
            account3.address,
            Math.ceil(Date.now() / 1000) + 86400,
            1
        );

        await subManager
            .connect(account1)
            .changeSubscriptionLimit(utils.parseEther("10"));
        await router.PaymentFacet.connect(account1).subscribe(
            1,
            1,
            account3.address
        );

        expect(await token.balanceOf(account3.address)).to.be.equal(0); //utils.parseEther("0.0985")
    });

    it("Free subscription test", async function () {
        await router.SubscriptionTypesFacet.newSubscription(
            1,
            utils.parseEther("0"),
            "Test"
        );

        expect(await token.balanceOf(account1.address)).to.be.equal(
            utils.parseEther("100")
        );

        await subManager
            .connect(account1)
            .changeSubscriptionLimit(utils.parseEther("10"));
        await router.PaymentFacet.connect(account1).subscribe(
            1,
            2,
            ethers.constants.AddressZero
        );

        expect(await token.balanceOf(account1.address)).to.be.equal(
            utils.parseEther("100")
        );

        await network.provider.send("evm_increaseTime", [90 * 86400]);
        await network.provider.send("evm_mine");

        const res = await subManager.getUserSubscriptionStatus(
            account1.address
        );

        expect(res.isActive).to.equal(true);

        await router.PaymentFacet.connect(account1).subscribe(
            1,
            1,
            ethers.constants.AddressZero
        );

        expect(
            (await subManager.getUserSubscriptionStatus(account1.address))[1]
        ).to.equal(true);

        await network.provider.send("evm_increaseTime", [30 * 86400]);
        await network.provider.send("evm_mine");

        expect(
            (await subManager.getUserSubscriptionStatus(account1.address))[1]
        ).to.equal(false);
    });

    it("Test bridge tx", async function () {
        const message = await router.BridgeFacet.getMessage(
            1,
            1,
            account1.address,
            utils.parseEther("10"),
            0
        );

        const signed = await sign(account1, message);

        await token.mint(utils.parseEther("10"));

        await token.approve(router.BridgeFacet.address, utils.parseEther("10"));

        await router.BridgeFacet.bridgeSubscribe(
            [1, 1, 1, utils.parseEther("10"), token.address],
            account1.address,
            ethers.constants.AddressZero,
            signed
        );

        expect(
            (await subManager.getUserSubscriptionStatus(account1.address))[0]
        ).to.equal(1);

        expect(
            (await subManager.getUserSubscriptionStatus(account1.address))[1]
        ).to.equal(true);
    });

    it("Test bridge tx with change", async function () {
        const message = await router.BridgeFacet.getMessage(
            1,
            1,
            account1.address,
            utils.parseEther("10"),
            0
        );
        const signed = await sign(account1, message);

        await token.mint(utils.parseEther("15"));

        await token.approve(router.BridgeFacet.address, utils.parseEther("15"));

        await router.BridgeFacet.bridgeSubscribe(
            [1, 1, 1, utils.parseEther("10"), token.address],
            account1.address,
            ethers.constants.AddressZero,
            signed
        );

        await router.SubscriptionTypesFacet.newSubscription(
            1,
            utils.parseEther("15"),
            "Test"
        );

        const amount = await router.PaymentFacet.getChangeSubscriptionPrice(
            1,
            account1.address,
            2
        );

        const message2 = await router.BridgeFacet.getMessage(
            1,
            2,
            account1.address,
            amount.toString(),
            1
        );
        const signed2 = await sign(account1, message2);

        await router.BridgeFacet.bridgeSubscribe(
            [1, 1, 2, amount.toString(), token.address],
            account1.address,
            ethers.constants.AddressZero,
            signed2
        );

        const message3 = await router.BridgeFacet.getMessage(
            1,
            1,
            account1.address,
            0,
            2
        );
        const signed3 = await sign(account1, message3);

        await router.BridgeFacet.bridgeSubscribe(
            [1, 1, 1, 0, token.address],
            account1.address,
            ethers.constants.AddressZero,
            signed3
        );

        const message4 = await router.BridgeFacet.getMessage(
            1,
            2,
            account1.address,
            0,
            3
        );
        const signed4 = await sign(account1, message4);

        await router.BridgeFacet.bridgeSubscribe(
            [1, 1, 2, 0, token.address],
            account1.address,
            ethers.constants.AddressZero,
            signed4
        );

        await network.provider.send("evm_increaseTime", [30 * 86400]);
        await network.provider.send("evm_mine");

        await token.connect(bot).mint(utils.parseEther("15"));
        await token
            .connect(bot)
            .approve(router.BridgeFacet.address, utils.parseEther("15"));

        await router.BridgeFacet.connect(bot).bridgeRenew(1, account1.address);

        expect(await token.balanceOf(bot.address)).to.equal(
            BigNumber.from("0")
        );
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
