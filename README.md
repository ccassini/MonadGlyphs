# MonadGlyphs

MonadGlyphs is an algorithmic NFT art collection inspired by the original Autoglyphs, deployed on the Monad blockchain. Each NFT generates unique ASCII art using deterministic algorithms.

## Features

- **Free Mint**: No payment required to mint
- **Algorithmic Art**: Each NFT generates unique ASCII art patterns
- **Limited Supply**: Only 512 tokens available
- **One Per Wallet**: Each address can mint only one NFT
- **SVG Output**: Generates both ASCII and SVG representations
- **Monad Native**: Deployed on Monad testnet

## Contract Details

- **Contract Name**: MonadGlyphs
- **Symbol**: MGLYPH
- **Max Supply**: 512 tokens
- **Network**: Monad Testnet
- **Chain ID**: 10143

## How It Works

The contract uses the same algorithmic approach as the original Autoglyphs:

1. Each token has a unique seed generated from the block hash and minter address
2. The seed determines the symbol scheme (11 different patterns)
3. A 64x64 grid is generated using mathematical formulas
4. Each cell contains one of 10 possible symbols: `.`, `O`, `+`, `X`, `|`, `-`, `\`, `/`, `#`, `^`
5. The result is both ASCII art and an SVG representation

## Installation

```bash
npm install
```

## Deployment

1. Make sure you have MON tokens in your wallet for gas fees
2. Update the private key in `hardhat.config.js` (currently has a test key)
3. Deploy the contract:

```bash
npm run deploy
```

## Minting

After deployment, you can mint using the provided scripts:

```bash
npm run mint
```

## Project Structure

```
├── contracts/
│   └── MonadGlyphs.sol          # Main contract
├── scripts/
│   ├── deploy.js                # Deployment script
│   ├── mint.js                  # Minting script
│   └── mint-simple.js           # Simple minting script
├── hardhat.config.js            # Hardhat configuration
└── package.json                 # Dependencies
```

## Contract Functions

### Public Functions

- `mint()`: Mint a new NFT (free, one per wallet)
- `tokenURI(uint256 tokenId)`: Get the metadata and SVG for a token
- `draw(uint256 tokenId)`: Get the raw ASCII art for a token
- `getRawArt(uint256 tokenId)`: Get the raw ASCII art for a token

### View Functions

- `totalSupply()`: Get total number of minted tokens
- `balanceOf(address owner)`: Get number of tokens owned by an address
- `ownerOf(uint256 tokenId)`: Get the owner of a specific token

## Art Generation

Each MonadGlyph is generated using:

1. **Seed Generation**: `keccak256(abi.encodePacked(blockhash(block.number-1), msg.sender, block.timestamp))`
2. **Symbol Scheme**: Determined by `seed % 83`, resulting in 11 different pattern types
3. **Grid Generation**: 64x64 grid with mathematical transformations
4. **Symbol Mapping**: Each cell maps to one of 10 ASCII symbols

## Example Output

```
....................X...........................................
...................XXX..........................................
..................XXXXX.........................................
.................XXXXXXX........................................
................XXXXXXXXX.......................................
...............XXXXXXXXXXX......................................
..............XXXXXXXXXXXXX.....................................
.............XXXXXXXXXXXXXXX....................................
............XXXXXXXXXXXXXXXXX...................................
...........XXXXXXXXXXXXXXXXXXX..................................
```

## Technical Details

- **Solidity Version**: 0.8.24
- **ERC-721 Compatible**: Full ERC-721 implementation
- **Gas Optimized**: Uses assembly for string operations
- **Deterministic**: Same seed always produces same art
- **On-chain**: All art generation happens on-chain

## Security Features

- One mint per wallet address
- No payment required (free mint)
- Standard ERC-721 transfer restrictions
- Overflow protection with Solidity 0.8.24

## License

MIT License

## Acknowledgments

Inspired by the original Autoglyphs by Larva Labs, adapted for the Monad ecosystem with enhanced features and free minting. 