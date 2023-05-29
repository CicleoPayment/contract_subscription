const { expect } = require("chai");
const { BigNumber, utils } = require("ethers");
const { ethers, waffle } = require("hardhat");

const {
    getSelectors,
    FacetCutAction,
} = require("./../scripts/deploy/libraries/diamond.js");

const deployDiamond = async (contractOwner) => {
    // deploy DiamondCutFacet
    const DiamondCutFacet = await ethers.getContractFactory("DiamondCutFacet");
    const diamondCutFacet = await DiamondCutFacet.deploy();
    await diamondCutFacet.deployed();
    //const diamondCutFacet = await ethers.getContractAt("DiamondCutFacet", "0xCBf4077c4919fcC019d0B47F157480C4CC985c7d")

    //console.log("DiamondCutFacet deployed:", diamondCutFacet.address);

    // deploy Diamond
    const Diamond = await ethers.getContractFactory("CicleoPaymentDiamond");
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

    // deploy facets
    const FacetNames = {
        DiamondLoupeFacet: "DiamondLoupeFacet",
        AdminFacet: "contracts/Payment/Facets/AdminFacet.sol:AdminFacet",
        PaymentFacet: "contracts/Payment/Facets/PaymentFacet.sol:PaymentFacet",
        PaymentManagerFacet: "PaymentManagerFacet",
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

const deploy = async () => {
    [owner, account1, account2, account3, bot, treasury] =
        await ethers.getSigners();

    let Token = await ethers.getContractFactory("FakeUSDC");
    let token = await Token.deploy();

    const [router, facets] = await deployDiamond(owner);

    let Security = await ethers.getContractFactory("CicleoPaymentSecurity");
    let security = await Security.deploy(router.address);

    await facets.AdminFacet.setTaxPercentage(15);
    await facets.AdminFacet.setTaxAccount(treasury.address);
    await facets.AdminFacet.setSecurity(security.address);

    return [token, facets, security, owner, account1, account2, account3];
};

describe("Payment Test", function () {
    let token;
    let facets;
    let security;
    let owner;
    let account1;
    let account2;
    let account3;

    beforeEach(async function () {
        [token, facets, security, owner, account1, account2, account3] =
            await deploy();

        await token.connect(account1).mint(utils.parseEther("100"));

        await facets.PaymentManagerFacet.createPaymentManager(
            "Test",
            token.address,
            account3.address
        );

        await token
            .connect(account1)
            .approve(
                facets.PaymentManagerFacet.address,
                utils.parseEther("100")
            );
    });

    it("Receive nft", async function () {
        expect(await security.balanceOf(owner.address)).to.equal(1);

        await facets.PaymentManagerFacet.createPaymentManager(
            "Test2",
            token.address,
            account3.address
        );

        expect(await security.balanceOf(owner.address)).to.equal(2);
    });

    it("Ownership", async function () {
        await expect(
            facets.PaymentManagerFacet.connect(
                account1
            ).editPaymentManagerToken(1, token.address)
        ).to.be.revertedWith("Not owner");

        await facets.PaymentManagerFacet.editPaymentManagerToken(
            1,
            token.address
        );

        await security.transferFrom(owner.address, account1.address, 1);

        await facets.PaymentManagerFacet.connect(
            account1
        ).editPaymentManagerToken(1, token.address);
    });

    it("Pay with payment token", async function () {
        await facets.PaymentFacet.connect(account1).payWithCicleo(
            1,
            utils.parseEther("10"),
            "Test payment"
        );

        expect(await token.balanceOf(account1.address)).to.equal(
            utils.parseEther("90")
        );

        expect(await token.balanceOf(account3.address)).to.equal(
            utils.parseEther("9.85")
        );

        expect(await token.balanceOf(treasury.address)).to.equal(
            utils.parseEther("0.15")
        );
    });

    it("Get data", async function () {
        const data = (
            await facets.AdminFacet.getPaymentManagersByUser(owner.address)
        )[0];

        console.log(data);

        expect(data.decimals).to.equal(18);

        expect(data.symbol).to.equal("BUSD");
    });
});
