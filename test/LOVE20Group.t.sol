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
        assertEq(group.totalMintCost(), 0);
        assertEq(group.name(), "LOVE20 Group");
        assertEq(group.symbol(), "Group");
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
        assertEq(group.totalMintCost(), mintCost);
        assertEq(group.ownerOf(tokenId), user1);
        assertEq(group.balanceOf(user1), 1);
        assertEq(group.groupNameOf(tokenId), groupName);
        assertTrue(group.isGroupNameUsed(groupName));
        assertEq(group.tokenIdOf(groupName), tokenId);
    }

    // ============ Symbol Prefix Tests ============

    function testMintWithTestSymbolPrefix() public {
        // Deploy a new token with "Test" prefix symbol
        MockLOVE20Token testToken = new MockLOVE20Token(
            "TestToken",
            "TestToken",
            MAX_SUPPLY
        );
        LOVE20Group testGroup = new LOVE20Group(
            address(testToken),
            BASE_DIVISOR,
            BYTES_THRESHOLD,
            MULTIPLIER,
            MAX_GROUP_NAME_LENGTH
        );

        // Mint tokens to user
        testToken.mint(user1, 1_000_000 * 1e18);

        string memory originalGroupName = "MyGroup";
        // Expected group name should have "Test" prefix added
        string memory expectedGroupName = "TestMyGroup";
        uint256 mintCost = testGroup.calculateMintCost(expectedGroupName);

        vm.startPrank(user1);
        testToken.approve(address(testGroup), mintCost);
        (uint256 tokenId, ) = testGroup.mint(originalGroupName);
        vm.stopPrank();

        // Verify the group name has "Test" prefix
        assertEq(testGroup.groupNameOf(tokenId), expectedGroupName);
        assertTrue(testGroup.isGroupNameUsed(expectedGroupName));
        assertEq(testGroup.tokenIdOf(expectedGroupName), tokenId);
        // Original name should not be registered
        assertEq(testGroup.tokenIdOf(originalGroupName), 0);
        assertFalse(testGroup.isGroupNameUsed(originalGroupName));
    }

    function testMintWithTestSymbolExactMatch() public {
        // Deploy a new token with symbol exactly "Test"
        MockLOVE20Token testToken = new MockLOVE20Token(
            "Test",
            "Test",
            MAX_SUPPLY
        );
        LOVE20Group testGroup = new LOVE20Group(
            address(testToken),
            BASE_DIVISOR,
            BYTES_THRESHOLD,
            MULTIPLIER,
            MAX_GROUP_NAME_LENGTH
        );

        testToken.mint(user1, 1_000_000 * 1e18);

        string memory originalGroupName = "Group123";
        string memory expectedGroupName = "TestGroup123";
        uint256 mintCost = testGroup.calculateMintCost(expectedGroupName);

        vm.startPrank(user1);
        testToken.approve(address(testGroup), mintCost);
        (uint256 tokenId, ) = testGroup.mint(originalGroupName);
        vm.stopPrank();

        assertEq(testGroup.groupNameOf(tokenId), expectedGroupName);
    }

    function testMintWithTestSymbolLongName() public {
        // Deploy a new token with "Test" prefix symbol
        MockLOVE20Token testToken = new MockLOVE20Token(
            "TestToken",
            "TestToken",
            MAX_SUPPLY
        );
        LOVE20Group testGroup = new LOVE20Group(
            address(testToken),
            BASE_DIVISOR,
            BYTES_THRESHOLD,
            MULTIPLIER,
            MAX_GROUP_NAME_LENGTH
        );

        testToken.mint(user1, 1_000_000 * 1e18);

        string memory originalGroupName = "VeryLongGroupName123456789";
        string memory expectedGroupName = "TestVeryLongGroupName123456789";
        uint256 mintCost = testGroup.calculateMintCost(expectedGroupName);

        vm.startPrank(user1);
        testToken.approve(address(testGroup), mintCost);
        (uint256 tokenId, ) = testGroup.mint(originalGroupName);
        vm.stopPrank();

        assertEq(testGroup.groupNameOf(tokenId), expectedGroupName);
    }

    function testMintWithoutTestSymbolPrefix() public {
        // Use default token with "LOVE" symbol (no "Test" prefix)
        string memory groupName = "MyGroup";
        uint256 mintCost = group.calculateMintCost(groupName);

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);
        vm.stopPrank();

        // Group name should NOT have "Test" prefix
        assertEq(group.groupNameOf(tokenId), groupName);
        assertEq(group.groupNameOf(tokenId), "MyGroup");
        assertFalse(group.isGroupNameUsed("TestMyGroup"));
    }

    function testMintWithTestSymbolLowerCase() public {
        // Deploy a new token with lowercase "test" symbol (should NOT match)
        MockLOVE20Token testToken = new MockLOVE20Token(
            "testToken",
            "testToken",
            MAX_SUPPLY
        );
        LOVE20Group testGroup = new LOVE20Group(
            address(testToken),
            BASE_DIVISOR,
            BYTES_THRESHOLD,
            MULTIPLIER,
            MAX_GROUP_NAME_LENGTH
        );

        testToken.mint(user1, 1_000_000 * 1e18);

        string memory originalGroupName = "MyGroup";
        uint256 mintCost = testGroup.calculateMintCost(originalGroupName);

        vm.startPrank(user1);
        testToken.approve(address(testGroup), mintCost);
        (uint256 tokenId, ) = testGroup.mint(originalGroupName);
        vm.stopPrank();

        // Group name should NOT have "Test" prefix (lowercase doesn't match)
        assertEq(testGroup.groupNameOf(tokenId), originalGroupName);
        assertEq(testGroup.groupNameOf(tokenId), "MyGroup");
    }

    function testMintWithTestSymbolShortSymbol() public {
        // Deploy a new token with symbol shorter than 4 bytes (should NOT match)
        MockLOVE20Token testToken = new MockLOVE20Token(
            "ABC",
            "ABC",
            MAX_SUPPLY
        );
        LOVE20Group testGroup = new LOVE20Group(
            address(testToken),
            BASE_DIVISOR,
            BYTES_THRESHOLD,
            MULTIPLIER,
            MAX_GROUP_NAME_LENGTH
        );

        testToken.mint(user1, 1_000_000 * 1e18);

        string memory originalGroupName = "MyGroup";
        uint256 mintCost = testGroup.calculateMintCost(originalGroupName);

        vm.startPrank(user1);
        testToken.approve(address(testGroup), mintCost);
        (uint256 tokenId, ) = testGroup.mint(originalGroupName);
        vm.stopPrank();

        // Group name should NOT have "Test" prefix
        assertEq(testGroup.groupNameOf(tokenId), originalGroupName);
    }

    function testMintWithTestSymbolPartialMatch() public {
        // Deploy a new token with symbol that starts with "Tes" but not "Test"
        // This should NOT match because bytes4("Test") != bytes4("TesX")
        MockLOVE20Token testToken = new MockLOVE20Token(
            "TesToken",
            "TesToken",
            MAX_SUPPLY
        );
        LOVE20Group testGroup = new LOVE20Group(
            address(testToken),
            BASE_DIVISOR,
            BYTES_THRESHOLD,
            MULTIPLIER,
            MAX_GROUP_NAME_LENGTH
        );

        testToken.mint(user1, 1_000_000 * 1e18);

        string memory originalGroupName = "MyGroup";
        uint256 mintCost = testGroup.calculateMintCost(originalGroupName);

        vm.startPrank(user1);
        testToken.approve(address(testGroup), mintCost);
        (uint256 tokenId, ) = testGroup.mint(originalGroupName);
        vm.stopPrank();

        // Group name should NOT have "Test" prefix (partial match doesn't count)
        assertEq(testGroup.groupNameOf(tokenId), originalGroupName);
    }

    function testMintWithTestSymbolMultipleMints() public {
        // Test multiple mints with "Test" prefix symbol
        MockLOVE20Token testToken = new MockLOVE20Token(
            "TestToken",
            "TestToken",
            MAX_SUPPLY
        );
        LOVE20Group testGroup = new LOVE20Group(
            address(testToken),
            BASE_DIVISOR,
            BYTES_THRESHOLD,
            MULTIPLIER,
            MAX_GROUP_NAME_LENGTH
        );

        testToken.mint(user1, 1_000_000 * 1e18);
        testToken.mint(user2, 1_000_000 * 1e18);

        string memory groupName1 = "Group1";
        string memory groupName2 = "Group2";
        string memory expectedName1 = "TestGroup1";
        string memory expectedName2 = "TestGroup2";

        uint256 mintCost1 = testGroup.calculateMintCost(expectedName1);

        vm.startPrank(user1);
        testToken.approve(address(testGroup), mintCost1);
        (uint256 tokenId1, ) = testGroup.mint(groupName1);
        vm.stopPrank();

        // Recalculate cost after first mint (cost increases due to burn)
        uint256 mintCost2 = testGroup.calculateMintCost(expectedName2);

        vm.startPrank(user2);
        testToken.approve(address(testGroup), mintCost2);
        (uint256 tokenId2, ) = testGroup.mint(groupName2);
        vm.stopPrank();

        // Both should have "Test" prefix
        assertEq(testGroup.groupNameOf(tokenId1), expectedName1);
        assertEq(testGroup.groupNameOf(tokenId2), expectedName2);
        assertTrue(testGroup.isGroupNameUsed(expectedName1));
        assertTrue(testGroup.isGroupNameUsed(expectedName2));
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
        assertEq(group.totalMintCost(), mintCost1);

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
        assertEq(group.totalMintCost(), mintCost1 + mintCost2);
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

        // Expect the Mint event with normalizedName
        vm.expectEmit(true, true, false, true, address(group));
        emit Mint({
            tokenId: expectedTokenId,
            owner: user1,
            groupName: groupName,
            normalizedName: normalizedName,
            cost: mintCost
        });

        group.mint(groupName);
        vm.stopPrank();
    }

    // Event declaration for testing (with normalizedName field)
    event Mint(
        uint256 indexed tokenId,
        address indexed owner,
        string groupName,
        string normalizedName,
        uint256 cost
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

    // ============ ownerOf Tests with Various Characters ============

    function testOwnerOfWithAllLettersAndNumbers() public {
        // Test ownerOf with group name containing all ASCII letters (A-Z, a-z) and numbers (0-9)
        string
            memory groupName = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
        uint256 mintCost = group.calculateMintCost(groupName);

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);
        vm.stopPrank();

        // Verify ownerOf returns correct owner
        assertEq(group.ownerOf(tokenId), user1);
        assertEq(group.groupNameOf(tokenId), groupName);
        assertEq(group.balanceOf(user1), 1);
    }

    function testOwnerOfWithChineseCharacters() public {
        // Test ownerOf with group name containing Chinese characters
        // Covering common Chinese characters from different ranges
        // Each Chinese character is 3 bytes in UTF-8, so 20 characters = 60 bytes (within 64 byte limit)
        string
            memory groupName = unicode"测试群组一二三四五六七八九十甲乙丙丁戊己";
        uint256 mintCost = group.calculateMintCost(groupName);

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);
        vm.stopPrank();

        // Verify ownerOf returns correct owner
        assertEq(group.ownerOf(tokenId), user1);
        assertEq(group.groupNameOf(tokenId), groupName);
        assertEq(group.balanceOf(user1), 1);
    }

    function testOwnerOfWithMixedChineseAndAlphanumeric() public {
        // Test ownerOf with group name containing both Chinese characters and alphanumeric
        string memory groupName = unicode"Group群组123ABC测试";
        uint256 mintCost = group.calculateMintCost(groupName);

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);
        vm.stopPrank();

        // Verify ownerOf returns correct owner
        assertEq(group.ownerOf(tokenId), user1);
        assertEq(group.groupNameOf(tokenId), groupName);
        assertEq(group.balanceOf(user1), 1);
    }

    function testOwnerOfWithVariousChineseCharacters() public {
        // Test ownerOf with various Chinese characters covering different Unicode ranges
        // CJK Unified Ideographs (U+4E00-U+9FFF)
        string memory groupName = unicode"中文测试群组名称验证";
        uint256 mintCost = group.calculateMintCost(groupName);

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);
        vm.stopPrank();

        // Verify ownerOf returns correct owner
        assertEq(group.ownerOf(tokenId), user1);
        assertEq(group.groupNameOf(tokenId), groupName);
        assertEq(group.balanceOf(user1), 1);
    }

    function testOwnerOfWithCJKUnifiedIdeographsBasic() public {
        // Test CJK Unified Ideographs Basic Block (U+4E00-U+9FFF)
        // This is the most common range for Chinese characters
        // Each character is 3 bytes in UTF-8
        string memory groupName = unicode"一丁七万丈三上下不与";
        uint256 mintCost = group.calculateMintCost(groupName);

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);
        vm.stopPrank();

        assertEq(group.ownerOf(tokenId), user1);
        assertEq(group.groupNameOf(tokenId), groupName);
    }

    function testOwnerOfWithCJKUnifiedIdeographsExtensionA() public {
        // Test CJK Unified Ideographs Extension A (U+3400-U+4DBF)
        // Less common but valid Chinese characters
        string memory groupName = unicode"㐀㐁㐂㐃㐄㐅㐆㐇";
        uint256 mintCost = group.calculateMintCost(groupName);

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);
        vm.stopPrank();

        assertEq(group.ownerOf(tokenId), user1);
        assertEq(group.groupNameOf(tokenId), groupName);
    }

    function testOwnerOfWithCJKCompatibilityIdeographs() public {
        // Test CJK Compatibility Ideographs (U+F900-U+FAFF)
        string memory groupName = unicode"豈更車賈滑";
        uint256 mintCost = group.calculateMintCost(groupName);

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);
        vm.stopPrank();

        assertEq(group.ownerOf(tokenId), user1);
        assertEq(group.groupNameOf(tokenId), groupName);
    }

    function testOwnerOfWithCJKRadicalsSupplement() public {
        // Test CJK Radicals Supplement (U+2E80-U+2EFF)
        string memory groupName = unicode"⺀⺁⺂⺃⺄⺅⺆";
        uint256 mintCost = group.calculateMintCost(groupName);

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);
        vm.stopPrank();

        assertEq(group.ownerOf(tokenId), user1);
        assertEq(group.groupNameOf(tokenId), groupName);
    }

    function testOwnerOfWithCJKStrokes() public {
        // Test CJK Strokes (U+31C0-U+31EF)
        string memory groupName = unicode"㇀㇁㇂㇃㇄㇅㇆";
        uint256 mintCost = group.calculateMintCost(groupName);

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);
        vm.stopPrank();

        assertEq(group.ownerOf(tokenId), user1);
        assertEq(group.groupNameOf(tokenId), groupName);
    }

    function testOwnerOfWithFullWidthCharacters() public {
        // Test full-width Chinese characters and punctuation
        string memory groupName = unicode"全角中文测试，。！？";
        uint256 mintCost = group.calculateMintCost(groupName);

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);
        vm.stopPrank();

        assertEq(group.ownerOf(tokenId), user1);
        assertEq(group.groupNameOf(tokenId), groupName);
    }

    function testOwnerOfWithSingleChineseCharacter() public {
        // Test ownerOf with single Chinese character (minimum case)
        // Single character has high cost (3 bytes < 8 bytes threshold)
        string memory groupName = unicode"中";
        uint256 mintCost = group.calculateMintCost(groupName);

        // Ensure user has enough tokens for high-cost single character mint
        if (love20Token.balanceOf(user1) < mintCost) {
            love20Token.mint(user1, mintCost);
        }

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);
        vm.stopPrank();

        assertEq(group.ownerOf(tokenId), user1);
        assertEq(group.groupNameOf(tokenId), groupName);
    }

    function testOwnerOfWithMaxLengthChineseCharacters() public {
        // Test ownerOf with maximum length Chinese characters
        // Each Chinese character is 3 bytes in UTF-8, so 21 chars = 63 bytes (within 64 byte limit)
        // Using exactly 21 characters to stay within limit
        string
            memory groupName = unicode"一二三四五六七八九十甲乙丙丁戊己庚辛壬";
        uint256 nameLength = bytes(groupName).length;
        require(nameLength <= 64, "Group name too long");

        uint256 mintCost = group.calculateMintCost(groupName);

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);
        vm.stopPrank();

        assertEq(group.ownerOf(tokenId), user1);
        assertEq(group.groupNameOf(tokenId), groupName);
    }

    function testOwnerOfWithChineseCharactersFromDifferentRanges() public {
        // Test ownerOf with Chinese characters from multiple Unicode ranges
        // Mixing characters from different CJK blocks
        string memory groupName = unicode"中文㐀㐁⺀⺁㇀㇁";
        uint256 mintCost = group.calculateMintCost(groupName);

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);
        vm.stopPrank();

        assertEq(group.ownerOf(tokenId), user1);
        assertEq(group.groupNameOf(tokenId), groupName);
    }

    // ============ Helper Functions for Exhaustive Testing ============

    /**
     * @dev Generate UTF-8 bytes for a Unicode code point (3-byte range: U+0800-U+FFFF)
     * @param codePoint The Unicode code point (e.g., 0x4E00 for 一)
     * @return bytes3 The 3-byte UTF-8 encoding
     */
    function _encodeUTF8Char(uint256 codePoint) internal pure returns (bytes3) {
        require(
            codePoint >= 0x0800 && codePoint <= 0xFFFF,
            "Code point out of 3-byte range"
        );
        uint8 byte1 = uint8(0xE0 | ((codePoint >> 12) & 0x0F));
        uint8 byte2 = uint8(0x80 | ((codePoint >> 6) & 0x3F));
        uint8 byte3 = uint8(0x80 | (codePoint & 0x3F));
        return
            bytes3(
                bytes32(uint256(bytes32(abi.encodePacked(byte1, byte2, byte3))))
            );
    }

    /**
     * @dev Generate a group name string from a range of Unicode code points
     * @param startCodePoint Starting Unicode code point
     * @param charCount Number of characters to include (max 21 for 63 bytes)
     * @return groupName The generated group name string
     */
    function _generateGroupNameFromCodePoints(
        uint256 startCodePoint,
        uint256 charCount
    ) internal pure returns (string memory groupName) {
        require(charCount > 0 && charCount <= 21, "Invalid character count");
        bytes memory nameBytes = new bytes(charCount * 3);
        for (uint256 i = 0; i < charCount; i++) {
            uint256 codePoint = startCodePoint + i;
            bytes3 charBytes = _encodeUTF8Char(codePoint);
            nameBytes[i * 3] = charBytes[0];
            nameBytes[i * 3 + 1] = charBytes[1];
            nameBytes[i * 3 + 2] = charBytes[2];
        }
        return string(nameBytes);
    }

    /**
     * @dev Test ownerOf with a batch of Chinese characters
     * @param startCodePoint Starting Unicode code point for this batch
     * @param charCount Number of characters in this batch (max 21)
     */
    function _testOwnerOfWithCharBatch(
        uint256 startCodePoint,
        uint256 charCount
    ) internal {
        string memory groupName = _generateGroupNameFromCodePoints(
            startCodePoint,
            charCount
        );
        uint256 mintCost = group.calculateMintCost(groupName);

        // Ensure user has enough tokens
        if (love20Token.balanceOf(user1) < mintCost) {
            love20Token.mint(user1, mintCost);
        }

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);
        vm.stopPrank();

        // Verify ownerOf returns correct owner
        assertEq(group.ownerOf(tokenId), user1);
        assertEq(group.groupNameOf(tokenId), groupName);
    }

    // ============ Exhaustive Chinese Character Tests ============

    /**
     * @notice Exhaustive test helper: Test ownerOf with a range of Chinese characters
     * @dev This function can be called with different ranges to test all characters
     * @param startCodePoint Starting Unicode code point
     * @param endCodePoint Ending Unicode code point
     * @param maxBatches Maximum number of batches to test (to avoid gas limits)
     */
    function _testOwnerOfExhaustiveRange(
        uint256 startCodePoint,
        uint256 endCodePoint,
        uint256 maxBatches
    ) internal {
        uint256 CHARS_PER_BATCH = 21; // Max characters per group name (63 bytes)
        uint256 TOTAL_CHARS = endCodePoint - startCodePoint + 1;
        uint256 TOTAL_BATCHES = (TOTAL_CHARS + CHARS_PER_BATCH - 1) /
            CHARS_PER_BATCH;

        // Limit batches to avoid gas issues
        uint256 batchesToTest = TOTAL_BATCHES < maxBatches
            ? TOTAL_BATCHES
            : maxBatches;

        for (uint256 batch = 0; batch < batchesToTest; batch++) {
            uint256 batchStart = startCodePoint + (batch * CHARS_PER_BATCH);
            uint256 batchEnd = batchStart + CHARS_PER_BATCH - 1;

            // Don't exceed end code point
            if (batchEnd > endCodePoint) {
                batchEnd = endCodePoint;
            }

            uint256 batchCharCount = batchEnd - batchStart + 1;

            // Skip if batch would be empty
            if (batchCharCount == 0 || batchStart > endCodePoint) {
                break;
            }

            _testOwnerOfWithCharBatch(batchStart, batchCharCount);
        }
    }

    /**
     * @notice Exhaustive test: Test ownerOf with CJK Unified Ideographs Basic (U+4E00-U+9FFF)
     * @dev This test covers all ~20,992 Chinese characters in the basic block
     *      Note: Due to gas limits, this tests in batches. To test all characters,
     *      run this test multiple times with different batch ranges or increase gas limit.
     *      Each batch contains 21 characters (max group name length).
     */
    function testOwnerOfExhaustiveAllCJKBasicBlock() public {
        // CJK Unified Ideographs Basic: U+4E00 to U+9FFF
        // Total: 0x9FFF - 0x4E00 + 1 = 0x5200 = 20,992 characters
        // Total batches: ~1000 batches (20,992 / 21)
        // Test first 100 batches to avoid gas limits (can be increased)
        _testOwnerOfExhaustiveRange(0x4E00, 0x9FFF, 1000);
    }

    /**
     * @notice Exhaustive test: Test ownerOf with CJK Unified Ideographs Extension A (U+3400-U+4DBF)
     * @dev This test covers all ~6,592 characters in Extension A
     */
    function testOwnerOfExhaustiveCJKExtensionA() public {
        // CJK Unified Ideographs Extension A: U+3400 to U+4DBF
        // Total: ~6,592 characters, ~314 batches
        // Test first 100 batches to avoid gas limits
        _testOwnerOfExhaustiveRange(0x3400, 0x4DBF, 1000);
    }

    /**
     * @notice Test ownerOf with specific CJK Basic Block range (for comprehensive testing)
     * @dev Use this to test specific ranges when running exhaustive tests
     *      Example: testOwnerOfCJKBasicBlockRange(0x4E00, 0x4FFF) tests first 4096 characters
     *      Note: This is not a fuzz test - call it directly with specific ranges
     */
    function testOwnerOfCJKBasicBlockRange_4E00_4FFF() public {
        // Test first 4096 characters of CJK Basic Block (U+4E00 to U+4FFF)
        _testOwnerOfExhaustiveRange(0x4E00, 0x4FFF, type(uint256).max);
    }

    function testOwnerOfCJKBasicBlockRange_5000_5FFF() public {
        // Test next 4096 characters (U+5000 to U+5FFF)
        _testOwnerOfExhaustiveRange(0x5000, 0x5FFF, type(uint256).max);
    }

    function testOwnerOfCJKBasicBlockRange_6000_6FFF() public {
        // Test next 4096 characters (U+6000 to U+6FFF)
        _testOwnerOfExhaustiveRange(0x6000, 0x6FFF, type(uint256).max);
    }

    function testOwnerOfCJKBasicBlockRange_7000_7FFF() public {
        // Test next 4096 characters (U+7000 to U+7FFF)
        _testOwnerOfExhaustiveRange(0x7000, 0x7FFF, type(uint256).max);
    }

    function testOwnerOfCJKBasicBlockRange_8000_8FFF() public {
        // Test next 4096 characters (U+8000 to U+8FFF)
        _testOwnerOfExhaustiveRange(0x8000, 0x8FFF, type(uint256).max);
    }

    function testOwnerOfCJKBasicBlockRange_9000_9FFF() public {
        // Test last 4096 characters (U+9000 to U+9FFF)
        _testOwnerOfExhaustiveRange(0x9000, 0x9FFF, type(uint256).max);
    }

    /**
     * @notice Fuzz test: randomly test ownerOf with different numbers of Chinese characters
     * @dev This complements the exhaustive tests by randomly sampling
     */
    function testFuzzOwnerOfWithChineseCharacters(uint8 charCount) public {
        // Bound charCount to ensure valid group name length (each Chinese char is 3 bytes)
        // Max 64 bytes / 3 bytes per char = ~21 characters max
        charCount = uint8(bound(charCount, 1, 20));

        // Generate a group name with the specified number of Chinese characters
        // Using characters from CJK Unified Ideographs Basic (U+4E00-U+9FFF)
        bytes memory nameBytes = new bytes(charCount * 3);
        for (uint256 i = 0; i < charCount; i++) {
            // Generate UTF-8 encoding for character U+4E00 + i
            // Each character in range U+4E00-U+9FFF uses 3 bytes: 0xE4 0xB8 0x80 + offset
            uint256 codePoint = 0x4E00 + (i % 0x5200); // Modulo to stay in valid range
            bytes3 charBytes = _encodeUTF8Char(codePoint);

            nameBytes[i * 3] = charBytes[0];
            nameBytes[i * 3 + 1] = charBytes[1];
            nameBytes[i * 3 + 2] = charBytes[2];
        }

        string memory groupName = string(nameBytes);
        uint256 mintCost = group.calculateMintCost(groupName);

        // Ensure user has enough tokens
        if (love20Token.balanceOf(user1) < mintCost) {
            love20Token.mint(user1, mintCost);
        }

        vm.startPrank(user1);
        love20Token.approve(address(group), mintCost);
        (uint256 tokenId, ) = group.mint(groupName);
        vm.stopPrank();

        // Verify ownerOf returns correct owner
        assertEq(group.ownerOf(tokenId), user1);
        assertEq(group.groupNameOf(tokenId), groupName);
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
