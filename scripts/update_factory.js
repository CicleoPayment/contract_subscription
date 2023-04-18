const hre = require("hardhat");

async function main() {
  const Node = await ethers.getContractFactory("CicleoSubscriptionFactory");

  const node = await upgrades.upgradeProxy("0x47cDb0966Fb3Af71058bC263DAAB4F7dF69C750B", Node);
  await node.deployed();

  console.log("Node updated");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });