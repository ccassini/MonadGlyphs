const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying MonadGlyphs to Monad testnet...");

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  // Check balance
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Account balance:", ethers.formatEther(balance), "MON");

  // Deploy the contract
  const MonadGlyphs = await ethers.getContractFactory("MonadGlyphs");
  const monadGlyphs = await MonadGlyphs.deploy();
  
  await monadGlyphs.waitForDeployment();
  
  const contractAddress = await monadGlyphs.getAddress();
  console.log("MonadGlyphs deployed to:", contractAddress);

  // Save the contract address for minting
  const fs = require("fs");
  fs.writeFileSync("deployed-address.txt", contractAddress);
  
  console.log("Deployment complete!");
  console.log("Contract address saved to deployed-address.txt");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 