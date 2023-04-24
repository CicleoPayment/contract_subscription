const hre = require("hardhat");

async function main() {
  const Node = await ethers.getContractFactory("CicleoSubscriptionRouter");

  const node = await upgrades.upgradeProxy("0x7B960C2F89a2829b323e6624cB03f6cD0046C97e", Node);
  await node.deployed();

  console.log("Node updated");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });