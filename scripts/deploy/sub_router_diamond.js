/* global ethers */
/* eslint prefer-const: "off" */

const { ethers } = require("hardhat");
const { getSelectors, FacetCutAction } = require("./libraries/diamond.js");

async function deployDiamond() {
    const accounts = await ethers.getSigners();
    const contractOwner = accounts[0];

    // deploy DiamondCutFacet
    const DiamondCutFacet = await ethers.getContractFactory("DiamondCutFacet");
    const diamondCutFacet = await DiamondCutFacet.deploy();
    await diamondCutFacet.deployed();
    /* const diamondCutFacet = await ethers.getContractAt(
        "DiamondCutFacet",
        "0x7FD0A008f1C1D77B4750d9808c63eF82a5c54F5c"
    ); */

    console.log("DiamondCutFacet deployed:", diamondCutFacet.address);

    // deploy Diamond
    const Diamond = await ethers.getContractFactory(
        "CicleoSubscriptionRouterDiamond"
    );
    const diamond = await Diamond.deploy(
        contractOwner.address,
        diamondCutFacet.address
    );
    await diamond.deployed();
    console.log("Diamond deployed:", diamond.address);

    // deploy DiamondInit
    // DiamondInit provides a function that is called when the diamond is upgraded to initialize state variables
    // Read about how the diamondCut function works here: https://eips.ethereum.org/EIPS/eip-2535#addingreplacingremoving-functions
    const DiamondInit = await ethers.getContractFactory("DiamondInit");
    const diamondInit = await DiamondInit.deploy();
    await diamondInit.deployed();
    console.log("DiamondInit deployed:", diamondInit.address);

    // deploy facets
    console.log("");
    console.log("Deploying facets");
    const FacetNames = {
        DiamondLoupeFacet: "DiamondLoupeFacet",
        AdminFacet:
            "contracts/Subscription/Router/Facets/AdminFacet.sol:AdminFacet",
        BridgeFacet:
            "contracts/Subscription/Router/Facets/BridgeFacet.sol:BridgeFacet",
        PaymentFacet:
            "contracts/Subscription/Router/Facets/PaymentFacet.sol:PaymentFacet",
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
    console.log("");
    console.log("Diamond Cut:", cut);
    const diamondCut = await ethers.getContractAt(
        "IDiamondCut",
        diamond.address
    );
    let tx;
    let receipt;
    // call to init function
    let functionCall = diamondInit.interface.encodeFunctionData("init");
    tx = await diamondCut.diamondCut(cut, diamondInit.address, functionCall);
    console.log("Diamond cut tx: ", tx.hash);
    receipt = await tx.wait();
    if (!receipt.status) {
        throw Error(`Diamond upgrade failed: ${tx.hash}`);
    }
    console.log("Completed diamond cut");
    return diamond.address;
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
if (require.main === module) {
    deployDiamond()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
}

exports.deployDiamond = deployDiamond;
