# MonadGlyphs

MonadGlyphs is an algorithmic NFT art collection inspired by the original Autoglyphs, deployed on the Monad blockchain. Each NFT generates unique ASCII art using deterministic algorithms.

## Features

- **Free Mint**: No payment required to mint
- **Algorithmic Art**: Each NFT generates unique ASCII art patterns
- **Limited Supply**: Only 512 tokens available
- **One Per Wallet**: Each address can mint only one NFT
- **SVG Output**: Generates both ASCII and SVG representations

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
