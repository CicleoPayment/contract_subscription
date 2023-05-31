const hre = require("hardhat");

async function main() {
    //Deploy security contract
    const Security = await ethers.getContractFactory(
        "CicleoSubscriptionSecurity"
    );
    const security = await upgrades.deployProxy(Security);
    await security.deployed();

    //Deploy factory contract
    const Factory = await ethers.getContractFactory(
        "CicleoSubscriptionFactory"
    );
    const factory = await upgrades.deployProxy(Factory, [
        security.address, //Securify address
    ]);
    await factory.deployed();

    await security.setFactory(factory.address);

    console.log("Security deployed to:", security.address);
    console.log("Router deployed to:", router.address);
    console.log("Factory deployed to:", factory.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
