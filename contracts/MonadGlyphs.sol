// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 *
 *    ****     ****   *********   ****     ****   *******   *********       ******   **      **    **  ********  **     **  ******
 *   ******   ******  **     **  ******   ****  **     **  **     **      **    **  **        **  **   **     ** **     ** **    **
 *   **  ** **  **    **     **  ** *** ** **   **     **  **     **      **        **         ****    **     ** **     ** **
 *   **   ***   **    **     **  **  *****  **  **********  **     **      **   ****  **         **     ********  *********  ******
 *   **    *    **    **     **  **   ***   **  **     **   **     **      **    **   **         **     **        **     **       **
 *   **         **    **     **  **    *    **  **     **   **     **      **    **   **         **     **        **     ** **    **
 *   **         **     *******   **         **  **     **   *********       ******    ********   **     **        **     **  ******
 *
 *
 *                                                                        Monad Algorithmic Art Collection
 *
 *
 * The output of the 'tokenURI' function is a set of instructions to make a drawing.
 * Each symbol in the output corresponds to a cell, and there are 64x64 cells arranged in a square grid.
 * The drawing can be any size, and the pen's stroke width should be between 1/5th to 1/10th the size of a cell.
 * The drawing instructions for the ten different symbols are as follows:
 *
 *   .  Draw nothing in the cell.
 *   O  Draw a circle bounded by the cell.
 *   +  Draw centered lines vertically and horizontally the length of the cell.
 *   X  Draw diagonal lines connecting opposite corners of the cell.
 *   |  Draw a centered vertical line the length of the cell.
 *   -  Draw a centered horizontal line the length of the cell.
 *   \  Draw a line connecting the top left corner of the cell to the bottom right corner.
 *   /  Draw a line connecting the bottom left corner of the cell to the top right corner.
 *   #  Fill in the cell completely.
 *   ^  Draw an upward pointing triangle in the cell.
 *
 */

interface ERC721TokenReceiver {
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes calldata _data) external returns(bytes4);
}

contract MonadGlyphs {

    event Generated(uint indexed index, address indexed a, string value);

    /// @dev This emits when ownership of any NFT changes by any mechanism.
    ///  This event emits when NFTs are created (`from` == 0) and destroyed
    ///  (`to` == 0). Exception: during contract creation, any number of NFTs
    ///  may be created and assigned without emitting Transfer. At the time of
    ///  any transfer, the approved address for that NFT (if any) is reset to none.
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);

    /// @dev This emits when the approved address for an NFT is changed or
    ///  reaffirmed. The zero address indicates there is no approved address.
    ///  When a Transfer event emits, this also indicates that the approved
    ///  address for that NFT (if any) is reset to none.
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);

    /// @dev This emits when an operator is enabled or disabled for an owner.
    ///  The operator can manage all NFTs of the owner.
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    bytes4 internal constant MAGIC_ON_ERC721_RECEIVED = 0x150b7a02;

    uint public constant TOKEN_LIMIT = 512;

    mapping (uint => address) private idToCreator;
    mapping (uint => uint8) private idToSymbolScheme;
    mapping (address => bool) private hasMinted;
    mapping (uint => address) private idToMinter; // Mint eden kişinin adresi
    mapping (uint => uint256) private idToMintBlock; // Mint edildiği block numarası

    // ERC 165
    mapping(bytes4 => bool) internal supportedInterfaces;

    /**
     * @dev A mapping from NFT ID to the address that owns it.
     */
    mapping (uint256 => address) internal idToOwner;

    /**
     * @dev A mapping from NFT ID to the seed used to make it.
     */
    mapping (uint256 => uint256) internal idToSeed;
    mapping (uint256 => uint256) internal seedToId;

    /**
     * @dev Mapping from NFT ID to approved address.
     */
    mapping (uint256 => address) internal idToApproval;

    /**
     * @dev Mapping from owner address to mapping of operator addresses.
     */
    mapping (address => mapping (address => bool)) internal ownerToOperators;

    /**
     * @dev Mapping from owner to list of owned NFT IDs.
     */
    mapping(address => uint256[]) internal ownerToIds;

    /**
     * @dev Mapping from NFT ID to its index in the owner tokens list.
     */
    mapping(uint256 => uint256) internal idToOwnerIndex;

    /**
     * @dev Total number of tokens.
     */
    uint internal numTokens = 0;

    /**
     * @dev Guarantees that the msg.sender is an owner or operator of the given NFT.
     * @param _tokenId ID of the NFT to validate.
     */
    modifier canOperate(uint256 _tokenId) {
        address tokenOwner = idToOwner[_tokenId];
        require(tokenOwner == msg.sender || ownerToOperators[tokenOwner][msg.sender]);
        _;
    }

    /**
     * @dev Guarantees that the msg.sender is allowed to transfer NFT.
     * @param _tokenId ID of the NFT to transfer.
     */
    modifier canTransfer(uint256 _tokenId) {
        address tokenOwner = idToOwner[_tokenId];
        require(
            tokenOwner == msg.sender
            || idToApproval[_tokenId] == msg.sender
            || ownerToOperators[tokenOwner][msg.sender]
        );
        _;
    }

    /**
     * @dev Guarantees that _tokenId is a valid Token.
     * @param _tokenId ID of the NFT to validate.
     */
    modifier validNFToken(uint256 _tokenId) {
        require(idToOwner[_tokenId] != address(0));
        _;
    }

    /**
     * @dev Contract constructor.
     */
    constructor() {
        supportedInterfaces[0x01ffc9a7] = true; // ERC165
        supportedInterfaces[0x80ac58cd] = true; // ERC721
        supportedInterfaces[0x780e9d63] = true; // ERC721 Enumerable
        supportedInterfaces[0x5b5e139f] = true; // ERC721 Metadata
    }

    ///////////////////
    //// GENERATOR ////
    ///////////////////

    int constant ONE = int(0x100000000);
    uint constant USIZE = 64;
    int constant SIZE = int(USIZE);
    int constant HALF_SIZE = SIZE / int(2);

    int constant SCALE = int(0x1b81a81ab1a81a823);
    int constant HALF_SCALE = SCALE / int(2);

    bytes constant prefix = "data:text/plain;charset=utf-8,";

    string internal nftName = "MonadGlyphs";
    string internal nftSymbol = "MGLYPH";

    // 0x2E = .
    // 0x4F = O
    // 0x2B = +
    // 0x58 = X
    // 0x7C = |
    // 0x2D = -
    // 0x5C = \
    // 0x2F = /
    // 0x23 = #
    // 0x5E = ^

    function abs(int n) internal pure returns (int) {
        if (n >= 0) return n;
        return -n;
    }

    function getScheme(uint a) internal pure returns (uint8) {
        uint index = a % 83;
        uint8 scheme;
        if (index < 18) {
            scheme = 1;
        } else if (index < 33) {
            scheme = 2;
        } else if (index < 46) {
            scheme = 3;
        } else if (index < 57) {
            scheme = 4;
        } else if (index < 66) {
            scheme = 5;
        } else if (index < 71) {
            scheme = 6;
        } else if (index < 75) {
            scheme = 7;
        } else if (index < 78) {
            scheme = 8;
        } else if (index < 80) {
            scheme = 9;
        } else if (index < 82) {
            scheme = 10;
        } else {
            scheme = 11; // New scheme with triangle
        }
        return scheme;
    }

    /* * ** *** ***** ******** ************* ******** ***** *** ** * */

    function creator(uint _id) external view returns (address) {
        return idToCreator[_id];
    }

    function symbolScheme(uint _id) external view returns (uint8) {
        return idToSymbolScheme[_id];
    }

    function minter(uint _id) external view returns (address) {
        return idToMinter[_id];
    }

    function mintBlock(uint _id) external view returns (uint256) {
        return idToMintBlock[_id];
    }

    function createGlyph(uint seed) external returns (string memory) {
        require(!hasMinted[msg.sender], "Already minted");
        hasMinted[msg.sender] = true;
        return _mint(msg.sender, seed);
    }

    //////////////////////////
    //// ERC 721 and 165  ////
    //////////////////////////

    /**
     * @dev Returns whether the target address is a contract.
     * @param _addr Address to check.
     * @return addressCheck True if _addr is a contract, false if not.
     */
    function isContract(address _addr) internal view returns (bool addressCheck) {
        uint256 size;
        assembly { size := extcodesize(_addr) } // solhint-disable-line
        addressCheck = size > 0;
    }

    /**
     * @dev Function to check which interfaces are suported by this contract.
     * @param _interfaceID Id of the interface.
     * @return True if _interfaceID is supported, false otherwise.
     */
    function supportsInterface(bytes4 _interfaceID) external view returns (bool) {
        return supportedInterfaces[_interfaceID];
    }

    /**
     * @dev Transfers the ownership of an NFT from one address to another address. This function can
     * be changed to payable.
     * @notice Throws unless `msg.sender` is the current owner, an authorized operator, or the
     * approved address for this NFT. Throws if `_from` is not the current owner. Throws if `_to` is
     * the zero address. Throws if `_tokenId` is not a valid NFT. When transfer is complete, this
     * function checks if `_to` is a smart contract (code size > 0). If so, it calls
     * `onERC721Received` on `_to` and throws if the return value is not
     * `bytes4(keccak256("onERC721Received(address,uint256,bytes)"))`.
     * @param _from The current owner of the NFT.
     * @param _to The new owner.
     * @param _tokenId The NFT to transfer.
     * @param _data Additional data with no specified format, sent in call to `_to`.
     */
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes calldata _data) external {
        _safeTransferFrom(_from, _to, _tokenId, _data);
    }

    /**
     * @dev Transfers the ownership of an NFT from one address to another address. This function can
     * be changed to payable.
     * @notice This works identically to the other function with an extra data parameter, except this
     * function just sets data to ""
     * @param _from The current owner of the NFT.
     * @param _to The new owner.
     * @param _tokenId The NFT to transfer.
     */
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external {
        _safeTransferFrom(_from, _to, _tokenId, "");
    }

    /**
     * @dev Throws unless `msg.sender` is the current owner, an authorized operator, or the approved
     * address for this NFT. Throws if `_from` is not the current owner. Throws if `_to` is the zero
     * address. Throws if `_tokenId` is not a valid NFT. This function can be changed to payable.
     * @notice The caller is responsible to confirm that `_to` is capable of receiving NFTs or else
     * they maybe be permanently lost.
     * @param _from The current owner of the NFT.
     * @param _to The new owner.
     * @param _tokenId The NFT to transfer.
     */
    function transferFrom(address _from, address _to, uint256 _tokenId) external canTransfer(_tokenId) validNFToken(_tokenId) {
        address tokenOwner = idToOwner[_tokenId];
        require(tokenOwner == _from);
        require(_to != address(0));
        _transfer(_to, _tokenId);
    }

    /**
     * @dev Set or reaffirm the approved address for an NFT. This function can be changed to payable.
     * @notice The zero address indicates there is no approved address. Throws unless `msg.sender` is
     * the current NFT owner, or an authorized operator of the current owner.
     * @param _approved Address to be approved for the given NFT ID.
     * @param _tokenId ID of the token to be approved.
     */
    function approve(address _approved, uint256 _tokenId) external canOperate(_tokenId) validNFToken(_tokenId) {
        address tokenOwner = idToOwner[_tokenId];
        require(_approved != tokenOwner);
        idToApproval[_tokenId] = _approved;
        emit Approval(tokenOwner, _approved, _tokenId);
    }

    /**
     * @dev Enables or disables approval for a third party ("operator") to manage all of
     * `msg.sender`'s assets. It also emits the ApprovalForAll event.
     * @notice This works even if sender doesn't own any tokens at the time.
     * @param _operator Address to add to the set of authorized operators.
     * @param _approved True if the operators is approved, false to revoke approval.
     */
    function setApprovalForAll(address _operator, bool _approved) external {
        ownerToOperators[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    /**
     * @dev Returns the number of NFTs owned by `_owner`. NFTs assigned to the zero address are
     * considered invalid, and this function throws for queries about the zero address.
     * @param _owner Address for whom to query the balance.
     * @return Balance of _owner.
     */
    function balanceOf(address _owner) external view returns (uint256) {
        require(_owner != address(0));
        return _getOwnerNFTCount(_owner);
    }

    /**
     * @dev Returns the address of the owner of the NFT. NFTs assigned to zero address are considered
     * invalid, and queries about them do throw.
     * @param _tokenId The identifier for an NFT.
     * @return _owner Address of _tokenId owner.
     */
    function ownerOf(uint256 _tokenId) external view returns (address _owner) {
        _owner = idToOwner[_tokenId];
        require(_owner != address(0));
    }

    /**
     * @dev Get the approved address for a single NFT.
     * @notice Throws if `_tokenId` is not a valid NFT.
     * @param _tokenId ID of the NFT to query the approval of.
     * @return Address that _tokenId is approved for.
     */
    function getApproved(uint256 _tokenId) external view validNFToken(_tokenId) returns (address) {
        return idToApproval[_tokenId];
    }

    /**
     * @dev Checks if `_operator` is an approved operator for `_owner`.
     * @param _owner The address that owns the NFTs.
     * @param _operator The address that acts on behalf of the owner.
     * @return True if approved for all, false otherwise.
     */
    function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
        return ownerToOperators[_owner][_operator];
    }

    /**
     * @dev Actually preforms the transfer.
     * @notice Does NO checks.
     * @param _to Address of a new owner.
     * @param _tokenId The NFT that is being transferred.
     */
    function _transfer(address _to, uint256 _tokenId) internal {
        address from = idToOwner[_tokenId];
        _clearApproval(_tokenId);

        _removeNFToken(from, _tokenId);
        _addNFToken(_to, _tokenId);

        emit Transfer(from, _to, _tokenId);
    }

    /**
     * @dev Mints a new NFT.
     * @notice This is an internal function which should be called from user-implemented external
     * mint function. Its purpose is to show and properly initialize data structures when using this
     * implementation.
     * @param _to The address that will own the minted NFT.
     */
    function _mint(address _to, uint seed) internal returns (string memory) {
        require(_to != address(0));
        require(numTokens < TOKEN_LIMIT);
        require(seedToId[seed] == 0);
        
        uint id = numTokens + 1;

        idToCreator[id] = _to;
        idToSeed[id] = seed;
        seedToId[seed] = id;
        idToMinter[id] = msg.sender; // Mint eden kişiyi kaydet
        idToMintBlock[id] = block.number; // Block numarasını kaydet
        uint a = uint(uint256(keccak256(abi.encodePacked(seed))));
        idToSymbolScheme[id] = getScheme(a);
        string memory uri = draw(id);
        emit Generated(id, _to, uri);

        numTokens = numTokens + 1;
        _addNFToken(_to, id);

        emit Transfer(address(0), _to, id);
        return uri;
    }

    /**
     * @dev Assigns a new NFT to an address.
     * @notice Use and override this function with caution. Wrong usage can have serious consequences.
     * @param _to Address to which we want to add the NFT.
     * @param _tokenId Which NFT we want to add.
     */
    function _addNFToken(address _to, uint256 _tokenId) internal {
        require(idToOwner[_tokenId] == address(0));
        idToOwner[_tokenId] = _to;

        ownerToIds[_to].push(_tokenId);
        idToOwnerIndex[_tokenId] = ownerToIds[_to].length - 1;
    }

    /**
     * @dev Removes a NFT from an address.
     * @notice Use and override this function with caution. Wrong usage can have serious consequences.
     * @param _from Address from wich we want to remove the NFT.
     * @param _tokenId Which NFT we want to remove.
     */
    function _removeNFToken(address _from, uint256 _tokenId) internal {
        require(idToOwner[_tokenId] == _from);
        delete idToOwner[_tokenId];

        uint256 tokenToRemoveIndex = idToOwnerIndex[_tokenId];
        uint256 lastTokenIndex = ownerToIds[_from].length - 1;

        if (lastTokenIndex != tokenToRemoveIndex) {
            uint256 lastToken = ownerToIds[_from][lastTokenIndex];
            ownerToIds[_from][tokenToRemoveIndex] = lastToken;
            idToOwnerIndex[lastToken] = tokenToRemoveIndex;
        }

        ownerToIds[_from].pop();
    }

    /**
     * @dev Helper function that gets NFT count of owner. This is needed for overriding in enumerable
     * extension to remove double storage (gas optimization) of owner nft count.
     * @param _owner Address for whom to query the count.
     * @return Number of _owner NFTs.
     */
    function _getOwnerNFTCount(address _owner) internal view returns (uint256) {
        return ownerToIds[_owner].length;
    }

    /**
     * @dev Actually perform the safeTransferFrom.
     * @param _from The current owner of the NFT.
     * @param _to The new owner.
     * @param _tokenId The NFT to transfer.
     * @param _data Additional data with no specified format, sent in call to `_to`.
     */
    function _safeTransferFrom(address _from,  address _to,  uint256 _tokenId,  bytes memory _data) private canTransfer(_tokenId) validNFToken(_tokenId) {
        address tokenOwner = idToOwner[_tokenId];
        require(tokenOwner == _from);
        require(_to != address(0));

        _transfer(_to, _tokenId);

        if (isContract(_to)) {
            bytes4 retval = ERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data);
            require(retval == MAGIC_ON_ERC721_RECEIVED);
        }
    }

    /**
     * @dev Clears the current approval of a given NFT ID.
     * @param _tokenId ID of the NFT to be transferred.
     */
    function _clearApproval(uint256 _tokenId) private {
        if (idToApproval[_tokenId] != address(0)) {
            delete idToApproval[_tokenId];
        }
    }

    //// Enumerable

    function totalSupply() public view returns (uint256) {
        return numTokens;
    }

    function tokenByIndex(uint256 index) public view returns (uint256) {
        require(index < numTokens);
        return index + 1;
    }

    /**
     * @dev returns the n-th NFT ID from a list of owner's tokens.
     * @param _owner Token owner's address.
     * @param _index Index number representing n-th token in owner's list of tokens.
     * @return Token id.
     */
    function tokenOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256) {
        require(_index < ownerToIds[_owner].length);
        return ownerToIds[_owner][_index];
    }

    //// Metadata

    /**
      * @dev Returns a descriptive name for a collection of NFTokens.
      * @return _name Representing name.
      */
    function name() external view returns (string memory _name) {
        _name = nftName;
    }

    /**
     * @dev Returns an abbreviated name for NFTokens.
     * @return _symbol Representing symbol.
     */
    function symbol() external view returns (string memory _symbol) {
        _symbol = nftSymbol;
    }

    /**
     * @dev Returns the raw ASCII art (original Autoglyphs format)
     * @param id Id for which we want the art.
     * @return Raw ASCII art string.
     */
    function draw(uint id) public view returns (string memory) {
        uint a = uint(uint256(keccak256(abi.encodePacked(idToSeed[id]))));
        bytes memory output = new bytes(USIZE * (USIZE + 3) + 30);
        uint c;
        for (c = 0; c < 30; c++) {
            output[c] = prefix[c];
        }
        int x = 0;
        int y = 0;
        uint v = 0;
        uint value = 0;
        
        unchecked {
            uint mod = (a % 11) + 5;
            bytes5 symbols;
            if (idToSymbolScheme[id] == 0) {
                revert();
            } else if (idToSymbolScheme[id] == 1) {
                symbols = 0x2E582F5C2E; // X/\
            } else if (idToSymbolScheme[id] == 2) {
                symbols = 0x2E2B2D7C2E; // +-|
            } else if (idToSymbolScheme[id] == 3) {
                symbols = 0x2E2F5C2E2E; // /\
            } else if (idToSymbolScheme[id] == 4) {
                symbols = 0x2E5C7C2D2F; // \|-/
            } else if (idToSymbolScheme[id] == 5) {
                symbols = 0x2E4F7C2D2E; // O|-
            } else if (idToSymbolScheme[id] == 6) {
                symbols = 0x2E5C5C2E2E; // \
            } else if (idToSymbolScheme[id] == 7) {
                symbols = 0x2E237C2D2B; // #|-+
            } else if (idToSymbolScheme[id] == 8) {
                symbols = 0x2E4F4F2E2E; // OO
            } else if (idToSymbolScheme[id] == 9) {
                symbols = 0x2E232E2E2E; // #
            } else if (idToSymbolScheme[id] == 10) {
                symbols = 0x2E234F2E2E; // #O
            } else {
                symbols = 0x2E5E2E2E2E; // ^ (triangle)
            }
            
            for (int i = int(0); i < SIZE; i++) {
                y = (2 * (i - HALF_SIZE) + 1);
                if (a % 3 == 1) {
                    y = -y;
                } else if (a % 3 == 2) {
                    y = abs(y);
                }
                y = y * int(a);
                for (int j = int(0); j < SIZE; j++) {
                    x = (2 * (j - HALF_SIZE) + 1);
                    if (a % 2 == 1) {
                        x = abs(x);
                    }
                    x = x * int(a);
                    v = uint(x * y / ONE) % mod;
                    if (v < 5) {
                        value = uint(uint8(symbols[v]));
                    } else {
                        value = 0x2E;
                    }
                    output[c] = bytes1(uint8(value));
                    c++;
                }
                output[c] = bytes1(0x25);
                c++;
                output[c] = bytes1(0x30);
                c++;
                output[c] = bytes1(0x41);
                c++;
            }
        }
        
        string memory result = string(output);
        return result;
    }

    /**
     * @dev A distinct URI (RFC 3986) for a given NFT.
     * @param _tokenId Id for which we want uri.
     * @return URI of _tokenId.
     */
    function tokenURI(uint256 _tokenId) external view validNFToken(_tokenId) returns (string memory) {
        // Create beautiful geometric pattern based on seed
        string memory pattern = _createGeometricPattern(_tokenId);
        string memory svgContent = string(abi.encodePacked(
            '<svg width="320" height="320" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 320">',
            '<rect width="100%" height="100%" fill="black"/>',
            pattern,
            '<text x="160" y="305" text-anchor="middle" fill="white" font-family="monospace" font-size="8">MonadGlyph #', _toString(_tokenId), '</text>',
            '<text x="160" y="315" text-anchor="middle" fill="white" font-family="monospace" font-size="6">Scheme: ', _toString(idToSymbolScheme[_tokenId]), ' | Block: ', _toString(idToMintBlock[_tokenId]), '</text>',
            '</svg>'
        ));
        
        string memory json = string(abi.encodePacked(
            '{"name":"MonadGlyphs #', _toString(_tokenId), 
            '","description":"Algorithmic art generated on Monad blockchain, based on original Autoglyphs",',
            '"image":"data:image/svg+xml;base64,', _base64Encode(bytes(svgContent)), '",',
            '"attributes":[',
            '{"trait_type":"Symbol Scheme","value":', _toString(idToSymbolScheme[_tokenId]), '},',
            '{"trait_type":"Minter","value":"', _toHexString(idToMinter[_tokenId]), '"},',
            '{"trait_type":"Mint Block","value":', _toString(idToMintBlock[_tokenId]), '}',
            ']}'
        ));
        
        return string(abi.encodePacked('data:application/json;base64,', _base64Encode(bytes(json))));
    }

    /**
     * @dev Creates SVG from the glyph pattern
     * @param _tokenId Token ID to create SVG for
     * @return SVG string
     */
    function _createSVG(uint256 _tokenId) internal view returns (string memory) {
        uint a = uint(uint256(keccak256(abi.encodePacked(idToSeed[_tokenId]))));
        string memory cells = "";
        
        unchecked {
            uint mod = (a % 11) + 5;
            bytes5 symbols;
            if (idToSymbolScheme[_tokenId] == 0) {
                revert();
            } else if (idToSymbolScheme[_tokenId] == 1) {
                symbols = 0x2E582F5C2E; // X/\
            } else if (idToSymbolScheme[_tokenId] == 2) {
                symbols = 0x2E2B2D7C2E; // +-|
            } else if (idToSymbolScheme[_tokenId] == 3) {
                symbols = 0x2E2F5C2E2E; // /\
            } else if (idToSymbolScheme[_tokenId] == 4) {
                symbols = 0x2E5C7C2D2F; // \|-/
            } else if (idToSymbolScheme[_tokenId] == 5) {
                symbols = 0x2E4F7C2D2E; // O|-
            } else if (idToSymbolScheme[_tokenId] == 6) {
                symbols = 0x2E5C5C2E2E; // \
            } else if (idToSymbolScheme[_tokenId] == 7) {
                symbols = 0x2E237C2D2B; // #|-+
            } else if (idToSymbolScheme[_tokenId] == 8) {
                symbols = 0x2E4F4F2E2E; // OO
            } else if (idToSymbolScheme[_tokenId] == 9) {
                symbols = 0x2E232E2E2E; // #
            } else if (idToSymbolScheme[_tokenId] == 10) {
                symbols = 0x2E234F2E2E; // #O
            } else {
                symbols = 0x2E5E2E2E2E; // ^ (triangle)
            }
            
            for (int i = int(0); i < SIZE; i++) {
                int y = (2 * (i - HALF_SIZE) + 1);
                if (a % 3 == 1) {
                    y = -y;
                } else if (a % 3 == 2) {
                    y = abs(y);
                }
                y = y * int(a);
                for (int j = int(0); j < SIZE; j++) {
                    int x = (2 * (j - HALF_SIZE) + 1);
                    if (a % 2 == 1) {
                        x = abs(x);
                    }
                    x = x * int(a);
                    uint v = uint(x * y / ONE) % mod;
                    uint8 char;
                    if (v < 5) {
                        char = uint8(symbols[v]);
                    } else {
                        char = 0x2E;
                    }
                    
                    if (char != 0x2E) { // Don't draw dots
                        cells = string(abi.encodePacked(
                            cells,
                            '%3Ctext x="', _toString(uint(j) * 8), 
                            '" y="', _toString(uint(i) * 12 + 10), 
                            '" class="mono"%3E', 
                            _charToString(char),
                            '%3C/text%3E'
                        ));
                    }
                }
            }
        }
        
        return string(abi.encodePacked(
            '%3Csvg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 768" style="background:black"%3E',
            '%3Cstyle%3E.mono{font-family:monospace;font-size:10px;fill:white}%3C/style%3E',
            cells,
            '%3C/svg%3E'
        ));
    }

    function _charToString(uint8 char) internal pure returns (string memory) {
        if (char == 0x58) return "X";
        if (char == 0x2F) return "/";
        if (char == 0x5C) return "\\";
        if (char == 0x2B) return "+";
        if (char == 0x2D) return "-";
        if (char == 0x7C) return "|";
        if (char == 0x4F) return "O";
        if (char == 0x23) return "#";
        if (char == 0x5E) return "^";
        return ".";
    }

    /**
     * @dev Creates complex Autoglyphs-style algorithmic art using original math
     * @param _tokenId Token ID to create art for
     * @return SVG pattern elements with intricate mathematical beauty
     */
    function _createGeometricPattern(uint256 _tokenId) internal view returns (string memory) {
        uint a = uint(uint256(keccak256(abi.encodePacked(idToSeed[_tokenId]))));
        uint8 scheme = idToSymbolScheme[_tokenId];
        
        string memory elements = "";
        
        // Use original Autoglyphs algorithm but render as SVG primitives
        unchecked {
            uint mod = (a % 11) + 5;
            
            // Create dense, complex algorithmic art with more variety
            for (int i = int(0); i < 32; i++) {  // 32x32 for dense patterns but gas efficient
                int y = (2 * (i - 16) + 1);  // HALF_SIZE = 16 for 32x32
                if (a % 3 == 1) {
                    y = -y;
                } else if (a % 3 == 2) {
                    y = abs(y);
                }
                y = y * int(a);
                
                for (int j = int(0); j < 32; j++) {
                    int x = (2 * (j - 16) + 1);
                    if (a % 2 == 1) {
                        x = abs(x);
                    }
                    x = x * int(a);
                    
                    uint v = uint(x * y / ONE) % mod;
                    
                    if (v < 6) {  // Optimized for gas efficiency
                        // Convert position to SVG coordinates - full canvas usage
                        uint svgX = 10 + uint(j) * 9;   // 9px spacing for full 290px width usage
                        uint svgY = 10 + uint(i) * 8;
                        
                        // Render optimized symbols for gas efficiency
                        if (scheme == 1) {
                            // X pattern
                            if (v == 1) {
                                elements = string(abi.encodePacked(elements,
                                    '<path d="M', _toString(svgX), ',', _toString(svgY), ' L', _toString(svgX + 7), ',', _toString(svgY + 7), ' M', _toString(svgX + 7), ',', _toString(svgY), ' L', _toString(svgX), ',', _toString(svgY + 7), '" stroke="white" stroke-width="0.6"/>'
                                ));
                            } else if (v == 2) {
                                elements = string(abi.encodePacked(elements,
                                    '<line x1="', _toString(svgX), '" y1="', _toString(svgY), '" x2="', _toString(svgX + 7), '" y2="', _toString(svgY + 7), '" stroke="white" stroke-width="0.6"/>'
                                ));
                            }
                        } else if (scheme == 2) {
                            // Plus pattern
                            if (v == 1) {
                                elements = string(abi.encodePacked(elements,
                                    '<path d="M', _toString(svgX + 3), ',', _toString(svgY), ' L', _toString(svgX + 3), ',', _toString(svgY + 7), ' M', _toString(svgX), ',', _toString(svgY + 3), ' L', _toString(svgX + 7), ',', _toString(svgY + 3), '" stroke="white" stroke-width="0.6"/>'
                                ));
                            } else if (v == 2) {
                                elements = string(abi.encodePacked(elements,
                                    '<line x1="', _toString(svgX), '" y1="', _toString(svgY + 3), '" x2="', _toString(svgX + 7), '" y2="', _toString(svgY + 3), '" stroke="white" stroke-width="0.6"/>'
                                ));
                            }
                        } else if (scheme == 3) {
                            // Slash patterns
                            if (v == 1) {
                                elements = string(abi.encodePacked(elements,
                                    '<line x1="', _toString(svgX), '" y1="', _toString(svgY + 7), '" x2="', _toString(svgX + 7), '" y2="', _toString(svgY), '" stroke="white" stroke-width="0.6"/>'
                                ));
                            } else if (v == 2) {
                                elements = string(abi.encodePacked(elements,
                                    '<line x1="', _toString(svgX), '" y1="', _toString(svgY), '" x2="', _toString(svgX + 7), '" y2="', _toString(svgY + 7), '" stroke="white" stroke-width="0.6"/>'
                                ));
                            }
                        } else if (scheme == 5) {
                            // Circle pattern
                            if (v == 1) {
                                elements = string(abi.encodePacked(elements,
                                    '<circle cx="', _toString(svgX + 3), '" cy="', _toString(svgY + 3), '" r="2.5" fill="none" stroke="white" stroke-width="0.6"/>'
                                ));
                            }
                        } else if (scheme == 7) {
                            // Square pattern
                            if (v == 1) {
                                elements = string(abi.encodePacked(elements,
                                    '<rect x="', _toString(svgX + 1), '" y="', _toString(svgY + 1), '" width="5" height="5" fill="white"/>'
                                ));
                            }
                        } else {
                            // Simple patterns
                            if (v == 1) {
                                elements = string(abi.encodePacked(elements,
                                    '<circle cx="', _toString(svgX + 3), '" cy="', _toString(svgY + 3), '" r="1.5" fill="white"/>'
                                ));
                            } else if (v == 2) {
                                elements = string(abi.encodePacked(elements,
                                    '<rect x="', _toString(svgX + 2), '" y="', _toString(svgY + 2), '" width="3" height="3" fill="white"/>'
                                ));
                            }
                        }
                    }
                }
            }
        }
        
        return elements;
    }

    // Simple trigonometric approximations for angles
    function _cos(uint256 angle) internal pure returns (int256) {
        angle = angle % 360;
        if (angle <= 90) return int256(1000 - (angle * angle * 11) / 1000);
        else if (angle <= 180) return -int256(1000 - ((180 - angle) * (180 - angle) * 11) / 1000);
        else if (angle <= 270) return -int256(1000 - ((angle - 180) * (angle - 180) * 11) / 1000);
        else return int256(1000 - ((360 - angle) * (360 - angle) * 11) / 1000);
    }

    function _sin(uint256 angle) internal pure returns (int256) {
        return _cos((angle + 270) % 360);
    }

    /**
     * @dev Creates ASCII art using EXACT original Autoglyphs algorithm
     * @param _tokenId Token ID to create ASCII for
     * @return ASCII string with line breaks for SVG
     */
    function _getCompactASCII(uint256 _tokenId) internal view returns (string memory) {
        uint a = uint(uint256(keccak256(abi.encodePacked(idToSeed[_tokenId]))));
        string memory result = "";
        
        unchecked {
            uint mod = (a % 11) + 5;
            bytes5 symbols;
            if (idToSymbolScheme[_tokenId] == 0) {
                revert();
            } else if (idToSymbolScheme[_tokenId] == 1) {
                symbols = 0x2E582F5C2E; // X/\
            } else if (idToSymbolScheme[_tokenId] == 2) {
                symbols = 0x2E2B2D7C2E; // +-|
            } else if (idToSymbolScheme[_tokenId] == 3) {
                symbols = 0x2E2F5C2E2E; // /\
            } else if (idToSymbolScheme[_tokenId] == 4) {
                symbols = 0x2E5C7C2D2F; // \|-/
            } else if (idToSymbolScheme[_tokenId] == 5) {
                symbols = 0x2E4F7C2D2E; // O|-
            } else if (idToSymbolScheme[_tokenId] == 6) {
                symbols = 0x2E5C5C2E2E; // \
            } else if (idToSymbolScheme[_tokenId] == 7) {
                symbols = 0x2E237C2D2B; // #|-+
            } else if (idToSymbolScheme[_tokenId] == 8) {
                symbols = 0x2E4F4F2E2E; // OO
            } else if (idToSymbolScheme[_tokenId] == 9) {
                symbols = 0x2E232E2E2E; // #
            } else if (idToSymbolScheme[_tokenId] == 10) {
                symbols = 0x2E234F2E2E; // #O
            } else {
                symbols = 0x2E5E2E2E2E; // ^ (triangle)
            }
            
            // Use EXACT original Autoglyphs algorithm - 64x64 grid
            for (int i = int(0); i < SIZE; i++) {
                string memory line = "";
                int y = (2 * (i - HALF_SIZE) + 1);
                if (a % 3 == 1) {
                    y = -y;
                } else if (a % 3 == 2) {
                    y = abs(y);
                }
                y = y * int(a);
                
                for (int j = int(0); j < SIZE; j++) {
                    int x = (2 * (j - HALF_SIZE) + 1);
                    if (a % 2 == 1) {
                        x = abs(x);
                    }
                    x = x * int(a);
                    uint v = uint(x * y / ONE) % mod;
                    uint8 char;
                    if (v < 5) {
                        char = uint8(symbols[v]);
                    } else {
                        char = 0x2E;
                    }
                    line = string(abi.encodePacked(line, _charToString(char)));
                }
                
                if (i < SIZE - 1) {
                    result = string(abi.encodePacked(result, line, "&#10;"));
                } else {
                    result = string(abi.encodePacked(result, line));
                }
            }
        }
        
        return result;
    }

    /**
     * @dev Returns raw ASCII art (original Autoglyphs format)
     * @param _tokenId Id for which we want the raw art.
     * @return Raw ASCII art string.
     */
    function getRawArt(uint256 _tokenId) external view validNFToken(_tokenId) returns (string memory) {
        return draw(_tokenId);
    }

    // Helper functions for tokenURI
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        unchecked {
            while (temp != 0) {
                digits++;
                temp /= 10;
            }
        }
        bytes memory buffer = new bytes(digits);
        unchecked {
            while (value != 0) {
                digits -= 1;
                buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
                value /= 10;
            }
        }
        return string(buffer);
    }

    function _toHexString(address addr) internal pure returns (string memory) {
        bytes memory buffer = new bytes(42);
        buffer[0] = "0";
        buffer[1] = "x";
        unchecked {
            for (uint256 i = 0; i < 20; i++) {
                buffer[2 + i * 2] = _hexChar(uint8(uint160(addr) >> (4 * (19 - i))) & 0xf);
                buffer[3 + i * 2] = _hexChar(uint8(uint160(addr) >> (4 * (19 - i) - 4)) & 0xf);
            }
        }
        return string(buffer);
    }

    function _hexChar(uint8 value) internal pure returns (bytes1) {
        if (value < 10) {
            return bytes1(uint8(48 + value));
        }
        return bytes1(uint8(87 + value));
    }

    function _base64Encode(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return "";
        
        string memory table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        uint256 encodedLen = 4 * ((data.length + 2) / 3);
        string memory result = new string(encodedLen + 32);
        
        assembly {
            let tablePtr := add(table, 1)
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))
            let resultPtr := add(result, 32)
            
            for {} lt(dataPtr, endPtr) {}
            {
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)
                
                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr( 6, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(        input,  0x3F))))
                resultPtr := add(resultPtr, 1)
            }
            
            switch mod(mload(data), 3)
            case 1 { mstore(sub(resultPtr, 2), shl(240, 0x3d3d)) }
            case 2 { mstore(sub(resultPtr, 1), shl(248, 0x3d)) }
            
            mstore(result, encodedLen)
        }
        
        return result;
    }


} 