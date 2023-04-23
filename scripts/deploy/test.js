const hre = require("hardhat");

async function main() {
    //Deploy security contract
    /* const Security = await ethers.getContractFactory(
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
    await factory.deployed(); */

    //Deploy router contract
    const Router = await ethers.getContractFactory("CicleoSubscriptionRouter");
    const router = await upgrades.deployProxy(Router, [
        "0x1a0635dE080b525e23A6835730DCa2240d347E14",
        "0x2e7BcddCD74aDE69B67E816cB32dB6F0B709Cab5", //Tax Account
        15, //Tax percentage out of 1000
        "0xa43194835127C17423ecABB982AAa8de4706aEBD", //Bot address
    ]);
    await router.deployed();

    await security.setFactory("0x1a0635dE080b525e23A6835730DCa2240d347E14");
    await factory.setRouterSubscription("0x7B960C2F89a2829b323e6624cB03f6cD0046C97e");

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
