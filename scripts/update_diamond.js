/* global ethers */
/* eslint prefer-const: "off" */

const { getSelectors, FacetCutAction } = require("./deploy/libraries/diamond.js");

async function deployDiamond() {
    const accounts = await ethers.getSigners();
    const contractOwner = accounts[0];

    // deploy facets
    console.log("");
    console.log("Deploying facets");
    const FacetNames = [
        "PaymentFacet",
    ];
    const cut = [];
    for (const FacetName of FacetNames) {
        const Facet = await ethers.getContractFactory(FacetName);

        const facet = await Facet.deploy();
        await facet.deployed();
        console.log(`${FacetName} deployed: ${facet.address}`);



        cut.push({
            facetAddress: facet.address,
            action: FacetCutAction.Replace,
            functionSelectors: [getSelectors(Facet)],
        }); 
    }

    // upgrade diamond with facets
    /* console.log("");
    console.log("Diamond Cut:", cut);
    const diamondCut = await ethers.getContractAt(
        "IDiamondCut",
        "0xd54140d51657e59aD74C2F5aE7EF14aFE5990228"
    );
    let tx;
    let receipt;
    // call to init function
    tx = await diamondCut.diamondCut(cut, "0xd54140d51657e59aD74C2F5aE7EF14aFE5990228", "0x");
    console.log("Diamond cut tx: ", tx.hash);
    receipt = await tx.wait();
    if (!receipt.status) {
        throw Error(`Diamond upgrade failed: ${tx.hash}`);
    }
    console.log("Completed diamond cut"); */

    const diamondCut = await ethers.getContractAt(
        "SubscriptionTypesFacet",
        "0xd54140d51657e59aD74C2F5aE7EF14aFE5990228"
    );
    let tx;
    let receipt;
    // call to init function
    tx = await diamondCut.subscriptions(1, 1);
    console.log(tx)
    receipt = await tx.wait();
    if (!receipt.status) {
        throw Error(`Diamond upgrade failed: ${tx.hash}`);
    }
    console.log("Completed diamond cut");
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
