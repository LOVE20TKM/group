// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {
    IERC721Enumerable
} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {
    IERC721Metadata
} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

interface ILOVE20GroupEvents {
    event GroupMint(
        uint256 indexed tokenId,
        address indexed owner,
        string groupName,
        uint256 mintCost
    );
}

interface ILOVE20GroupErrors {
    error InvalidTokenAddress();
    error InvalidParameter();
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
    function mint(string calldata groupName) external returns (uint256 tokenId);

    function calculateMintCost(
        string calldata groupName
    ) external view returns (uint256);

    function groupNameOf(uint256 tokenId) external view returns (string memory);

    function isGroupNameUsed(
        string calldata groupName
    ) external view returns (bool);

    function tokenIdOf(
        string calldata groupName
    ) external view returns (uint256);

    function normalizedNameOf(
        string calldata groupName
    ) external pure returns (string memory);

    function totalMintCost() external view returns (uint256);

    function love20Token() external view returns (address);
}
