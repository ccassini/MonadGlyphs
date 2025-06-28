const { ethers } = require("hardhat");
const fs = require("fs");

async function main() {
  console.log("Simple mint for MonadGlyph...");

  // Read the deployed contract address
  const contractAddress = fs.readFileSync("deployed-address.txt", "utf8").trim();
  
  // Get the minter account
  const [minter] = await ethers.getSigners();
  console.log("Minting with:", minter.address);

  // Connect to the deployed contract
  const MonadGlyphs = await ethers.getContractFactory("MonadGlyphs");
  const monadGlyphs = MonadGlyphs.attach(contractAddress);

  // Mint
  const tx = await monadGlyphs.mint();
  console.log("Tx hash:", tx.hash);
  
  await tx.wait();
  console.log("Minted!");
}

main().catch(console.error); 