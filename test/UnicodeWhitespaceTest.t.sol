// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Test} from "forge-std/Test.sol";
import {LOVE20Group} from "../src/LOVE20Group.sol";
import {ILOVE20Group, ILOVE20GroupErrors} from "../src/interfaces/ILOVE20Group.sol";
import {MockLOVE20Token} from "./mocks/MockLOVE20Token.sol";

/**
 * @title UnicodeWhitespaceTest
 * @notice Test suite for Unicode whitespace character validation
 */
contract UnicodeWhitespaceTest is Test {
    LOVE20Group public group;
    MockLOVE20Token public love20Token;

    address public user1;

    uint256 constant MAX_SUPPLY = 21_000_000_000 * 1e18; // 21 billion tokens
    uint256 constant BASE_DIVISOR = 1e7;
    uint256 constant BYTES_THRESHOLD = 7;
    uint256 constant MULTIPLIER = 10;
    uint256 constant MAX_GROUP_NAME_LENGTH = 64;

    function setUp() public {
        user1 = makeAddr("user1");

        // Deploy mock LOVE20 token
        love20Token = new MockLOVE20Token("LOVE20", "LOVE", MAX_SUPPLY);

        // Deploy LOVE20Group contract
        group = new LOVE20Group(address(love20Token), BASE_DIVISOR, BYTES_THRESHOLD, MULTIPLIER, MAX_GROUP_NAME_LENGTH);

        // Mint some tokens to user
        love20Token.mint(user1, 1_000_000 * 1e18);
    }

    // Helper function to expect GroupNameInvalidCharacters error
    function _expectInvalidChars(string memory) internal {
        vm.expectRevert(ILOVE20GroupErrors.GroupNameInvalidCharacters.selector);
    }

    // ============ Unicode Whitespace Tests ============

    function testCannotMintWithNoBreakSpace() public {
        // U+00A0 - No-Break Space
        string memory groupName = unicode"Group\u00A0Name";

        vm.startPrank(user1);
        _expectInvalidChars(groupName);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithOghamSpaceMark() public {
        // U+1680 - Ogham Space Mark
        string memory groupName = unicode"Group\u1680Name";

        vm.startPrank(user1);
        _expectInvalidChars(groupName);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithEnQuad() public {
        // U+2000 - En Quad
        string memory groupName = unicode"Group\u2000Name";

        vm.startPrank(user1);
        _expectInvalidChars(groupName);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithEmQuad() public {
        // U+2001 - Em Quad
        string memory groupName = unicode"Group\u2001Name";

        vm.startPrank(user1);
        _expectInvalidChars(groupName);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithEnSpace() public {
        // U+2002 - En Space
        string memory groupName = unicode"Group\u2002Name";

        vm.startPrank(user1);
        _expectInvalidChars(groupName);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithEmSpace() public {
        // U+2003 - Em Space
        string memory groupName = unicode"Group\u2003Name";

        vm.startPrank(user1);
        _expectInvalidChars(groupName);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithThreePerEmSpace() public {
        // U+2004 - Three-Per-Em Space
        string memory groupName = unicode"Group\u2004Name";

        vm.startPrank(user1);
        _expectInvalidChars(groupName);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithFourPerEmSpace() public {
        // U+2005 - Four-Per-Em Space
        string memory groupName = unicode"Group\u2005Name";

        vm.startPrank(user1);
        _expectInvalidChars(groupName);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithSixPerEmSpace() public {
        // U+2006 - Six-Per-Em Space
        string memory groupName = unicode"Group\u2006Name";

        vm.startPrank(user1);
        _expectInvalidChars(groupName);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithFigureSpace() public {
        // U+2007 - Figure Space
        string memory groupName = unicode"Group\u2007Name";

        vm.startPrank(user1);
        _expectInvalidChars(groupName);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithPunctuationSpace() public {
        // U+2008 - Punctuation Space
        string memory groupName = unicode"Group\u2008Name";

        vm.startPrank(user1);
        _expectInvalidChars(groupName);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithThinSpace() public {
        // U+2009 - Thin Space
        string memory groupName = unicode"Group\u2009Name";

        vm.startPrank(user1);
        _expectInvalidChars(groupName);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithHairSpace() public {
        // U+200A - Hair Space
        string memory groupName = unicode"Group\u200AName";

        vm.startPrank(user1);
        _expectInvalidChars(groupName);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithNarrowNoBreakSpace() public {
        // U+202F - Narrow No-Break Space
        string memory groupName = unicode"Group\u202FName";

        vm.startPrank(user1);
        _expectInvalidChars(groupName);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithMediumMathematicalSpace() public {
        // U+205F - Medium Mathematical Space
        string memory groupName = unicode"Group\u205FName";

        vm.startPrank(user1);
        _expectInvalidChars(groupName);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithIdeographicSpace() public {
        // U+3000 - Ideographic Space (CJK Full-Width Space)
        string memory groupName = unicode"Group\u3000Name";

        vm.startPrank(user1);
        _expectInvalidChars(groupName);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithChineseFullWidthSpace() public {
        // U+3000 - Chinese Full-Width Space (全角空格)
        string memory groupName = unicode"链群　名称"; // 注意中间是全角空格

        vm.startPrank(user1);
        _expectInvalidChars(groupName);
        group.mint(groupName);
        vm.stopPrank();
    }

    // ============ Line/Paragraph Separator Tests ============

    function testCannotMintWithLineSeparator() public {
        // U+2028 - Line Separator
        string memory groupName = unicode"Group\u2028Name";

        vm.startPrank(user1);
        _expectInvalidChars(groupName);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithParagraphSeparator() public {
        // U+2029 - Paragraph Separator
        string memory groupName = unicode"Group\u2029Name";

        vm.startPrank(user1);
        _expectInvalidChars(groupName);
        group.mint(groupName);
        vm.stopPrank();
    }

    // ============ Directional Formatting Tests ============

    function testCannotMintWithArabicLetterMark() public {
        // U+061C - Arabic Letter Mark
        string memory groupName = unicode"Group\u061CName";

        vm.startPrank(user1);
        _expectInvalidChars(groupName);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithLeftToRightEmbedding() public {
        // U+202A - Left-to-Right Embedding
        string memory groupName = unicode"Group\u202AName";

        vm.startPrank(user1);
        _expectInvalidChars(groupName);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithRightToLeftEmbedding() public {
        // U+202B - Right-to-Left Embedding
        string memory groupName = unicode"Group\u202BName";

        vm.startPrank(user1);
        _expectInvalidChars(groupName);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithPopDirectionalFormatting() public {
        // U+202C - Pop Directional Formatting
        string memory groupName = unicode"Group\u202CName";

        vm.startPrank(user1);
        _expectInvalidChars(groupName);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithLeftToRightOverride() public {
        // U+202D - Left-to-Right Override
        string memory groupName = unicode"Group\u202DName";

        vm.startPrank(user1);
        _expectInvalidChars(groupName);
        group.mint(groupName);
        vm.stopPrank();
    }

    function testCannotMintWithRightToLeftOverride() public {
        // U+202E - Right-to-Left Override
        string memory groupName = unicode"Group\u202EName";

        vm.startPrank(user1);
        _expectInvalidChars(groupName);
        group.mint(groupName);
        vm.stopPrank();
    }

    // ============ C1 Control Character Test ============

    function testCannotMintWithC1ControlCharacter() public {
        // U+0080 - C1 control character (first one in range)
        string memory groupName = unicode"Group\u0080Name";

        vm.startPrank(user1);
        _expectInvalidChars(groupName);
        group.mint(groupName);
        vm.stopPrank();
    }
}
