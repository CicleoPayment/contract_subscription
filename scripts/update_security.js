const hre = require("hardhat");

async function main() {
  const Node = await ethers.getContractFactory("CicleoSubscriptionSecurity");

  const node = await upgrades.upgradeProxy("0xd00D67a023079fa7f78C3e6c26bf94Be8f73408d", Node);
  await node.deployed();

  console.log("Node updated");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });