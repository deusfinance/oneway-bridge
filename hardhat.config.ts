import * as dotenv from "dotenv";

import { HardhatUserConfig, task } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import "@nomiclabs/hardhat-etherscan";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";

dotenv.config();

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

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.13",
        settings: {
          outputSelection: {
            "*": {
              "*": ["storageLayout"],
            },
          },
          optimizer: {
            enabled: true,
            runs: 100000,
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      accounts: {
        mnemonic:
          "weekend friend since level unaware voyage lazy spring put three grunt power",
        path: "m/44'/60'/0'/0",
        initialIndex: 0,
        count: 5,
      },
    },
    fantom: {
      url: `https://rpc.ftm.tools`,
      accounts: [process.env.MAIN_DEPLOYER_PRIVATE_KEY!],
      chainId: 250,
      gas: "auto",
      gasPrice: "auto", //500.1 Gwei
      gasMultiplier: 1.2,
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: process.env.FANTOM_API_KEY,
  },
};

export default config;
