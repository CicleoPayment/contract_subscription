const hre = require("hardhat");

async function main() {
  const Node = await ethers.getContractFactory("CicleoSubscriptionFactory");

  const node = await upgrades.upgradeProxy("0x2A3cd887167979Ae577577f9dE60C92b7b28A261", Node);
  await node.deployed();

  console.log("Node updated");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });