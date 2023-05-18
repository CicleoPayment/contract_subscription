const hre = require("hardhat");

async function main() {
    //Deploy router contract
    const Router = await ethers.getContractFactory("CicleoTestBridge");
    const router = await Router.deploy();
    await router.deployed();

    console.log("Router deployed to:", router.address);

    await router.setToken("0x04068DA6C83AFCFA0e13ba15A6696662335D5B75")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
