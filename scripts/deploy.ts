import { ethers, upgrades } from "hardhat";

async function main() {
    const Bridge = await ethers.getContractFactory("DeusBridge")
    console.log("Deploying DeusBridge...")
    const bridge = await upgrades.deployProxy(Bridge, [1,10,"","0xDE12c7959E1a72bbe8a5f7A1dc8f8EeF9Ab011B3"], { initializer: 'initialize' })

    console.log(bridge.address," bridge(proxy) address")
    console.log(await upgrades.erc1967.getImplementationAddress(bridge.address)," getImplementationAddress")
    console.log(await upgrades.erc1967.getAdminAddress(bridge.address)," getAdminAddress")
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
