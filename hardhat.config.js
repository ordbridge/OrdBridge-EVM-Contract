require("@nomicfoundation/hardhat-toolbox");
require ("@nomicfoundation/hardhat-verify");
require('@openzeppelin/hardhat-upgrades');

/** @type import('hardhat/config').HardhatUserConfig */
require('dotenv').config();
const sepoliaUrl = process.env.SEPOLIA_URL;
const sepoliaAccount = process.env.SEPOLIA_ACCOUNT;

module.exports = {
  sourcify: {
    enabled: true
  },
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  etherscan: {
    apiKey: {
      snowtrace: "snowtrace", // apiKey is not required, just set a placeholder
      //sepolia: sepoliaApiKey,
    },
    customChains: [
      {
        network: "snowtrace",
        chainId: 43114,
        urls: {
          apiURL: "https://api.routescan.io/v2/network/mainnet/evm/43114/etherscan",
          browserURL: "https://avalanche.routescan.io"
        }
      }
    ]
  },
  networks: {
    mainnet: {
      url: 'https://ethereum.publicnode.com',
      // accounts: [process.env.PRIVATE_KEY]
    },
    snowtrace: {
      url: 'https://api.avax.network/ext/bc/C/rpc',
      // accounts: [process.env.PRIVATE_KEY]
    },
    sepolia: {
      url: sepoliaUrl,
      accounts: [sepoliaAccount],
    }
  },
};