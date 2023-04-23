const hre = require("hardhat");

async function main() {
  const Node = await ethers.getContractFactory("CicleoSubscriptionRouter");

  const node = await upgrades.upgradeProxy("0x646F7Ab7066900F189e822F147CB983865Ff24AC", Node);
  await node.deployed();

  console.log("Node updated");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });