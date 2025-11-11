// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {
    ERC721Enumerable
} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {IPoolID} from "./interfaces/IPoolID.sol";
import {ILOVE20Token} from "@core/interfaces/ILOVE20Token.sol";

/**
 * @title PoolID
 * @notice ERC721-based Pool ID system for LOVE20 ecosystem
 * @dev Each Pool ID represents ownership of a mining pool in the LOVE20 ecosystem
 */
contract PoolID is ERC721Enumerable, IPoolID {
    // ============ Constants ============

    uint256 private constant BASE_DIVISOR = 1e8;
    uint256 private constant BYTES_THRESHOLD = 10;
    uint256 private constant MULTIPLIER = 10;

    // ============ State Variables ============

    address public immutable love20Token;

    uint256 private _nextTokenId = 1;

    // Mapping from token ID to pool name
    mapping(uint256 => string) private _poolNames;

    // Mapping from pool name to token ID (0 if not exists)
    mapping(string => uint256) private _poolNameToTokenId;

    // ============ Constructor ============

    constructor(address love20Token_) ERC721("LOVE20 Pool ID", "LPID") {
        if (love20Token_ == address(0)) revert InvalidAddress();
        love20Token = love20Token_;
    }

    // ============ Pool ID Functions ============

    /**
     * @notice Mint a new pool ID with the given pool name
     * @dev Requires payment in LOVE20 tokens based on name length
     * @param poolName The unique name for the pool
     * @return tokenId The newly minted token ID
     */
    function mint(string calldata poolName) external returns (uint256 tokenId) {
        // ========== Checks ==========
        uint256 mintCost = calculateMintCost(poolName);
        // ========== Effects ==========
        _mint(msg.sender, poolName, mintCost);
        return _nextTokenId - 1;
    }

    function _mint(
        address to,
        string memory poolName,
        uint256 mintCost
    ) internal {
        if (bytes(poolName).length == 0) revert PoolNameEmpty();
        if (_poolNameToTokenId[poolName] != 0) revert PoolNameAlreadyExists();

        uint256 tokenId = _nextTokenId++;
        _mint(to, tokenId);
        _poolNames[tokenId] = poolName;
        _poolNameToTokenId[poolName] = tokenId;

        if (mintCost > 0) {
            ILOVE20Token(love20Token).transferFrom(
                msg.sender,
                address(this),
                mintCost
            );
        }

        emit PoolIDMinted(tokenId, msg.sender, poolName, mintCost);
    }

    /**
     * @notice Calculate the cost to mint a pool ID with the given pool name
     * @dev Cost formula:
     *      Base cost = remaining unminted LOVE20 / 10^8
     *      For names with >= 10 bytes: cost = base cost
     *      For names with < 10 bytes: cost = base cost * (10 ^ (10 - byte_length))
     * @param poolName The pool name to calculate cost for
     * @return The cost in LOVE20 tokens
     */
    function calculateMintCost(
        string calldata poolName
    ) public view returns (uint256) {
        ILOVE20Token token = ILOVE20Token(love20Token);

        // Get the unminted supply (maxSupply - totalSupply)
        uint256 unmintedSupply = token.maxSupply() - token.totalSupply();

        // Base cost = unminted supply / 10^8
        uint256 baseCost = unmintedSupply / BASE_DIVISOR;

        // Get byte length of pool name
        uint256 byteLength = bytes(poolName).length;

        // If byte length >= 10, return base cost
        if (byteLength >= BYTES_THRESHOLD) {
            return baseCost;
        }

        // Otherwise, multiply by 10^(10 - byteLength)
        uint256 multiplier = 1;
        uint256 difference = BYTES_THRESHOLD - byteLength;

        for (uint256 i = 0; i < difference; i++) {
            multiplier *= MULTIPLIER;
        }

        return baseCost * multiplier;
    }

    /**
     * @notice Get the pool name for a token ID
     * @param tokenId The token ID to query
     * @return The pool name associated with the token ID
     */
    function poolNameOf(uint256 tokenId) external view returns (string memory) {
        _requireMinted(tokenId);
        return _poolNames[tokenId];
    }

    /**
     * @notice Check if a pool name is already used
     * @param poolName The pool name to check
     * @return True if the pool name is already used
     */
    function isPoolNameUsed(
        string calldata poolName
    ) external view returns (bool) {
        return _poolNameToTokenId[poolName] != 0;
    }

    /**
     * @notice Get token ID by pool name
     * @param poolName The pool name to query
     * @return The token ID associated with the pool name (0 if not exists)
     */
    function tokenIdOf(
        string calldata poolName
    ) external view returns (uint256) {
        return _poolNameToTokenId[poolName];
    }
}
