const hre = require("hardhat");

async function main() {
  const Node = await ethers.getContractFactory("CicleoSubscriptionRouter");

  const node = await upgrades.upgradeProxy("0x5AE476d984eA2F1Afd844234d2eEa6f358300fF3", Node);
  await node.deployed();

  console.log("Node updated");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });