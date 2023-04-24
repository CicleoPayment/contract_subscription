const hre = require("hardhat");

async function main() {
  const Node = await ethers.getContractFactory("CicleoSubscriptionSecurity");

  const node = await upgrades.upgradeProxy("0x073caBB0514C73b7E58163A7869D2919680c4e3c", Node);
  await node.deployed();

  console.log("Node updated");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });