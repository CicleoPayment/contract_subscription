const hre = require("hardhat");

async function main() {
  const Node = await ethers.getContractFactory("CicleoSubscriptionSecurity");

  const node = await upgrades.upgradeProxy("0x0Ab4CEb2052Fa6D157620c3F354463253c794A26", Node);
  await node.deployed();

  console.log("Node updated");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });