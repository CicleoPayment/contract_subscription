const hre = require("hardhat");

async function main() {
  const Node = await ethers.getContractFactory("CicleoSubscriptionFactory");

  const node = await upgrades.upgradeProxy("0xEF496b9ecf5D44a4F2fC76b63334d84CECACD1dF", Node);
  await node.deployed();

  console.log("Node updated");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });