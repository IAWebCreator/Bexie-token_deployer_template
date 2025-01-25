// scripts/deploy.js
const hre = require("hardhat");
const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log('='.repeat(50));
  console.log("Starting deployment process...");
  console.log('='.repeat(50));
  console.log("Deploying contracts with account:", deployer.address);

  // Check environment variables
  if (!process.env.BEX_DEX_ADDRESS) {
    throw new Error("Missing BEX_DEX_ADDRESS in .env");
  }
  if (!process.env.FEE_COLLECTOR_ADDRESS) {
    throw new Error("Missing FEE_COLLECTOR_ADDRESS in .env");
  }
  if (!process.env.LIQUIDITY_COLLECTOR_ADDRESS) {
    throw new Error("Missing LIQUIDITY_COLLECTOR_ADDRESS in .env");
  }

  // 1) Deploy BexLiquidityManager
  console.log("\nDeploying BexLiquidityManager...");
  const BexLiquidityManager = await hre.ethers.getContractFactory("BexLiquidityManager");
  const bexLiquidityManager = await BexLiquidityManager.deploy(process.env.BEX_DEX_ADDRESS);
  await bexLiquidityManager.waitForDeployment();
  const bexLiquidityManagerAddress = await bexLiquidityManager.getAddress();
  console.log("✓ BexLiquidityManager deployed at:", bexLiquidityManagerAddress);

  // 2) Deploy TokenFactory
  console.log("\nDeploying TokenFactory...");
  const TokenFactory = await hre.ethers.getContractFactory("TokenFactory");
  const tokenFactory = await TokenFactory.deploy(
    process.env.FEE_COLLECTOR_ADDRESS,
    bexLiquidityManagerAddress,
    process.env.LIQUIDITY_COLLECTOR_ADDRESS
  );
  await tokenFactory.waitForDeployment();
  const tokenFactoryAddress = await tokenFactory.getAddress();
  console.log("✓ TokenFactory deployed at:", tokenFactoryAddress);

  // Output addresses to console
  const deploymentInfo = {
    tokenFactoryAddress,
    bexLiquidityManagerAddress,
    bexDexAddress: process.env.BEX_DEX_ADDRESS,
    priceFeedAddress: process.env.PRICE_FEED_ADDRESS,
    feeCollectorAddress: process.env.FEE_COLLECTOR_ADDRESS,
    liquidityCollectorAddress: process.env.LIQUIDITY_COLLECTOR_ADDRESS,
    deployedBy: deployer.address,
    timestamp: new Date().toISOString(),
  };
  
  console.log('\n='.repeat(50));
  console.log("DEPLOYMENT SUMMARY");
  console.log('='.repeat(50));
  console.log(JSON.stringify(deploymentInfo, null, 2));
  console.log('='.repeat(50));
}

main()
  .then(() => {
    console.log("\n✓ Deployment completed successfully!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n✗ Deployment failed:");
    console.error(error);
    process.exit(1);
  });
