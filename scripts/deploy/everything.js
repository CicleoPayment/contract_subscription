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
        "0xa43194835127C17423ecABB982AAa8de4706aEBD",   //Bot address
        15,                                             //Tax percentage out of 1000
        "0x2e7BcddCD74aDE69B67E816cB32dB6F0B709Cab5",   //Tax Account
        security.address,                               //Securify address
    ]);
    await factory.deployed();


    //Deploy router contract
    const Router = await ethers.getContractFactory("CicleoSubscriptionRouter");
    const router = await upgrades.deployProxy(Router, [factory.address]);
    await router.deployed();

    await security.setFactory(factory.address);
    await factory.setRouter(router.address);

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
