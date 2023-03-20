const hre = require("hardhat");

async function main() {
   /*  const Security = await ethers.getContractFactory(
        "CicleoSubscriptionSecurity"
    );
    const security = await upgrades.deployProxy(Security);
    let tx = await security.deployed();

    await tx.wait(); */

    const Factory = await ethers.getContractFactory(
        "CicleoSubscriptionFactory"
    );
    const factory = await upgrades.deployProxy(Factory, [
        "0xa43194835127C17423ecABB982AAa8de4706aEBD",
        15,
        "0x2e7BcddCD74aDE69B67E816cB32dB6F0B709Cab5",
        "0x6352a56caadc4f1e25cd6c75970fa768a3304e64",
        "0xd00D67a023079fa7f78C3e6c26bf94Be8f73408d",
    ]);
    tx = await factory.deployed();

    //await tx.wait();

    const Router = await ethers.getContractFactory("CicleoSubscriptionRouter");
    const router = await upgrades.deployProxy(Router, [factory.address]);
    tx = await router.deployed();

    //await tx.wait();

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
