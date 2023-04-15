require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("@openzeppelin/hardhat-upgrades");
require("hardhat-gas-reporter");
require("@typechain/hardhat");
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-waffle");
require('dotenv').config()
// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
    const accounts = await hre.ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address);
    }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
const ALCHEMY_API_KEY = process.env.ALCHEMY_API_KEY;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const ETHERSCAN_KEY = process.env.ETHERSCAN_KEY;
const SNOWTRACE_KEY = process.env.SNOWTRACE_KEY;
const BSC_KEY = process.env.BSC_KEY;
const FANTOM_KEY = process.env.FANTOM_KEY;
const POLYGON_KEY = process.env.POLYGON_KEY;
// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
    solidity: {
        compilers: [
            {
                version: "0.8.9",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                        details: {
                            yul: true,
                        },
                    },
                },
            },
            {
                version: "0.6.12",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                        details: {
                            yul: false,
                        },
                    },
                },
            },
        ],
    },
    networks: {
        ropsten: {
            url: `https://eth-ropsten.alchemyapi.io/v2/${ALCHEMY_API_KEY}`,
            accounts: [`${PRIVATE_KEY}`],
            gasPrice: 100000000000,
        },
        fuji: {
            url: "https://api.avax-test.network/ext/bc/C/rpc",
            gasPrice: 225000000000,
            chainId: 43113,
            accounts: [`${PRIVATE_KEY}`],
        },
        avalancheMain: {
            url: "https://api.avax.network/ext/bc/C/rpc",
            gasPrice: 225000000000,
            chainId: 43114,
            accounts: [`${PRIVATE_KEY}`],
        },
        bsb: {
            url: "https://bsc-dataseed.binance.org/",
            chainId: 56,
            accounts: [`${PRIVATE_KEY}`],
        },
        fantom: {
            url: "https://rpcapi.fantom.network/",
            chainId: 250,
            accounts: [`${PRIVATE_KEY}`],
        },
        bsbTest: {
            url: "https://bsc-testnet.public.blastapi.io",
            chainId: 97,
            accounts: [`${PRIVATE_KEY}`],
        },
        polygon: {
            url: "https://polygon-rpc.com",
            chainId: 137,
            accounts: [`${PRIVATE_KEY}`],
        }
    },
    etherscan: {
        apiKey: {
            ropsten: ETHERSCAN_KEY,
            avalanche: SNOWTRACE_KEY,
            avalancheFujiTestnet: SNOWTRACE_KEY,
            bscTestnet: BSC_KEY,
            bsc: BSC_KEY,
            opera: FANTOM_KEY,
            polygon: POLYGON_KEY
        },
    },
};
