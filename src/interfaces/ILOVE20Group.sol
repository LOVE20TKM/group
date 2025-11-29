// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {
    IERC721Enumerable
} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {
    IERC721Metadata
} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

interface ILOVE20GroupEvents {
    // Emitted when a new group is minted
    event GroupMinted(
        uint256 indexed tokenId,
        address indexed owner,
        string groupName,
        uint256 mintCost
    );
}

interface ILOVE20GroupErrors {
    error InvalidAddress();
    error GroupNameAlreadyExists();
    error GroupNameEmpty();
    error InvalidGroupName();
}

interface ILOVE20Group is
    IERC721Metadata,
    IERC721Enumerable,
    ILOVE20GroupEvents,
    ILOVE20GroupErrors
{
    // Mint a new group with the given group name
    function mint(string calldata groupName) external returns (uint256 tokenId);

    // Calculate the cost to mint a group with the given group name
    function calculateMintCost(
        string calldata groupName
    ) external view returns (uint256);

    // Get the group name for a token ID
    function groupNameOf(uint256 tokenId) external view returns (string memory);

    // Check if a group name is already used (case-insensitive)
    function isGroupNameUsed(
        string calldata groupName
    ) external view returns (bool);

    // Get token ID by group name (case-insensitive)
    function tokenIdOf(
        string calldata groupName
    ) external view returns (uint256);

    // Get the normalized (lowercase) version of a group name
    function normalizedNameOf(
        string calldata groupName
    ) external pure returns (string memory);

    // Get the LOVE20 token address
    function love20Token() external view returns (address);
}
