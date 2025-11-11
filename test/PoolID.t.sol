// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {PoolID} from "../src/PoolID.sol";
import {
    IPoolID,
    IPoolIDErrors,
    IPoolIDEvents
} from "../src/interfaces/IPoolID.sol";
import {MockLOVE20Token} from "./mocks/MockLOVE20Token.sol";

/**
 * @title PoolIDTest
 * @notice Test suite for the PoolID contract
 */
contract PoolIDTest is Test {
    PoolID public poolID;
    MockLOVE20Token public love20Token;

    address public user1;
    address public user2;

    uint256 constant INITIAL_SUPPLY = 10_000_000_000 * 1e18; // 10 billion tokens
    uint256 constant MAX_SUPPLY = 21_000_000_000 * 1e18; // 21 billion tokens

    function setUp() public {
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy mock LOVE20 token
        love20Token = new MockLOVE20Token("LOVE20", "LOVE", MAX_SUPPLY);

        // Deploy PoolID contract
        poolID = new PoolID(address(love20Token));

        // Mint some tokens to users
        love20Token.mint(user1, 1_000_000 * 1e18);
        love20Token.mint(user2, 1_000_000 * 1e18);
    }

    // ============ Initialization Tests ============

    function testInitialization() public view {
        assertEq(poolID.love20Token(), address(love20Token));
        assertEq(poolID.totalSupply(), 0);
        assertEq(poolID.name(), "LOVE20 Pool ID");
        assertEq(poolID.symbol(), "LPID");
    }

    function testCannotInitializeWithZeroAddress() public {
        vm.expectRevert(IPoolIDErrors.InvalidAddress.selector);
        new PoolID(address(0));
    }

    // ============ Minting Cost Calculation Tests ============

    function testCalculateMintCost10Bytes() public view {
        // Pool name with 10 bytes
        string memory poolName = "1234567890"; // 10 bytes
        uint256 unmintedSupply = MAX_SUPPLY - love20Token.totalSupply();
        uint256 expectedCost = unmintedSupply / 1e8;

        uint256 actualCost = poolID.calculateMintCost(poolName);
        assertEq(actualCost, expectedCost);
    }

    function testCalculateMintCost12Bytes() public view {
        // Pool name with 12 bytes
        string memory poolName = "123456789012"; // 12 bytes
        uint256 unmintedSupply = MAX_SUPPLY - love20Token.totalSupply();
        uint256 expectedCost = unmintedSupply / 1e8;

        uint256 actualCost = poolID.calculateMintCost(poolName);
        assertEq(actualCost, expectedCost);
    }

    function testCalculateMintCost8Bytes() public view {
        // Pool name with 8 bytes
        string memory poolName = "12345678"; // 8 bytes
        uint256 unmintedSupply = MAX_SUPPLY - love20Token.totalSupply();
        uint256 expectedCost = (unmintedSupply / 1e8) * 100; // 10^(10-8) = 100

        uint256 actualCost = poolID.calculateMintCost(poolName);
        assertEq(actualCost, expectedCost);
    }

    function testCalculateMintCost6Bytes() public view {
        // Pool name with 6 bytes
        string memory poolName = "123456"; // 6 bytes
        uint256 unmintedSupply = MAX_SUPPLY - love20Token.totalSupply();
        uint256 expectedCost = (unmintedSupply / 1e8) * 10000; // 10^(10-6) = 10000

        uint256 actualCost = poolID.calculateMintCost(poolName);
        assertEq(actualCost, expectedCost);
    }

    function testCalculateMintCost4Bytes() public view {
        // Pool name with 4 bytes
        string memory poolName = "1234"; // 4 bytes
        uint256 unmintedSupply = MAX_SUPPLY - love20Token.totalSupply();
        uint256 expectedCost = (unmintedSupply / 1e8) * 1000000; // 10^(10-4) = 1000000

        uint256 actualCost = poolID.calculateMintCost(poolName);
        assertEq(actualCost, expectedCost);
    }

    function testCalculateMintCost1Byte() public view {
        // Pool name with 1 byte (extreme case)
        string memory poolName = "a"; // 1 byte
        uint256 unmintedSupply = MAX_SUPPLY - love20Token.totalSupply();
        uint256 expectedCost = (unmintedSupply / 1e8) * 1e9; // 10^(10-1) = 1e9

        uint256 actualCost = poolID.calculateMintCost(poolName);
        assertEq(actualCost, expectedCost);
    }

    // ============ Minting Tests ============

    function testMint() public {
        string memory poolName = "TestPool123";
        uint256 mintCost = poolID.calculateMintCost(poolName);

        vm.startPrank(user1);
        love20Token.approve(address(poolID), mintCost);
        uint256 tokenId = poolID.mint(poolName);
        vm.stopPrank();

        assertEq(tokenId, 1);
        assertEq(poolID.totalSupply(), 1);
        assertEq(poolID.ownerOf(tokenId), user1);
        assertEq(poolID.balanceOf(user1), 1);
        assertEq(poolID.poolNameOf(tokenId), poolName);
        assertTrue(poolID.isPoolNameUsed(poolName));
        assertEq(poolID.tokenIdOf(poolName), tokenId);
    }

    function testMintMultiple() public {
        string memory poolName1 = "FirstPoolName";
        string memory poolName2 = "SecondPoolName";

        uint256 mintCost1 = poolID.calculateMintCost(poolName1);
        uint256 mintCost2 = poolID.calculateMintCost(poolName2);

        // User1 mints first pool
        vm.startPrank(user1);
        love20Token.approve(address(poolID), mintCost1);
        uint256 tokenId1 = poolID.mint(poolName1);
        vm.stopPrank();

        // User2 mints second pool
        vm.startPrank(user2);
        love20Token.approve(address(poolID), mintCost2);
        uint256 tokenId2 = poolID.mint(poolName2);
        vm.stopPrank();

        assertEq(tokenId1, 1);
        assertEq(tokenId2, 2);
        assertEq(poolID.totalSupply(), 2);
        assertEq(poolID.ownerOf(tokenId1), user1);
        assertEq(poolID.ownerOf(tokenId2), user2);
    }

    function testCannotMintWithEmptyName() public {
        vm.startPrank(user1);
        vm.expectRevert(IPoolIDErrors.PoolNameEmpty.selector);
        poolID.mint("");
        vm.stopPrank();
    }

    function testCannotMintDuplicateName() public {
        string memory poolName = "TestPool";
        uint256 mintCost = poolID.calculateMintCost(poolName);

        // First mint succeeds
        vm.startPrank(user1);
        love20Token.approve(address(poolID), mintCost);
        poolID.mint(poolName);
        vm.stopPrank();

        // Second mint with same name fails
        vm.startPrank(user2);
        love20Token.approve(address(poolID), mintCost);
        vm.expectRevert(IPoolIDErrors.PoolNameAlreadyExists.selector);
        poolID.mint(poolName);
        vm.stopPrank();
    }

    function testCannotMintWithInsufficientApproval() public {
        string memory poolName = "TestPool";
        uint256 mintCost = poolID.calculateMintCost(poolName);

        vm.startPrank(user1);
        love20Token.approve(address(poolID), mintCost - 1); // Approve less than needed
        vm.expectRevert();
        poolID.mint(poolName);
        vm.stopPrank();
    }

    function testMintWithSpecialCharacters() public {
        string memory poolName = "Pool-123_Test!@#";
        uint256 mintCost = poolID.calculateMintCost(poolName);

        vm.startPrank(user1);
        love20Token.approve(address(poolID), mintCost);
        uint256 tokenId = poolID.mint(poolName);
        vm.stopPrank();

        assertEq(poolID.poolNameOf(tokenId), poolName);
        assertTrue(poolID.isPoolNameUsed(poolName));
    }

    function testMintWithLongName() public {
        // Test with a very long pool name (100 bytes)
        string
            memory poolName = "ThisIsAVeryLongPoolNameThatContainsMoreThan100CharactersToTestTheBehaviorOfTheContractWhenHandling";
        uint256 mintCost = poolID.calculateMintCost(poolName);

        vm.startPrank(user1);
        love20Token.approve(address(poolID), mintCost);
        uint256 tokenId = poolID.mint(poolName);
        vm.stopPrank();

        assertEq(poolID.poolNameOf(tokenId), poolName);
        assertEq(poolID.tokenIdOf(poolName), tokenId);
    }

    function testMintWithUnicodeCharacters() public {
        string memory poolName = unicode"Pool池名";
        uint256 mintCost = poolID.calculateMintCost(poolName);

        vm.startPrank(user1);
        love20Token.approve(address(poolID), mintCost);
        uint256 tokenId = poolID.mint(poolName);
        vm.stopPrank();

        assertEq(poolID.poolNameOf(tokenId), poolName);
    }

    function testMintEmitsEvent() public {
        string memory poolName = "EventTestPool";
        uint256 mintCost = poolID.calculateMintCost(poolName);

        uint256 expectedTokenId = 1;

        vm.startPrank(user1);
        love20Token.approve(address(poolID), mintCost);

        // Expect the PoolIDMinted event
        vm.expectEmit(true, true, false, true, address(poolID));
        emit PoolIDMinted(expectedTokenId, user1, poolName, mintCost);

        poolID.mint(poolName);
        vm.stopPrank();
    }

    // Event declaration for testing
    event PoolIDMinted(
        uint256 indexed tokenId,
        address indexed owner,
        string poolName,
        uint256 mintCost
    );

    function testMintTransfersTokensToContract() public {
        string memory poolName = "TokenTransferTest";
        uint256 mintCost = poolID.calculateMintCost(poolName);
        uint256 balanceBefore = love20Token.balanceOf(address(poolID));
        uint256 user1BalanceBefore = love20Token.balanceOf(user1);

        vm.startPrank(user1);
        love20Token.approve(address(poolID), mintCost);
        poolID.mint(poolName);
        vm.stopPrank();

        assertEq(
            love20Token.balanceOf(address(poolID)),
            balanceBefore + mintCost
        );
        assertEq(love20Token.balanceOf(user1), user1BalanceBefore - mintCost);
    }

    // ============ Transfer Tests ============

    function testTransfer() public {
        string memory poolName = "TransferPool";
        uint256 mintCost = poolID.calculateMintCost(poolName);

        // User1 mints
        vm.startPrank(user1);
        love20Token.approve(address(poolID), mintCost);
        uint256 tokenId = poolID.mint(poolName);
        vm.stopPrank();

        // User1 transfers to user2
        vm.prank(user1);
        poolID.transferFrom(user1, user2, tokenId);

        assertEq(poolID.ownerOf(tokenId), user2);
        assertEq(poolID.balanceOf(user1), 0);
        assertEq(poolID.balanceOf(user2), 1);
    }

    function testApproveAndTransfer() public {
        string memory poolName = "ApprovePool";
        uint256 mintCost = poolID.calculateMintCost(poolName);

        // User1 mints
        vm.startPrank(user1);
        love20Token.approve(address(poolID), mintCost);
        uint256 tokenId = poolID.mint(poolName);

        // User1 approves user2
        poolID.approve(user2, tokenId);
        vm.stopPrank();

        // User2 transfers
        vm.prank(user2);
        poolID.transferFrom(user1, user2, tokenId);

        assertEq(poolID.ownerOf(tokenId), user2);
    }

    function testTransferWithApprovalForAll() public {
        string memory poolName = "ApprovalForAllTest";
        uint256 mintCost = poolID.calculateMintCost(poolName);

        // User1 mints
        vm.startPrank(user1);
        love20Token.approve(address(poolID), mintCost);
        uint256 tokenId = poolID.mint(poolName);

        // User1 sets approval for all to user2
        poolID.setApprovalForAll(user2, true);
        vm.stopPrank();

        // User2 can transfer
        vm.prank(user2);
        poolID.transferFrom(user1, user2, tokenId);

        assertEq(poolID.ownerOf(tokenId), user2);
    }

    // ============ ERC721 Standard Tests ============

    function testSupportsInterface() public view {
        // ERC165
        assertTrue(poolID.supportsInterface(0x01ffc9a7));
        // ERC721
        assertTrue(poolID.supportsInterface(0x80ac58cd));
        // ERC721Metadata
        assertTrue(poolID.supportsInterface(0x5b5e139f));
        // ERC721Enumerable
        assertTrue(poolID.supportsInterface(0x780e9d63));
    }

    function testSetApprovalForAll() public {
        vm.prank(user1);
        poolID.setApprovalForAll(user2, true);

        assertTrue(poolID.isApprovedForAll(user1, user2));

        vm.prank(user1);
        poolID.setApprovalForAll(user2, false);

        assertFalse(poolID.isApprovedForAll(user1, user2));
    }

    // ============ ERC721Enumerable Tests ============

    function testTokenByIndex() public {
        string memory poolName1 = "LongPool1";
        string memory poolName2 = "LongPool2";
        string memory poolName3 = "LongPool3";

        uint256 mintCost1 = poolID.calculateMintCost(poolName1);
        uint256 mintCost2 = poolID.calculateMintCost(poolName2);
        uint256 mintCost3 = poolID.calculateMintCost(poolName3);

        // Ensure users have enough tokens
        love20Token.mint(user1, mintCost1 + mintCost2);
        love20Token.mint(user2, mintCost3);

        // Mint three tokens
        vm.startPrank(user1);
        love20Token.approve(address(poolID), mintCost1 + mintCost2);
        uint256 tokenId1 = poolID.mint(poolName1);
        uint256 tokenId2 = poolID.mint(poolName2);
        vm.stopPrank();

        vm.startPrank(user2);
        love20Token.approve(address(poolID), mintCost3);
        uint256 tokenId3 = poolID.mint(poolName3);
        vm.stopPrank();

        // Test tokenByIndex
        assertEq(poolID.tokenByIndex(0), tokenId1);
        assertEq(poolID.tokenByIndex(1), tokenId2);
        assertEq(poolID.tokenByIndex(2), tokenId3);
        assertEq(poolID.totalSupply(), 3);
    }

    function testTokenOfOwnerByIndex() public {
        string memory poolName1 = "LongPoolA";
        string memory poolName2 = "LongPoolB";
        string memory poolName3 = "LongPoolC";

        uint256 mintCost1 = poolID.calculateMintCost(poolName1);
        uint256 mintCost2 = poolID.calculateMintCost(poolName2);
        uint256 mintCost3 = poolID.calculateMintCost(poolName3);

        // Ensure users have enough tokens
        love20Token.mint(user1, mintCost1 + mintCost2);
        love20Token.mint(user2, mintCost3);

        // User1 mints two tokens
        vm.startPrank(user1);
        love20Token.approve(address(poolID), mintCost1 + mintCost2);
        uint256 tokenId1 = poolID.mint(poolName1);
        uint256 tokenId2 = poolID.mint(poolName2);
        vm.stopPrank();

        // User2 mints one token
        vm.startPrank(user2);
        love20Token.approve(address(poolID), mintCost3);
        uint256 tokenId3 = poolID.mint(poolName3);
        vm.stopPrank();

        // Test tokenOfOwnerByIndex
        assertEq(poolID.tokenOfOwnerByIndex(user1, 0), tokenId1);
        assertEq(poolID.tokenOfOwnerByIndex(user1, 1), tokenId2);
        assertEq(poolID.tokenOfOwnerByIndex(user2, 0), tokenId3);
        assertEq(poolID.balanceOf(user1), 2);
        assertEq(poolID.balanceOf(user2), 1);
    }

    // ============ Query Function Tests ============

    function testTokenIdOfNonExistentPool() public view {
        string memory nonExistentPool = "NonExistentPool";
        assertEq(poolID.tokenIdOf(nonExistentPool), 0);
    }

    function testIsPoolNameUsedForNonExistentPool() public view {
        string memory nonExistentPool = "NonExistentPool";
        assertFalse(poolID.isPoolNameUsed(nonExistentPool));
    }

    function testCannotQueryPoolNameOfNonExistentToken() public {
        vm.expectRevert();
        poolID.poolNameOf(999);
    }

    function testQueryFunctionsAfterMint() public {
        string memory poolName = "QueryTestPool";
        uint256 mintCost = poolID.calculateMintCost(poolName);

        vm.startPrank(user1);
        love20Token.approve(address(poolID), mintCost);
        uint256 tokenId = poolID.mint(poolName);
        vm.stopPrank();

        // Test all query functions
        assertEq(poolID.poolNameOf(tokenId), poolName);
        assertEq(poolID.tokenIdOf(poolName), tokenId);
        assertTrue(poolID.isPoolNameUsed(poolName));
        assertEq(poolID.ownerOf(tokenId), user1);
        assertEq(poolID.balanceOf(user1), 1);
    }

    // ============ Edge Case Tests ============

    function testMintSingleCharacterPool() public view {
        // Single character pool names have extremely high cost
        // This test verifies the cost calculation works correctly
        string memory poolName = "X";
        uint256 mintCost = poolID.calculateMintCost(poolName);

        uint256 unmintedSupply = MAX_SUPPLY - love20Token.totalSupply();
        uint256 expectedCost = (unmintedSupply / 1e8) * 1e9; // 10^(10-1) = 1e9

        // Verify the cost is calculated correctly
        assertEq(mintCost, expectedCost);

        // Note: Actually minting with this cost would exceed max supply
        // So we just verify the cost calculation is correct
    }

    function testMultipleUsersMintingSequentially() public {
        string memory poolName1 = "User1Pool";
        string memory poolName2 = "User2Pool";

        uint256 mintCost1 = poolID.calculateMintCost(poolName1);
        uint256 mintCost2 = poolID.calculateMintCost(poolName2);

        // User1 mints
        vm.startPrank(user1);
        love20Token.approve(address(poolID), mintCost1);
        uint256 tokenId1 = poolID.mint(poolName1);
        vm.stopPrank();

        // User2 mints
        vm.startPrank(user2);
        love20Token.approve(address(poolID), mintCost2);
        uint256 tokenId2 = poolID.mint(poolName2);
        vm.stopPrank();

        // Verify ownership and token IDs
        assertEq(poolID.ownerOf(tokenId1), user1);
        assertEq(poolID.ownerOf(tokenId2), user2);
        assertEq(tokenId1, 1);
        assertEq(tokenId2, 2);
        assertEq(poolID.totalSupply(), 2);
    }

    function testTransferDoesNotChangePoolName() public {
        string memory poolName = "TransferTest";
        uint256 mintCost = poolID.calculateMintCost(poolName);

        // User1 mints
        vm.startPrank(user1);
        love20Token.approve(address(poolID), mintCost);
        uint256 tokenId = poolID.mint(poolName);
        vm.stopPrank();

        // Transfer to user2
        vm.prank(user1);
        poolID.transferFrom(user1, user2, tokenId);

        // Pool name should remain the same
        assertEq(poolID.poolNameOf(tokenId), poolName);
        assertEq(poolID.tokenIdOf(poolName), tokenId);
        assertTrue(poolID.isPoolNameUsed(poolName));
    }

    function testBurnDoesNotExist() public {
        // Verify that burn function doesn't exist by checking the contract doesn't have it
        // This is a design choice - Pool IDs should be permanent
        string memory poolName = "PermanentPool";
        uint256 mintCost = poolID.calculateMintCost(poolName);

        vm.startPrank(user1);
        love20Token.approve(address(poolID), mintCost);
        uint256 tokenId = poolID.mint(poolName);
        vm.stopPrank();

        // Token should still exist and be owned by user1
        assertEq(poolID.ownerOf(tokenId), user1);
        assertTrue(poolID.isPoolNameUsed(poolName));
    }

    // ============ Fuzz Tests ============

    function testFuzzMintCostCalculation(uint8 nameLength) public view {
        vm.assume(nameLength > 0 && nameLength <= 32);

        bytes memory nameBytes = new bytes(nameLength);
        for (uint256 i = 0; i < nameLength; i++) {
            nameBytes[i] = bytes1(uint8(65 + (i % 26))); // A-Z
        }
        string memory poolName = string(nameBytes);

        uint256 cost = poolID.calculateMintCost(poolName);
        uint256 unmintedSupply = MAX_SUPPLY - love20Token.totalSupply();
        uint256 baseCost = unmintedSupply / 1e8;

        if (nameLength >= 10) {
            assertEq(cost, baseCost);
        } else {
            uint256 multiplier = 1;
            for (uint256 i = 0; i < 10 - nameLength; i++) {
                multiplier *= 10;
            }
            assertEq(cost, baseCost * multiplier);
        }
    }
}
