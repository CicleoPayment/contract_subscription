const hre = require("hardhat");
const { BigNumber } = require("ethers");

async function main() {
    await hre.run("verify:verify", {
        address: "0xE36d6a2D086798C56AC091828DC2EAE876AF9dbF",
        constructorArguments: [
          ["100000000000000000000"],
          "0x3E6aA1b9C8B2527786FDd752558Ba0E85b940aF6",
          "Wallet DMs"
        ],
      });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
