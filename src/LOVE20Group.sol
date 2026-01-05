// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {
    ERC721Enumerable
} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ILOVE20Group} from "./interfaces/ILOVE20Group.sol";
import {ILOVE20Token} from "./interfaces/ILOVE20Token.sol";

/**
 * @title LOVE20Group
 * @notice ERC721-based Group system for LOVE20 ecosystem
 * @dev Each Group represents ownership of a group in the LOVE20 ecosystem
 */
contract LOVE20Group is ERC721Enumerable, ILOVE20Group {
    // ============ Immutable Parameters ============

    address public immutable LOVE20_TOKEN_ADDRESS;
    uint256 public immutable BASE_DIVISOR;
    uint256 public immutable BYTES_THRESHOLD;
    uint256 public immutable MULTIPLIER;
    uint256 public immutable MAX_GROUP_NAME_LENGTH;

    // ============ State Variables ============

    uint256 internal _nextTokenId = 1;

    uint256 public totalMintCost;

    // tokenId => groupName
    mapping(uint256 => string) internal _groupNames;

    // normalizedName => tokenId
    mapping(string => uint256) internal _normalizedNameToTokenId;

    // all holder addresses
    address[] internal _allHolders;

    // holderAddress => whether the holder exists in the array
    mapping(address => bool) internal _isHolder;

    // holderAddress => index in _allHolders array (0-based, only valid when _isHolder is true)
    mapping(address => uint256) internal _holderIndex;

    // ============ Constructor ============

    /**
     * @param love20Token_ Address of the LOVE20 token
     * @param baseDivisor_ Base divisor for cost calculation (e.g., 1e8)
     * @param bytesThreshold_ Byte length threshold for cost multiplier (e.g., 8)
     * @param multiplier_ Multiplier for short names (e.g., 10)
     * @param maxGroupNameLength_ Maximum group name length in bytes (e.g., 64)
     */
    constructor(
        address love20Token_,
        uint256 baseDivisor_,
        uint256 bytesThreshold_,
        uint256 multiplier_,
        uint256 maxGroupNameLength_
    ) ERC721("LOVE20 Group", "Group") {
        LOVE20_TOKEN_ADDRESS = love20Token_;
        BASE_DIVISOR = baseDivisor_;
        BYTES_THRESHOLD = bytesThreshold_;
        MULTIPLIER = multiplier_;
        MAX_GROUP_NAME_LENGTH = maxGroupNameLength_;
    }

    // ============ Group Functions ============

    /**
     * @notice Mint a new group with the given group name
     * @dev Requires payment in LOVE20 tokens based on name length.
     *      Uses safeMint to ensure recipient can receive ERC721.
     * @param groupName The unique name for the group
     * @return tokenId The newly minted token ID
     */
    function mint(
        string calldata groupName
    ) external returns (uint256 tokenId, uint256 mintCost) {
        mintCost = calculateMintCost(groupName);
        tokenId = _mintGroup(msg.sender, groupName, mintCost);
        return (tokenId, mintCost);
    }

    function _mintGroup(
        address to,
        string memory groupName,
        uint256 mintCost
    ) internal returns (uint256 tokenId) {
        if (bytes(groupName).length == 0) revert GroupNameEmpty();
        if (!_isValidGroupName(groupName)) revert InvalidGroupName();

        // Use normalized (lowercase) name for uniqueness check
        string memory normalizedName = _toLowerCase(groupName);
        if (_normalizedNameToTokenId[normalizedName] != 0) {
            revert GroupNameAlreadyExists();
        }

        tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _groupNames[tokenId] = groupName;
        _normalizedNameToTokenId[normalizedName] = tokenId;

        if (mintCost > 0) {
            totalMintCost += mintCost;

            ILOVE20Token token = ILOVE20Token(LOVE20_TOKEN_ADDRESS);
            token.transferFrom(msg.sender, address(this), mintCost);
            token.burn(mintCost);
        }

        emit Mint({
            tokenId: tokenId,
            owner: msg.sender,
            groupName: groupName,
            normalizedName: normalizedName,
            cost: mintCost
        });

        return tokenId;
    }

    /**
     * @notice Calculate the cost to mint a group with the given group name
     * @dev Cost formula:
     *      Base cost = remaining unminted LOVE20 / 10^8
     *      For names with >= 8 bytes: cost = base cost
     *      For names with < 8 bytes: cost = base cost * (10 ^ (8 - byte_length))
     * @param groupName The group name to calculate cost for
     * @return The cost in LOVE20 tokens
     */
    function calculateMintCost(
        string calldata groupName
    ) public view returns (uint256) {
        ILOVE20Token token = ILOVE20Token(LOVE20_TOKEN_ADDRESS);

        uint256 unmintedSupply = token.maxSupply() - token.totalSupply();

        uint256 baseCost = unmintedSupply / BASE_DIVISOR;

        uint256 byteLength = bytes(groupName).length;

        if (byteLength >= BYTES_THRESHOLD) {
            return baseCost;
        }

        uint256 difference = BYTES_THRESHOLD - byteLength;

        return baseCost * (MULTIPLIER ** difference);
    }

    /**
     * @notice Get the group name for a token ID
     * @param tokenId The token ID to query
     * @return The group name associated with the token ID (empty string if token doesn't exist)
     */
    function groupNameOf(
        uint256 tokenId
    ) external view returns (string memory) {
        return _groupNames[tokenId];
    }

    /**
     * @notice Check if a group name is already used (case-insensitive)
     * @param groupName The group name to check
     * @return True if the group name is already used
     */
    function isGroupNameUsed(
        string calldata groupName
    ) external view returns (bool) {
        return _normalizedNameToTokenId[_toLowerCase(groupName)] != 0;
    }

    /**
     * @notice Get token ID by group name (case-insensitive)
     * @param groupName The group name to query
     * @return The token ID associated with the group name (0 if not exists)
     */
    function tokenIdOf(
        string calldata groupName
    ) external view returns (uint256) {
        return _normalizedNameToTokenId[_toLowerCase(groupName)];
    }

    /**
     * @notice Get the normalized (lowercase) version of a group name
     * @param groupName The group name to normalize
     * @return The normalized group name with ASCII uppercase converted to lowercase
     */
    function normalizedNameOf(
        string calldata groupName
    ) external pure returns (string memory) {
        return _toLowerCase(groupName);
    }

    /**
     * @notice Get the total number of unique holders
     * @return The number of unique addresses that currently hold NFTs
     */
    function holdersCount() external view returns (uint256) {
        return _allHolders.length;
    }

    /**
     * @notice Get the holder address at the given index
     * @param index The index in the holders array (0-based)
     * @return The holder address at the given index
     */
    function holdersAtIndex(uint256 index) external view returns (address) {
        if (index >= _allHolders.length) {
            revert HolderIndexOutOfBounds();
        }
        return _allHolders[index];
    }

    // ============ Internal Functions ============

    /**
     * @dev Add a holder to the holders array if not already present
     * @param holder The address to add
     */
    function _addHolder(address holder) internal {
        if (!_isHolder[holder] && holder != address(0)) {
            uint256 index = _allHolders.length;
            _allHolders.push(holder);
            _holderIndex[holder] = index; // 0-based index
            _isHolder[holder] = true;
        }
    }

    /**
     * @dev Remove a holder from the holders array using swap-and-pop
     * @param holder The address to remove
     */
    function _removeHolder(address holder) internal {
        if (!_isHolder[holder]) return; // Not in array

        uint256 index = _holderIndex[holder];
        uint256 lastIndex = _allHolders.length - 1;

        if (index != lastIndex) {
            address lastHolder = _allHolders[lastIndex];
            _allHolders[index] = lastHolder;
            _holderIndex[lastHolder] = index;
        }
        _allHolders.pop();
        _isHolder[holder] = false;
    }

    /**
     * @dev Hook that is called before any token transfer
     * @param from Address transferring the token (address(0) for mint)
     * @param to Address receiving the token (address(0) for burn)
     * @param firstTokenId The token ID being transferred
     * @param batchSize The number of tokens being transferred (always 1 for this contract)
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override {
        uint256 fromBalanceBefore = from != address(0) ? balanceOf(from) : 0;
        uint256 toBalanceBefore = to != address(0) ? balanceOf(to) : 0;

        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);

        if (from == address(0)) {
            // Mint
            if (toBalanceBefore == 0 && to != address(0)) {
                _addHolder(to);
            }
        } else if (to == address(0)) {
            // Burn
            if (fromBalanceBefore == 1) {
                _removeHolder(from);
            }
        } else {
            // Transfer
            if (fromBalanceBefore == 1) {
                _removeHolder(from);
            }
            if (toBalanceBefore == 0) {
                _addHolder(to);
            }
        }
    }

    /**
     * @dev Validate group name characters and format
     * @param groupName The group name to validate
     * @return bool True if the group name is valid
     *
     * Validation rules:
     * - Length must be between 1 and 64 bytes (UTF-8 encoded)
     * - Must be valid UTF-8 encoding
     * - No ASCII whitespace (0x20) or control characters (0x00-0x1F, 0x7F)
     * - No Unicode whitespace characters (U+00A0, U+1680, U+2000-U+200A, U+202F, U+205F, U+3000)
     * - No zero-width characters (U+200B-U+200F, U+034F, U+FEFF, U+2060, U+00AD)
     * - No line/paragraph separators (U+2028, U+2029)
     * - No directional formatting (U+061C, U+202A-U+202E)
     * - Supports UTF-8 encoded characters including Unicode
     *
     * Note: We check byte length, not character count. A single Unicode
     * character may use multiple bytes in UTF-8 encoding.
     */
    function _isValidGroupName(
        string memory groupName
    ) internal view returns (bool) {
        bytes memory nameBytes = bytes(groupName);
        uint256 len = nameBytes.length;

        // Check length bounds (byte length, not character count)
        if (len == 0 || len > MAX_GROUP_NAME_LENGTH) {
            return false;
        }

        // Validate UTF-8 encoding and check for invalid characters
        uint256 i = 0;
        while (i < len) {
            uint8 byteValue = uint8(nameBytes[i]);

            // Reject C0 control characters (0x00-0x1F) and space (0x20)
            if (byteValue <= 0x20) {
                return false;
            }

            // Reject DEL character (0x7F)
            if (byteValue == 0x7F) {
                return false;
            }

            // ASCII range (0x21-0x7E): valid single-byte character
            if (byteValue < 0x80) {
                i++;
                continue;
            }

            // Multi-byte UTF-8 sequence validation
            uint8 numBytes = 0;

            // Determine expected sequence length based on first byte
            if (byteValue >= 0xC2 && byteValue <= 0xDF) {
                // 2-byte sequence: 110xxxxx 10xxxxxx
                numBytes = 2;
            } else if (byteValue >= 0xE0 && byteValue <= 0xEF) {
                // 3-byte sequence: 1110xxxx 10xxxxxx 10xxxxxx
                numBytes = 3;
            } else if (byteValue >= 0xF0 && byteValue <= 0xF4) {
                // 4-byte sequence: 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
                numBytes = 4;
            } else {
                // Invalid UTF-8 start byte (0x80-0xC1, 0xF5-0xFF)
                return false;
            }

            // Check if there are enough remaining bytes
            if (i + numBytes > len) {
                return false;
            }

            // Validate continuation bytes and check for forbidden sequences
            for (uint256 j = 1; j < numBytes; j++) {
                uint8 contByte = uint8(nameBytes[i + j]);

                // All continuation bytes must be in range 0x80-0xBF
                if (contByte < 0x80 || contByte > 0xBF) {
                    return false;
                }
            }

            // Now check for forbidden Unicode characters
            if (numBytes == 2) {
                uint8 byte1 = uint8(nameBytes[i]);
                uint8 byte2 = uint8(nameBytes[i + 1]);

                // Check for U+00A0 (No-Break Space)
                // UTF-8: 0xC2 0xA0
                if (byte1 == 0xC2 && byte2 == 0xA0) {
                    return false;
                }

                // Check for U+00AD (Soft Hyphen)
                // UTF-8: 0xC2 0xAD
                if (byte1 == 0xC2 && byte2 == 0xAD) {
                    return false;
                }

                // Check for C1 control characters (0x80-0x9F)
                // UTF-8: 0xC2 0x80-0x9F
                if (byte1 == 0xC2 && byte2 >= 0x80 && byte2 <= 0x9F) {
                    return false;
                }

                // Check for U+034F (Combining Grapheme Joiner)
                // UTF-8: 0xCD 0x8F
                if (byte1 == 0xCD && byte2 == 0x8F) {
                    return false;
                }

                // Check for U+061C (Arabic Letter Mark)
                // UTF-8: 0xD8 0x9C
                if (byte1 == 0xD8 && byte2 == 0x9C) {
                    return false;
                }
            }

            if (numBytes == 3) {
                uint8 byte1 = uint8(nameBytes[i]);
                uint8 byte2 = uint8(nameBytes[i + 1]);
                uint8 byte3 = uint8(nameBytes[i + 2]);

                // Check for U+1680 (Ogham Space Mark)
                // UTF-8: 0xE1 0x9A 0x80
                if (byte1 == 0xE1 && byte2 == 0x9A && byte3 == 0x80) {
                    return false;
                }

                // Check for U+2000 to U+200F (Various spaces, zero-width chars, LRM, RLM)
                // UTF-8: 0xE2 0x80 0x80-0x8F
                if (
                    byte1 == 0xE2 &&
                    byte2 == 0x80 &&
                    byte3 >= 0x80 &&
                    byte3 <= 0x8F
                ) {
                    return false;
                }

                // Check for U+2028 (Line Separator)
                // UTF-8: 0xE2 0x80 0xA8
                if (byte1 == 0xE2 && byte2 == 0x80 && byte3 == 0xA8) {
                    return false;
                }

                // Check for U+2029 (Paragraph Separator)
                // UTF-8: 0xE2 0x80 0xA9
                if (byte1 == 0xE2 && byte2 == 0x80 && byte3 == 0xA9) {
                    return false;
                }

                // Check for U+202A-U+202E (Directional formatting characters)
                // UTF-8: 0xE2 0x80 0xAA-0xAE
                if (
                    byte1 == 0xE2 &&
                    byte2 == 0x80 &&
                    byte3 >= 0xAA &&
                    byte3 <= 0xAE
                ) {
                    return false;
                }

                // Check for U+202F (Narrow No-Break Space)
                // UTF-8: 0xE2 0x80 0xAF
                if (byte1 == 0xE2 && byte2 == 0x80 && byte3 == 0xAF) {
                    return false;
                }

                // Check for U+205F (Medium Mathematical Space)
                // UTF-8: 0xE2 0x81 0x9F
                if (byte1 == 0xE2 && byte2 == 0x81 && byte3 == 0x9F) {
                    return false;
                }

                // Check for U+2060 (Word Joiner)
                // UTF-8: 0xE2 0x81 0xA0
                if (byte1 == 0xE2 && byte2 == 0x81 && byte3 == 0xA0) {
                    return false;
                }

                // Check for U+3000 (Ideographic Space - CJK full-width space)
                // UTF-8: 0xE3 0x80 0x80
                if (byte1 == 0xE3 && byte2 == 0x80 && byte3 == 0x80) {
                    return false;
                }

                // Check for U+FEFF (Zero Width No-Break Space / BOM)
                // UTF-8: 0xEF 0xBB 0xBF
                if (byte1 == 0xEF && byte2 == 0xBB && byte3 == 0xBF) {
                    return false;
                }

                // Additional validation for 3-byte sequences
                // Reject overlong encodings and invalid ranges
                if (byte1 == 0xE0 && byte2 < 0xA0) {
                    // Overlong encoding
                    return false;
                }
                if (byte1 == 0xED && byte2 >= 0xA0) {
                    // UTF-16 surrogates (U+D800 to U+DFFF are invalid in UTF-8)
                    return false;
                }
            }

            if (numBytes == 4) {
                uint8 byte1 = uint8(nameBytes[i]);
                uint8 byte2 = uint8(nameBytes[i + 1]);

                // Additional validation for 4-byte sequences
                // Reject overlong encodings and code points > U+10FFFF
                if (byte1 == 0xF0 && byte2 < 0x90) {
                    // Overlong encoding
                    return false;
                }
                if (byte1 == 0xF4 && byte2 >= 0x90) {
                    // Code point > U+10FFFF
                    return false;
                }
            }

            // Move to next character
            i += numBytes;
        }

        return true;
    }

    /**
     * @dev Convert ASCII uppercase letters (A-Z) to lowercase (a-z)
     * @param str The string to convert
     * @return A new string with uppercase letters converted to lowercase
     */
    function _toLowerCase(
        string memory str
    ) internal pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory result = new bytes(bStr.length);
        for (uint256 i = 0; i < bStr.length; i++) {
            // ASCII A-Z: 0x41-0x5A -> a-z: 0x61-0x7A
            if (bStr[i] >= 0x41 && bStr[i] <= 0x5A) {
                result[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                result[i] = bStr[i];
            }
        }
        return string(result);
    }
}
