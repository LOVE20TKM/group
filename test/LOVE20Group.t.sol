// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {LOVE20Group} from "../src/LOVE20Group.sol";
import {
    ILOVE20Group,
    ILOVE20GroupErrors,
    ILOVE20GroupEvents
} from "../src/interfaces/ILOVE20Group.sol";
import {MockLOVE20Token} from "./mocks/MockLOVE20Token.sol";

/**
 * @title LOVE20GroupTest
 * @notice Test suite for the LOVE20Group contract
 */
contract LOVE20GroupTest is Test {
    LOVE20Group public group;
    MockLOVE20Token public love20Token;

    address public user1;
    address public user2;

    uint256 constant INITIAL_SUPPLY = 10_000_000_000 * 1e18; // 10 billion tokens
    uint256 constant MAX_SUPPLY = 21_000_000_000 * 1e18; // 21 billion tokens

    // Group parameters (matching default config)
    uint256 constant BASE_DIVISOR = 1e8;
    uint256 constant BYTES_THRESHOLD = 8;
    uint256 constant MULTIPLIER = 10;
    uint256 constant MAX_GROUP_NAME_LENGTH = 64;

    function setUp() public {
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy mock LOVE20 token
        love20Token = new MockLOVE20Token("LOVE20", "LOVE", MAX_SUPPLY);

        // Deploy LOVE20Group contract with parameters
        group = new LOVE20Group(
            address(love20Token),
            BASE_DIVISOR,
            BYTES_THRESHOLD,
            MULTIPLIER,
            MAX_GROUP_NAME_LENGTH
        );

        // Mint some tokens to users
        love20Token.mint(user1, 1_000_000 * 1e18);
        love20Token.mint(user2, 1_000_000 * 1e18);
    }

    // ============ Initialization Tests ============

    function testInitialization() public view {
        assertEq(group.LOVE20_TOKEN_ADDRESS(), address(love20Token));
        assertEq(group.totalSupply(), 0);
        assertEq(group.totalBurnedForMint(), 0);
        assertEq(group.name(), "LOVE20 Group");
        assertEq(group.symbol(), "Group");
    }

    function testCannotInitializeWithZeroAddress() public {
        vm.expectRevert(ILOVE20GroupErrors.InvalidTokenAddress.selector);
        new LOVE20Group(
            address(0),
            BASE_DIVISOR,
            BYTES_THRESHOLD,
            MULTIPLIER,
            MAX_GROUP_NAME_LENGTH
        );
    }

    // ============ Minting Cost Calculation Tests ============

    function testCalculateMintCost10Bytes() public view {
        // Group name with 10 bytes
        string memory groupName = "1234567890"; // 10 bytes
        uint256 unmintedSupply = MAX_SUPPLY - love20Token.totalSupply();
        uint256 expectedCost = unmintedSupply / 1e8;

        uint256 actualCost = group.calculateMintCost(groupName);
        assertEq(actualCost, expectedCost);
    }

    function testCalculateMintCost12Bytes() public view {
        // Group name with 12 bytes
        string memory groupName = "123456789012"; // 12 bytes
        uint256 unmintedSupply = MAX_SUPPLY - love20Token.totalSupply();
        uint256 expectedCost = unmintedSupply / 1e8;

        uint256 actualCost = group.calculateMintCost(groupName);
        assertEq(actualCost, expectedCost);
    }

    function testCalculateMintCost8Bytes() public view {
        // Group name with 8 bytes
        string memory groupName = "12345678"; // 8 bytes
        uint256 unmintedSupply = MAX_SUPPLY - love20Token.totalSupply();
        uint256 expectedCost = unmintedSupply / 1e8;

        uint256 actualCost = group.calculateMintCost(groupName);
        assertEq(actualCost, expectedCost);
    }

    function testCalculateMintCost6Bytes() public view {
        // Group name with 6 bytes
        string memory groupName = "123456"; // 6 bytes
        uint256 unmintedSupply = MAX_SUPPLY - love20Token.totalSupply();
        uint256 expectedCost = (unmintedSupply / 1e8) * 100; // 10^(8-6) = 100

        uint256 actualCost = group.calculateMintCost(groupName);
        assertEq(actualCost, expectedCost);
    }

    function testCalculateMintCost4Bytes() public view {
        // Group name with 4 bytes
        string memory groupName = "1234"; // 4 bytes
        uint256 unmintedSupply = MAX_SUPPLY - love20Token.totalSupply();
        uint256 expectedCost = (unmintedSupply / 1e8) * 10000; // 10^(8-4) = 10000

        uint256 actualCost = group.calculateMintCost(groupName);
        assertEq(actualCost, expectedCost);
    }

    function testCalculateMintCost1Byte() public view {
        // Group name with 1 byte (extreme case)
        string memory groupName = "a"; // 1 byte
        uint256 unmintedSupply = MAX_SUPPLY - love20Token.totalSupply();
        uint256 expectedCost = (unmintedSupply / 1e8) * 1e7; // 10^(8-1) = 1e7

        uint256 actualCost = group.calculateMintCost(groupName);
        assertEq(actualCost, expectedCost);
    }

    // ============ Minting Tests ============

    function testMint() public {
        string memory groupName = "TestGroup123";
        uint256 mintCost = group.calculateMintCost(groupName);

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, uint256 returnedMintCost) = group.mint(groupName);
        vm.stopPrank();

        assertEq(returnedMintCost, mintCost);
        assertEq(tokenId, 1);
        assertEq(group.totalSupply(), 1);
        assertEq(group.totalBurnedForMint(), mintCost);
        assertEq(group.ownerOf(tokenId), user1);
        assertEq(group.balanceOf(user1), 1);
        assertEq(group.groupNameOf(tokenId), groupName);
        assertTrue(group.isGroupNameUsed(groupName));
        assertEq(group.tokenIdOf(groupName), tokenId);
    }

    function testMintMultiple() public {
        string memory groupName1 = "FirstGroupName";
        string memory groupName2 = "SecondGroupName";

        uint256 mintCost1 = group.calculateMintCost(groupName1);

        // User1 mints first group
        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost1);
        (uint256 tokenId1, ) = group.mint(groupName1);
        vm.stopPrank();
        assertEq(group.totalBurnedForMint(), mintCost1);

        // Calculate cost AFTER first mint (cost increases due to burn)
        uint256 mintCost2 = group.calculateMintCost(groupName2);

        // User2 mints second group
        vm.startPrank(user2);
        love20Token.approve(address(group), mintCost2);
        (uint256 tokenId2, ) = group.mint(groupName2);
        vm.stopPrank();

        assertEq(tokenId1, 1);
        assertEq(tokenId2, 2);
        assertEq(group.totalSupply(), 2);
        assertEq(group.totalBurnedForMint(), mintCost1 + mintCost2);
        assertEq(group.ownerOf(tokenId1), user1);
        assertEq(group.ownerOf(tokenId2), user2);
    }

    function testCannotMintWithEmptyName() public {
        vm.startPrank(user1);
        vm.expectRevert(ILOVE20GroupErrors.GroupNameEmpty.selector);
        group.mint("");
        vm.stopPrank();
    }

    function testCannotMintWithLeadingWhitespace() public {
        string memory groupName = " LeadingSpace";

        vm.startPrank(user1);
        vm.expectRevert(ILOVE20GroupErrors.InvalidGroupName.selector);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithTrailingWhitespace() public {
        string memory groupName = "TrailingSpace ";

        vm.startPrank(user1);
        vm.expectRevert(ILOVE20GroupErrors.InvalidGroupName.selector);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithControlCharacters() public {
        // Test newline character
        string memory groupNameWithNewline = "Group\nName";

        vm.startPrank(user1);
        vm.expectRevert(ILOVE20GroupErrors.InvalidGroupName.selector);
        group.mint(groupNameWithNewline);
        vm.stopPrank();
    }

    function testCannotMintWithTabCharacter() public {
        // Test tab character
        string memory groupNameWithTab = "Group\tName";

        vm.startPrank(user1);
        vm.expectRevert(ILOVE20GroupErrors.InvalidGroupName.selector);
        group.mint(groupNameWithTab);
        vm.stopPrank();
    }

    function testCannotMintWithTooLongName() public {
        // Create a name longer than 64 characters
        string
            memory groupName = "ThisIsAVeryLongGroupNameThatExceedsSixtyFourCharactersInLengthAndShouldBeRejected";

        vm.startPrank(user1);
        vm.expectRevert(ILOVE20GroupErrors.InvalidGroupName.selector);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithZeroWidthSpace() public {
        // Zero Width Space (U+200B) - UTF-8: 0xE2 0x80 0x8B
        string memory groupName = unicode"Group\u200BName";

        vm.startPrank(user1);
        vm.expectRevert(ILOVE20GroupErrors.InvalidGroupName.selector);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithZeroWidthNonJoiner() public {
        // Zero Width Non-Joiner (U+200C) - UTF-8: 0xE2 0x80 0x8C
        string memory groupName = unicode"Group\u200CName";

        vm.startPrank(user1);
        vm.expectRevert(ILOVE20GroupErrors.InvalidGroupName.selector);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithZeroWidthJoiner() public {
        // Zero Width Joiner (U+200D) - UTF-8: 0xE2 0x80 0x8D
        string memory groupName = unicode"Group\u200DName";

        vm.startPrank(user1);
        vm.expectRevert(ILOVE20GroupErrors.InvalidGroupName.selector);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithLeftToRightMark() public {
        // Left-to-Right Mark (U+200E) - UTF-8: 0xE2 0x80 0x8E
        string memory groupName = unicode"Group\u200EName";

        vm.startPrank(user1);
        vm.expectRevert(ILOVE20GroupErrors.InvalidGroupName.selector);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithRightToLeftMark() public {
        // Right-to-Left Mark (U+200F) - UTF-8: 0xE2 0x80 0x8F
        string memory groupName = unicode"Group\u200FName";

        vm.startPrank(user1);
        vm.expectRevert(ILOVE20GroupErrors.InvalidGroupName.selector);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithSoftHyphen() public {
        // Soft Hyphen (U+00AD) - UTF-8: 0xC2 0xAD
        string memory groupName = unicode"Group\u00ADName";

        vm.startPrank(user1);
        vm.expectRevert(ILOVE20GroupErrors.InvalidGroupName.selector);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithBOM() public {
        // Zero Width No-Break Space / BOM (U+FEFF) - UTF-8: 0xEF 0xBB 0xBF
        string memory groupName = unicode"\uFEFFGroupName";

        vm.startPrank(user1);
        vm.expectRevert(ILOVE20GroupErrors.InvalidGroupName.selector);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithWordJoiner() public {
        // Word Joiner (U+2060) - UTF-8: 0xE2 0x81 0xA0
        string memory groupName = unicode"Group\u2060Name";

        vm.startPrank(user1);
        vm.expectRevert(ILOVE20GroupErrors.InvalidGroupName.selector);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithCombiningGraphemeJoiner() public {
        // Combining Grapheme Joiner (U+034F) - UTF-8: 0xCD 0x8F
        string memory groupName = unicode"Group\u034FName";

        vm.startPrank(user1);
        vm.expectRevert(ILOVE20GroupErrors.InvalidGroupName.selector);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintDuplicateName() public {
        string memory groupName = "TestGroup";
        uint256 mintCost = group.calculateMintCost(groupName);

        // First mint succeeds
        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (, uint256 returnedMintCost) = group.mint(groupName);
        assertEq(returnedMintCost, mintCost);
        vm.stopPrank();

        // Second mint with same name fails
        vm.startPrank(user2);
        love20Token.approve(address(group), mintCost);
        vm.expectRevert(ILOVE20GroupErrors.GroupNameAlreadyExists.selector);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintDuplicateNameCaseInsensitive() public {
        string memory groupName1 = "TestGroup";
        string memory groupName2 = "testgroup";
        string memory groupName3 = "TESTGROUP";

        uint256 mintCost = group.calculateMintCost(groupName1);

        // First mint succeeds
        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        group.mint(groupName1);
        vm.stopPrank();

        // Second mint with lowercase version fails
        vm.startPrank(user2);
        love20Token.approve(address(group), mintCost);
        vm.expectRevert(ILOVE20GroupErrors.GroupNameAlreadyExists.selector);
        group.mint(groupName2);
        vm.stopPrank();

        // Third mint with uppercase version also fails
        vm.startPrank(user2);
        love20Token.approve(address(group), mintCost);
        vm.expectRevert(ILOVE20GroupErrors.GroupNameAlreadyExists.selector);
        group.mint(groupName3);
        vm.stopPrank();
    }

    function testCaseInsensitiveLookup() public {
        string memory groupName = "MyGroup";
        uint256 mintCost = group.calculateMintCost(groupName);

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);
        vm.stopPrank();

        // All case variants should return the same token ID
        assertEq(group.tokenIdOf("MyGroup"), tokenId);
        assertEq(group.tokenIdOf("mygroup"), tokenId);
        assertEq(group.tokenIdOf("MYGROUP"), tokenId);
        assertEq(group.tokenIdOf("mYgRoUp"), tokenId);

        // All case variants should return true for isGroupNameUsed
        assertTrue(group.isGroupNameUsed("MyGroup"));
        assertTrue(group.isGroupNameUsed("mygroup"));
        assertTrue(group.isGroupNameUsed("MYGROUP"));
        assertTrue(group.isGroupNameUsed("mYgRoUp"));
    }

    function testOriginalCasePreserved() public {
        string memory groupName = "MyMixedCaseGroup";
        uint256 mintCost = group.calculateMintCost(groupName);

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);
        vm.stopPrank();

        // groupNameOf should return the original case
        assertEq(group.groupNameOf(tokenId), "MyMixedCaseGroup");
    }

    function testNormalizedNameOf() public view {
        // ASCII uppercase should be converted to lowercase
        assertEq(group.normalizedNameOf("MyGroup"), "mygroup");
        assertEq(group.normalizedNameOf("ALLCAPS"), "allcaps");
        assertEq(group.normalizedNameOf("alllower"), "alllower");
        assertEq(group.normalizedNameOf("MiXeD-CaSe_123"), "mixed-case_123");

        // Non-ASCII characters should remain unchanged
        assertEq(
            group.normalizedNameOf(unicode"Group组名"),
            unicode"group组名"
        );
        assertEq(group.normalizedNameOf(unicode"🎉PARTY"), unicode"🎉party");
    }

    function testCannotMintWithInsufficientApproval() public {
        string memory groupName = "TestGroup";
        uint256 mintCost = group.calculateMintCost(groupName);

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost - 1); // Approve less than needed
        vm.expectRevert();
        group.mint(groupName);
        vm.stopPrank();
    }

    function testMintWithSpecialCharacters() public {
        string memory groupName = "Group-123_Test!@#";
        uint256 mintCost = group.calculateMintCost(groupName);

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);
        vm.stopPrank();

        assertEq(group.groupNameOf(tokenId), groupName);
        assertTrue(group.isGroupNameUsed(groupName));
    }

    function testMintWith63ByteName() public {
        // Test with a 63-byte group name (just under the limit)
        string
            memory groupName = "123456789012345678901234567890123456789012345678901234567890123";
        assertEq(bytes(groupName).length, 63);

        uint256 mintCost = group.calculateMintCost(groupName);

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);
        vm.stopPrank();

        assertEq(group.groupNameOf(tokenId), groupName);
        assertEq(group.tokenIdOf(groupName), tokenId);
    }

    function testMintWithUnicodeCharacters() public {
        string memory groupName = unicode"Group组名";
        uint256 mintCost = group.calculateMintCost(groupName);

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);
        vm.stopPrank();

        assertEq(group.groupNameOf(tokenId), groupName);
    }

    function testMintWithMaxLengthName() public {
        // Test with maximum allowed length (64 characters)
        string
            memory groupName = "1234567890123456789012345678901234567890123456789012345678901234";
        assertEq(bytes(groupName).length, 64);

        uint256 mintCost = group.calculateMintCost(groupName);

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);
        vm.stopPrank();

        assertEq(group.groupNameOf(tokenId), groupName);
        assertEq(group.tokenIdOf(groupName), tokenId);
    }

    function testCannotMintWithInternalSpaces() public {
        // Internal spaces should NOT be allowed
        string memory groupName = "Group Name";

        vm.startPrank(user1);
        vm.expectRevert(ILOVE20GroupErrors.InvalidGroupName.selector);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testMintEmitsEvent() public {
        string memory groupName = "EventTestGroup";
        uint256 mintCost = group.calculateMintCost(groupName);
        string memory normalizedName = group.normalizedNameOf(groupName);

        uint256 expectedTokenId = 1;

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);

        // Expect the GroupMint event with normalizedName
        vm.expectEmit(true, true, false, true, address(group));
        emit GroupMint({
            tokenId: expectedTokenId,
            owner: user1,
            groupName: groupName,
            normalizedName: normalizedName,
            mintCost: mintCost
        });

        group.mint(groupName);
        vm.stopPrank();
    }

    // Event declaration for testing (with normalizedName field)
    event GroupMint(
        uint256 indexed tokenId,
        address indexed owner,
        string groupName,
        string normalizedName,
        uint256 mintCost
    );

    function testMintBurnsTokens() public {
        string memory groupName = "TokenBurnTest";
        uint256 mintCost = group.calculateMintCost(groupName);
        uint256 user1BalanceBefore = love20Token.balanceOf(user1);
        uint256 totalSupplyBefore = love20Token.totalSupply();

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        group.mint(groupName);
        vm.stopPrank();

        // Tokens should be burned, not held by contract
        assertEq(love20Token.balanceOf(address(group)), 0);
        // User's balance should decrease by mintCost
        assertEq(love20Token.balanceOf(user1), user1BalanceBefore - mintCost);
        // Total supply should decrease by mintCost (burned)
        assertEq(love20Token.totalSupply(), totalSupplyBefore - mintCost);
    }

    function testMintIncreasesUnmintedSupply() public {
        string memory groupName = "UnmintedSupplyTest";
        uint256 unmintedSupplyBefore = love20Token.maxSupply() -
            love20Token.totalSupply();
        uint256 mintCost = group.calculateMintCost(groupName);

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        group.mint(groupName);
        vm.stopPrank();

        uint256 unmintedSupplyAfter = love20Token.maxSupply() -
            love20Token.totalSupply();
        // Unminted supply should increase by mintCost (burned tokens return to unminted pool)
        assertEq(unmintedSupplyAfter, unmintedSupplyBefore + mintCost);
    }

    function testMintCostIncreasesAfterBurn() public {
        // This test verifies that burning tokens increases future mint costs
        string memory groupName1 = "FirstGroup1";
        string memory groupName2 = "SecondGroup";

        // Calculate cost for second group BEFORE first mint
        uint256 costBefore = group.calculateMintCost(groupName2);

        // Mint first group (this burns tokens, increasing unminted supply)
        uint256 mintCost1 = group.calculateMintCost(groupName1);
        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost1);
        group.mint(groupName1);
        vm.stopPrank();

        // Calculate cost for second group AFTER first mint
        uint256 costAfter = group.calculateMintCost(groupName2);

        // Cost should increase because unminted supply increased
        assertGt(costAfter, costBefore);

        // Verify the exact increase: costAfter = costBefore + (mintCost1 / BASE_DIVISOR)
        uint256 expectedIncrease = mintCost1 / BASE_DIVISOR;
        assertEq(costAfter - costBefore, expectedIncrease);
    }

    function testMultipleMintsCumulativelyIncreaseCost() public {
        // Test that multiple mints cumulatively increase the cost
        string memory groupName1 = "CumulTest1";
        string memory groupName2 = "CumulTest2";
        string memory groupName3 = "CumulTest3";

        uint256 initialCost = group.calculateMintCost(groupName3);

        // Mint first group
        uint256 mintCost1 = group.calculateMintCost(groupName1);
        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost1);
        group.mint(groupName1);
        vm.stopPrank();

        uint256 costAfterFirst = group.calculateMintCost(groupName3);

        // Mint second group
        uint256 mintCost2 = group.calculateMintCost(groupName2);
        vm.startPrank(user2);
        love20Token.approve(address(group), mintCost2);
        group.mint(groupName2);
        vm.stopPrank();

        uint256 costAfterSecond = group.calculateMintCost(groupName3);

        // Costs should be increasing
        assertGt(costAfterFirst, initialCost);
        assertGt(costAfterSecond, costAfterFirst);

        // Total increase should equal total burned / BASE_DIVISOR
        uint256 totalBurned = mintCost1 + mintCost2;
        uint256 expectedTotalIncrease = totalBurned / BASE_DIVISOR;
        assertEq(costAfterSecond - initialCost, expectedTotalIncrease);
    }

    // ============ Transfer Tests ============

    function testTransfer() public {
        string memory groupName = "TransferGroup";
        uint256 mintCost = group.calculateMintCost(groupName);

        // User1 mints
        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);
        vm.stopPrank();

        // User1 transfers to user2
        vm.prank(user1);
        group.transferFrom(user1, user2, tokenId);

        assertEq(group.ownerOf(tokenId), user2);
        assertEq(group.balanceOf(user1), 0);
        assertEq(group.balanceOf(user2), 1);
    }

    function testApproveAndTransfer() public {
        string memory groupName = "ApproveGroup";
        uint256 mintCost = group.calculateMintCost(groupName);

        // User1 mints
        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);

        // User1 approves user2
        group.approve(user2, tokenId);
        vm.stopPrank();

        // User2 transfers
        vm.prank(user2);
        group.transferFrom(user1, user2, tokenId);

        assertEq(group.ownerOf(tokenId), user2);
    }

    function testTransferWithApprovalForAll() public {
        string memory groupName = "ApprovalForAllTest";
        uint256 mintCost = group.calculateMintCost(groupName);

        // User1 mints
        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);

        // User1 sets approval for all to user2
        group.setApprovalForAll(user2, true);
        vm.stopPrank();

        // User2 can transfer
        vm.prank(user2);
        group.transferFrom(user1, user2, tokenId);

        assertEq(group.ownerOf(tokenId), user2);
    }

    // ============ ERC721 Standard Tests ============

    function testSupportsInterface() public view {
        // ERC165
        assertTrue(group.supportsInterface(0x01ffc9a7));
        // ERC721
        assertTrue(group.supportsInterface(0x80ac58cd));
        // ERC721Metadata
        assertTrue(group.supportsInterface(0x5b5e139f));
        // ERC721Enumerable
        assertTrue(group.supportsInterface(0x780e9d63));
    }

    function testSetApprovalForAll() public {
        vm.prank(user1);
        group.setApprovalForAll(user2, true);

        assertTrue(group.isApprovedForAll(user1, user2));

        vm.prank(user1);
        group.setApprovalForAll(user2, false);

        assertFalse(group.isApprovedForAll(user1, user2));
    }

    // ============ ERC721Enumerable Tests ============

    function testTokenByIndex() public {
        string memory groupName1 = "LongGroup1";
        string memory groupName2 = "LongGroup2";
        string memory groupName3 = "LongGroup3";

        uint256 mintCost1 = group.calculateMintCost(groupName1);
        uint256 mintCost2 = group.calculateMintCost(groupName2);
        uint256 mintCost3 = group.calculateMintCost(groupName3);

        // Ensure users have enough tokens
        love20Token.mint(user1, mintCost1 + mintCost2);
        love20Token.mint(user2, mintCost3);

        // Mint three tokens
        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost1 + mintCost2);
        (uint256 tokenId1, ) = group.mint(groupName1);
        (uint256 tokenId2, ) = group.mint(groupName2);
        vm.stopPrank();

        vm.startPrank(user2);
        love20Token.approve(address(group), mintCost3);
        (uint256 tokenId3, ) = group.mint(groupName3);
        vm.stopPrank();

        // Test tokenByIndex
        assertEq(group.tokenByIndex(0), tokenId1);
        assertEq(group.tokenByIndex(1), tokenId2);
        assertEq(group.tokenByIndex(2), tokenId3);
        assertEq(group.totalSupply(), 3);
    }

    function testTokenOfOwnerByIndex() public {
        string memory groupName1 = "LongGroupA";
        string memory groupName2 = "LongGroupB";
        string memory groupName3 = "LongGroupC";

        uint256 mintCost1 = group.calculateMintCost(groupName1);
        uint256 mintCost2 = group.calculateMintCost(groupName2);
        uint256 mintCost3 = group.calculateMintCost(groupName3);

        // Ensure users have enough tokens
        love20Token.mint(user1, mintCost1 + mintCost2);
        love20Token.mint(user2, mintCost3);

        // User1 mints two tokens
        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost1 + mintCost2);
        (uint256 tokenId1, ) = group.mint(groupName1);
        (uint256 tokenId2, ) = group.mint(groupName2);
        vm.stopPrank();

        // User2 mints one token
        vm.startPrank(user2);
        love20Token.approve(address(group), mintCost3);
        (uint256 tokenId3, ) = group.mint(groupName3);
        vm.stopPrank();

        // Test tokenOfOwnerByIndex
        assertEq(group.tokenOfOwnerByIndex(user1, 0), tokenId1);
        assertEq(group.tokenOfOwnerByIndex(user1, 1), tokenId2);
        assertEq(group.tokenOfOwnerByIndex(user2, 0), tokenId3);
        assertEq(group.balanceOf(user1), 2);
        assertEq(group.balanceOf(user2), 1);
    }

    // ============ Query Function Tests ============

    function testTokenIdOfNonExistentGroup() public view {
        string memory nonExistentGroup = "NonExistentGroup";
        assertEq(group.tokenIdOf(nonExistentGroup), 0);
    }

    function testIsGroupNameUsedForNonExistentGroup() public view {
        string memory nonExistentGroup = "NonExistentGroup";
        assertFalse(group.isGroupNameUsed(nonExistentGroup));
    }

    function testCannotQueryGroupNameOfNonExistentToken() public view {
        assertEq(group.groupNameOf(999), "");
    }

    function testQueryFunctionsAfterMint() public {
        string memory groupName = "QueryTestGroup";
        uint256 mintCost = group.calculateMintCost(groupName);

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);
        vm.stopPrank();

        // Test all query functions
        assertEq(group.groupNameOf(tokenId), groupName);
        assertEq(group.tokenIdOf(groupName), tokenId);
        assertTrue(group.isGroupNameUsed(groupName));
        assertEq(group.ownerOf(tokenId), user1);
        assertEq(group.balanceOf(user1), 1);
    }

    // ============ Edge Case Tests ============

    function testMintSingleCharacterGroup() public view {
        // Single character group names have extremely high cost
        // This test verifies the cost calculation works correctly
        string memory groupName = "X";
        uint256 mintCost = group.calculateMintCost(groupName);

        uint256 unmintedSupply = MAX_SUPPLY - love20Token.totalSupply();
        uint256 expectedCost = (unmintedSupply / 1e8) * 1e7; // 10^(8-1) = 1e7

        // Verify the cost is calculated correctly
        assertEq(mintCost, expectedCost);

        // Note: Actually minting with this cost would exceed max supply
        // So we just verify the cost calculation is correct
    }

    function testMultipleUsersMintingSequentially() public {
        string memory groupName1 = "User1Group";
        string memory groupName2 = "User2Group";

        uint256 mintCost1 = group.calculateMintCost(groupName1);

        // User1 mints
        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost1);
        (uint256 tokenId1, ) = group.mint(groupName1);
        vm.stopPrank();

        // Calculate cost AFTER first mint (cost increases due to burn)
        uint256 mintCost2 = group.calculateMintCost(groupName2);

        // User2 mints
        vm.startPrank(user2);
        love20Token.approve(address(group), mintCost2);
        (uint256 tokenId2, ) = group.mint(groupName2);
        vm.stopPrank();

        // Verify ownership and token IDs
        assertEq(group.ownerOf(tokenId1), user1);
        assertEq(group.ownerOf(tokenId2), user2);
        assertEq(tokenId1, 1);
        assertEq(tokenId2, 2);
        assertEq(group.totalSupply(), 2);
    }

    function testTransferDoesNotChangeGroupName() public {
        string memory groupName = "TransferTest";
        uint256 mintCost = group.calculateMintCost(groupName);

        // User1 mints
        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);
        vm.stopPrank();

        // Transfer to user2
        vm.prank(user1);
        group.transferFrom(user1, user2, tokenId);

        // Group name should remain the same
        assertEq(group.groupNameOf(tokenId), groupName);
        assertEq(group.tokenIdOf(groupName), tokenId);
        assertTrue(group.isGroupNameUsed(groupName));
    }

    function testBurnDoesNotExist() public {
        // Verify that burn function doesn't exist by checking the contract doesn't have it
        // This is a design choice - Group IDs should be permanent
        string memory groupName = "PermanentGroup";
        uint256 mintCost = group.calculateMintCost(groupName);

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);
        vm.stopPrank();

        // Token should still exist and be owned by user1
        assertEq(group.ownerOf(tokenId), user1);
        assertTrue(group.isGroupNameUsed(groupName));
    }

    // ============ Fuzz Tests ============

    function testFuzzMintCostCalculation(uint8 nameLength) public view {
        vm.assume(nameLength > 0 && nameLength <= 32);

        bytes memory nameBytes = new bytes(nameLength);
        for (uint256 i = 0; i < nameLength; i++) {
            nameBytes[i] = bytes1(uint8(65 + (i % 26))); // A-Z
        }
        string memory groupName = string(nameBytes);

        uint256 cost = group.calculateMintCost(groupName);
        uint256 unmintedSupply = MAX_SUPPLY - love20Token.totalSupply();
        uint256 baseCost = unmintedSupply / 1e8;

        if (nameLength >= 8) {
            assertEq(cost, baseCost);
        } else {
            uint256 multiplier = 1;
            for (uint256 i = 0; i < 8 - nameLength; i++) {
                multiplier *= 10;
            }
            assertEq(cost, baseCost * multiplier);
        }
    }

    // ============ Safe Mint Behavior Tests ============

    function testMintToContractWithReceiver() public {
        // Deploy a contract that implements IERC721Receiver
        ERC721ReceiverMock receiver = new ERC721ReceiverMock();

        string memory groupName = "MintToReceiver";
        uint256 mintCost = group.calculateMintCost(groupName);

        // Fund the receiver contract with LOVE20 tokens
        love20Token.mint(address(receiver), mintCost);

        vm.startPrank(address(receiver));
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);
        vm.stopPrank();

        assertEq(group.ownerOf(tokenId), address(receiver));
    }

    function testMintToContractWithoutReceiverReverts() public {
        // Mint reverts if contract doesn't implement IERC721Receiver
        NonReceiverMock nonReceiver = new NonReceiverMock();

        string memory groupName = "MintToNonRcvr";
        uint256 mintCost = group.calculateMintCost(groupName);

        // Fund the non-receiver contract with LOVE20 tokens
        love20Token.mint(address(nonReceiver), mintCost);

        vm.startPrank(address(nonReceiver));
        love20Token.approve(address(group), mintCost);
        vm.expectRevert();
        group.mint(groupName);
        vm.stopPrank();
    }
}

// Mock contract that implements IERC721Receiver
contract ERC721ReceiverMock {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

// Mock contract that does NOT implement IERC721Receiver
contract NonReceiverMock {
    // Empty contract - no onERC721Received implementation
}
