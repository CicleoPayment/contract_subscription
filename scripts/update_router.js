const hre = require("hardhat");

async function main() {
  const Node = await ethers.getContractFactory("CicleoSubscriptionRouter");

  const node = await upgrades.upgradeProxy("0x941dc504D78af17aFbAAe8FF406348426CEeF9af", Node);
  await node.deployed();

  console.log("Node updated");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });