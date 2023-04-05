const hre = require("hardhat");

async function main() {
  const Node = await ethers.getContractFactory("CicleoSubscriptionFactory");

  const node = await upgrades.upgradeProxy("0x266B99681EC50f117976603206F0a01E048Ca891", Node);
  await node.deployed();

  console.log("Node updated");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });