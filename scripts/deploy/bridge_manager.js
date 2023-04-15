const hre = require("hardhat");

async function main() {
    const Bridge = await ethers.getContractFactory(
        "CicleoSubscriptionBridgeManager"
    );
    const bridge = await Bridge.deploy()
    await bridge.deployed();

    console.log("Bridge deployed to:", bridge.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
