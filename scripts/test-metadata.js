const { ethers } = require("hardhat");
const fs = require("fs");

async function main() {
  console.log("Testing MonadGlyphs metadata...");

  // Read the deployed contract address
  if (!fs.existsSync("deployed-address.txt")) {
    console.error("deployed-address.txt not found. Please deploy the contract first.");
    return;
  }

  const contractAddress = fs.readFileSync("deployed-address.txt", "utf8").trim();
  console.log("Contract address:", contractAddress);

  // Connect to the deployed contract
  const MonadGlyphs = await ethers.getContractFactory("MonadGlyphs");
  const monadGlyphs = MonadGlyphs.attach(contractAddress);

  // Test with token ID 1 (assuming it exists)
  const tokenId = 1;
  
  try {
    // Check if token exists
    const owner = await monadGlyphs.ownerOf(tokenId);
    console.log("Token owner:", owner);
    
    // Get token details
    const creator = await monadGlyphs.creator(tokenId);
    const symbolScheme = await monadGlyphs.symbolScheme(tokenId);
    const minterAddress = await monadGlyphs.minter(tokenId);
    const mintBlockNumber = await monadGlyphs.mintBlock(tokenId);
    
    console.log("Creator:", creator);
    console.log("Minter:", minterAddress);
    console.log("Mint Block:", mintBlockNumber.toString());
    console.log("Symbol Scheme:", symbolScheme.toString());
    
    // Get the raw ASCII art
    console.log("\n--- Raw ASCII Art (tokenURI) ---");
    const tokenURI = await monadGlyphs.tokenURI(tokenId);
    console.log(tokenURI);
    
    // Get JSON metadata
    console.log("\n--- JSON Metadata ---");
    const metadata = await monadGlyphs.getMetadata(tokenId);
    console.log(metadata);
    
  } catch (error) {
    console.error("Error:", error.message);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 