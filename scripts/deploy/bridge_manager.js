const hre = require("hardhat");

async function main() {
    const Bridge = await ethers.getContractFactory(
        "CicleoSubscriptionBridgeManager"
    );
    const bridge = await Bridge.deploy("0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE")
    await bridge.deployed();

    console.log("Bridge deployed to:", bridge.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
