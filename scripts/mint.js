const { ethers } = require("hardhat");
const fs = require("fs");

async function main() {
  console.log("Minting a MonadGlyph...");

  // Read the deployed contract address
  if (!fs.existsSync("deployed-address.txt")) {
    console.error("deployed-address.txt not found. Please deploy the contract first.");
    return;
  }

  const contractAddress = fs.readFileSync("deployed-address.txt", "utf8").trim();
  console.log("Contract address:", contractAddress);

  // Get the minter account
  const [minter] = await ethers.getSigners();
  console.log("Minting with account:", minter.address);

  // Check balance
  const balance = await ethers.provider.getBalance(minter.address);
  console.log("Account balance:", ethers.formatEther(balance), "MON");

  // Connect to the deployed contract
  const MonadGlyphs = await ethers.getContractFactory("MonadGlyphs");
  const monadGlyphs = MonadGlyphs.attach(contractAddress);

  // Check current supply
  const totalSupply = await monadGlyphs.totalSupply();
  console.log("Current supply:", totalSupply.toString());
  console.log("Max supply:", await monadGlyphs.TOKEN_LIMIT());

  // Generate a random seed
  const seed = ethers.keccak256(ethers.toUtf8Bytes(
    Date.now().toString() + minter.address + Math.random().toString()
  ));
  console.log("Generated seed:", seed);

  // Mint a glyph
  console.log("Minting glyph...");
  const tx = await monadGlyphs.createGlyph(seed);
  console.log("Transaction hash:", tx.hash);
  
  const receipt = await tx.wait();
  console.log("Transaction confirmed in block:", receipt.blockNumber);

  // Get the new supply to find the minted token ID
  const newSupply = await monadGlyphs.totalSupply();
  const tokenId = newSupply; // The newly minted token ID
  
  console.log("Minted token ID:", tokenId.toString());
  
  // Get token details
  const creator = await monadGlyphs.creator(tokenId);
  const symbolScheme = await monadGlyphs.symbolScheme(tokenId);
  const minterAddress = await monadGlyphs.minter(tokenId);
  const mintBlockNumber = await monadGlyphs.mintBlock(tokenId);
  
  console.log("Creator:", creator);
  console.log("Minter:", minterAddress);
  console.log("Mint Block:", mintBlockNumber.toString());
  console.log("Symbol Scheme:", symbolScheme);
  
  // Get the token URI (now JSON format for explorers)
  const tokenURI = await monadGlyphs.tokenURI(tokenId);
  console.log("Token URI (JSON):", tokenURI);
  
  // Get raw ASCII art
  const rawArt = await monadGlyphs.getRawArt(tokenId);
  console.log("Raw ASCII Art:", rawArt);
  
  console.log("\nMinting complete!");
  console.log("You now own token ID:", tokenId.toString());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 