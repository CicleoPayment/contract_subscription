const hre = require("hardhat");

async function main() {
    //Deploy router contract
    const Proxy = await ethers.getContractFactory("CicleoProxy");
    const proxy = await Proxy.deploy();
    await proxy.deployed();

    console.log("Proxy deployed to:", proxy.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
