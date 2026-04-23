// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Test} from "forge-std/Test.sol";
import {stdError} from "forge-std/StdError.sol";
import {LOVE20Group} from "../src/LOVE20Group.sol";
import {GroupMarket} from "../src/GroupMarket.sol";
import {ILOVE20Group} from "../src/interfaces/ILOVE20Group.sol";
import {IGroupMarket, IGroupMarketErrors} from "../src/interfaces/IGroupMarket.sol";
import {ILOVE20Token} from "../src/interfaces/ILOVE20Token.sol";
import {MockLOVE20Token} from "./mocks/MockLOVE20Token.sol";

contract GroupMarketHarness is GroupMarket {
    constructor(ILOVE20Group group_, ILOVE20Token love20Token_) GroupMarket(group_, love20Token_) {}

    function exposedMinimumReplacementAmount(uint256 lowestAmount) external pure returns (uint256) {
        return _minimumReplacementAmount(lowestAmount);
    }
}

contract GroupMarketTest is Test {
    LOVE20Group public group;
    GroupMarketHarness public market;
    MockLOVE20Token public love20Token;

    address public seller;
    address public buyer;
    address public bidder;
    address public bidder2;

    uint256 constant MAX_SUPPLY = 21_000_000_000 * 1e18;

    uint256 constant BASE_DIVISOR = 1e7;
    uint256 constant BYTES_THRESHOLD = 7;
    uint256 constant MULTIPLIER = 10;
    uint256 constant MAX_GROUP_NAME_LENGTH = 64;

    function setUp() public {
        seller = makeAddr("seller");
        buyer = makeAddr("buyer");
        bidder = makeAddr("bidder");
        bidder2 = makeAddr("bidder2");

        love20Token = new MockLOVE20Token("LOVE20", "LOVE", MAX_SUPPLY);
        group = new LOVE20Group(address(love20Token), BASE_DIVISOR, BYTES_THRESHOLD, MULTIPLIER, MAX_GROUP_NAME_LENGTH);
        market = new GroupMarketHarness(ILOVE20Group(address(group)), ILOVE20Token(address(love20Token)));

        love20Token.mint(seller, 1_000_000 * 1e18);
        love20Token.mint(buyer, 1_000_000 * 1e18);
        love20Token.mint(bidder, 1_000_000 * 1e18);
        love20Token.mint(bidder2, 1_000_000 * 1e18);
    }

    function testInitialization() public view {
        assertEq(address(market.group()), address(group));
        assertEq(address(market.love20Token()), address(love20Token));
        assertEq(market.FEE_BPS(), 1_000);
        assertEq(market.BPS_DENOMINATOR(), 10_000);
    }

    function testConstructorRevertsForZeroGroupAddress() public {
        vm.expectRevert(IGroupMarketErrors.InvalidAddress.selector);
        new GroupMarket(ILOVE20Group(address(0)), ILOVE20Token(address(love20Token)));
    }

    function testConstructorRevertsForZeroTokenAddress() public {
        vm.expectRevert(IGroupMarketErrors.InvalidAddress.selector);
        new GroupMarket(ILOVE20Group(address(group)), ILOVE20Token(address(0)));
    }

    function testDirectSafeTransferToMarketReverts() public {
        uint256 tokenId = _mintGroupFor(seller, "MarketDirectSafeTransfer");

        vm.startPrank(seller);
        vm.expectRevert(bytes("ERC721: transfer to non ERC721Receiver implementer"));
        group.safeTransferFrom(seller, address(market), tokenId);
        vm.stopPrank();

        assertEq(group.ownerOf(tokenId), seller);
    }

    function testForeignSafeTransferToMarketReverts() public {
        MockLOVE20Token otherToken = new MockLOVE20Token("LOVE20-OTHER", "LOVEO", MAX_SUPPLY);
        LOVE20Group otherGroup =
            new LOVE20Group(address(otherToken), BASE_DIVISOR, BYTES_THRESHOLD, MULTIPLIER, MAX_GROUP_NAME_LENGTH);

        otherToken.mint(seller, 1_000_000 * 1e18);

        uint256 mintCost = otherGroup.calculateMintCost("OtherMarketGroup");

        vm.startPrank(seller);
        otherToken.approve(address(otherGroup), mintCost);
        (uint256 tokenId,) = otherGroup.mint("OtherMarketGroup");

        vm.expectRevert(bytes("ERC721: transfer to non ERC721Receiver implementer"));
        otherGroup.safeTransferFrom(seller, address(market), tokenId);
        vm.stopPrank();

        assertEq(otherGroup.ownerOf(tokenId), seller);
    }

    function testCreateListingAndBuyBurnsFee() public {
        uint256 tokenId = _mintGroupFor(seller, "MarketGroupOne");
        uint256 price = 1_000 * 1e18;
        uint256 fee = market.calculateFee(price);
        uint256 sellerProceeds = market.calculateSellerProceeds(price);

        vm.startPrank(seller);
        group.approve(address(market), tokenId);
        market.createListing(tokenId, price);
        vm.stopPrank();

        assertEq(group.ownerOf(tokenId), address(market));
        assertEq(market.listing(tokenId).seller, seller);
        assertEq(market.listing(tokenId).price, price);

        uint256 sellerBalanceBefore = love20Token.balanceOf(seller);
        uint256 buyerBalanceBefore = love20Token.balanceOf(buyer);
        uint256 totalSupplyBefore = love20Token.totalSupply();

        vm.startPrank(buyer);
        love20Token.approve(address(market), price);
        market.buyListing(tokenId);
        vm.stopPrank();

        assertEq(group.ownerOf(tokenId), buyer);
        assertEq(love20Token.balanceOf(seller), sellerBalanceBefore + sellerProceeds);
        assertEq(love20Token.balanceOf(buyer), buyerBalanceBefore - price);
        assertEq(love20Token.totalSupply(), totalSupplyBefore - fee);
        assertEq(love20Token.balanceOf(address(market)), 0);
        assertEq(market.listing(tokenId).seller, address(0));
    }

    function testCreateListingsCreatesMultipleListings() public {
        uint256 tokenId1 = _mintGroupFor(seller, "MarketBatchListOne");
        uint256 tokenId2 = _mintGroupFor(seller, "MarketBatchListTwo");
        uint256 tokenId3 = _mintGroupFor(seller, "MarketBatchListThree");

        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = tokenId1;
        tokenIds[1] = tokenId2;
        tokenIds[2] = tokenId3;

        uint256[] memory prices = new uint256[](3);
        prices[0] = 100 * 1e18;
        prices[1] = 200 * 1e18;
        prices[2] = 300 * 1e18;

        vm.startPrank(seller);
        group.setApprovalForAll(address(market), true);
        market.createListings(tokenIds, prices);
        vm.stopPrank();

        assertEq(market.listingCount(), 3);
        assertEq(group.ownerOf(tokenId1), address(market));
        assertEq(group.ownerOf(tokenId2), address(market));
        assertEq(group.ownerOf(tokenId3), address(market));
        assertEq(market.listing(tokenId1).seller, seller);
        assertEq(market.listing(tokenId1).price, prices[0]);
        assertEq(market.listing(tokenId2).seller, seller);
        assertEq(market.listing(tokenId2).price, prices[1]);
        assertEq(market.listing(tokenId3).seller, seller);
        assertEq(market.listing(tokenId3).price, prices[2]);
    }

    function testCreateListingsRevertsForLengthMismatch() public {
        uint256 tokenId = _mintGroupFor(seller, "MarketBatchLengthMismatch");

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        uint256[] memory prices = new uint256[](2);
        prices[0] = 100 * 1e18;
        prices[1] = 200 * 1e18;

        vm.prank(seller);
        vm.expectRevert(IGroupMarketErrors.ArrayLengthMismatch.selector);
        market.createListings(tokenIds, prices);
    }

    function testCreateListingsRevertsAtomicallyForInvalidPrice() public {
        uint256 tokenId1 = _mintGroupFor(seller, "MarketBatchAtomicOne");
        uint256 tokenId2 = _mintGroupFor(seller, "MarketBatchAtomicTwo");

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenId1;
        tokenIds[1] = tokenId2;

        uint256[] memory prices = new uint256[](2);
        prices[0] = 100 * 1e18;
        prices[1] = 0;

        vm.startPrank(seller);
        group.setApprovalForAll(address(market), true);
        vm.expectRevert(IGroupMarketErrors.InvalidAmount.selector);
        market.createListings(tokenIds, prices);
        vm.stopPrank();

        assertEq(market.listingCount(), 0);
        assertEq(group.ownerOf(tokenId1), seller);
        assertEq(group.ownerOf(tokenId2), seller);
        assertEq(market.listing(tokenId1).seller, address(0));
        assertEq(market.listing(tokenId2).seller, address(0));
    }

    function testBuyAtMaxPriceRevertsOnFeeOverflow() public {
        uint256 tokenId = _mintGroupFor(seller, "MarketMaxPrice");

        vm.startPrank(seller);
        group.approve(address(market), tokenId);
        market.createListing(tokenId, type(uint256).max);
        vm.stopPrank();

        deal(address(love20Token), buyer, type(uint256).max);

        vm.startPrank(buyer);
        love20Token.approve(address(market), type(uint256).max);
        vm.expectRevert(stdError.arithmeticError);
        market.buyListing(tokenId);
        vm.stopPrank();

        assertEq(group.ownerOf(tokenId), address(market));
        assertEq(market.listing(tokenId).seller, seller);
        assertEq(market.listing(tokenId).price, type(uint256).max);
    }

    function testBuyDoesNotClearBuyerExistingOffer() public {
        uint256 tokenId = _mintGroupFor(seller, "MarketGroupBuyOffer");
        uint256 offerAmount = 300 * 1e18;
        uint256 price = 1_000 * 1e18;

        vm.startPrank(buyer);
        love20Token.approve(address(market), offerAmount + price);
        market.makeOffer(tokenId, offerAmount);
        vm.stopPrank();

        vm.startPrank(seller);
        group.approve(address(market), tokenId);
        market.createListing(tokenId, price);
        vm.stopPrank();

        uint256 buyerBalanceBeforeBuy = love20Token.balanceOf(buyer);

        vm.prank(buyer);
        market.buyListing(tokenId);

        assertEq(group.ownerOf(tokenId), buyer);
        assertEq(market.offer(tokenId, buyer).amount, offerAmount);
        assertEq(uint256(market.offer(tokenId, buyer).status), uint256(IGroupMarket.OfferStatus.Active));
        assertEq(love20Token.balanceOf(buyer), buyerBalanceBeforeBuy - price);
        assertEq(love20Token.balanceOf(address(market)), offerAmount);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IGroupMarketErrors.CannotAcceptOwnOffer.selector, tokenId));
        market.acceptOffer(tokenId, buyer);

        vm.startPrank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IGroupMarketErrors.OfferCancellationLocked.selector,
                block.number,
                market.offer(tokenId, buyer).cancelAvailableBlock
            )
        );
        market.cancelOffer(tokenId);

        vm.roll(market.offer(tokenId, buyer).cancelAvailableBlock);
        market.cancelOffer(tokenId);
        vm.stopPrank();

        assertEq(market.offer(tokenId, buyer).amount, 0);
        assertEq(love20Token.balanceOf(address(market)), 0);
    }

    function testNewOwnerCanAcceptExistingOfferAfterBuy() public {
        uint256 tokenId = _mintGroupFor(seller, "MarketBuyThenAcceptOffer");
        uint256 offerAmount = 700 * 1e18;
        uint256 price = 1_000 * 1e18;
        uint256 fee = market.calculateFee(offerAmount);
        uint256 sellerProceeds = market.calculateSellerProceeds(offerAmount);

        vm.startPrank(bidder);
        love20Token.approve(address(market), offerAmount);
        market.makeOffer(tokenId, offerAmount);
        vm.stopPrank();

        vm.startPrank(seller);
        group.approve(address(market), tokenId);
        market.createListing(tokenId, price);
        vm.stopPrank();

        vm.startPrank(buyer);
        love20Token.approve(address(market), price);
        market.buyListing(tokenId);
        vm.stopPrank();

        assertEq(group.ownerOf(tokenId), buyer);
        assertEq(market.offer(tokenId, bidder).amount, offerAmount);
        assertEq(uint256(market.offer(tokenId, bidder).status), uint256(IGroupMarket.OfferStatus.Active));

        uint256 buyerBalanceBeforeAccept = love20Token.balanceOf(buyer);
        uint256 totalSupplyBeforeAccept = love20Token.totalSupply();

        vm.startPrank(buyer);
        group.approve(address(market), tokenId);
        market.acceptOffer(tokenId, bidder);
        vm.stopPrank();

        assertEq(group.ownerOf(tokenId), bidder);
        assertEq(love20Token.balanceOf(buyer), buyerBalanceBeforeAccept + sellerProceeds);
        assertEq(love20Token.totalSupply(), totalSupplyBeforeAccept - fee);
        assertEq(love20Token.balanceOf(address(market)), 0);
        assertEq(market.offer(tokenId, bidder).amount, 0);
    }

    function testCancelListingReturnsNft() public {
        uint256 tokenId = _mintGroupFor(seller, "MarketGroupTwo");
        uint256 price = 500 * 1e18;

        vm.startPrank(seller);
        group.approve(address(market), tokenId);
        market.createListing(tokenId, price);
        market.cancelListing(tokenId);
        vm.stopPrank();

        assertEq(group.ownerOf(tokenId), seller);
        assertEq(market.listing(tokenId).seller, address(0));
    }

    function testGetListingsSupportsPagination() public {
        uint256 tokenId1 = _mintGroupFor(seller, "MarketListOne");
        uint256 tokenId2 = _mintGroupFor(seller, "MarketListTwo");
        uint256 tokenId3 = _mintGroupFor(buyer, "MarketListThree");

        vm.startPrank(seller);
        group.approve(address(market), tokenId1);
        market.createListing(tokenId1, 100 * 1e18);
        group.approve(address(market), tokenId2);
        market.createListing(tokenId2, 200 * 1e18);
        vm.stopPrank();

        vm.startPrank(buyer);
        group.approve(address(market), tokenId3);
        market.createListing(tokenId3, 300 * 1e18);
        vm.stopPrank();

        IGroupMarket.ListingView[] memory firstPage = market.listings(0, 2);
        IGroupMarket.ListingView[] memory secondPage = market.listings(2, 2);

        assertEq(market.listingCount(), 3);
        assertEq(firstPage.length, 2);
        assertEq(secondPage.length, 1);

        assertEq(firstPage[0].tokenId, tokenId1);
        assertEq(firstPage[0].seller, seller);
        assertEq(firstPage[0].price, 100 * 1e18);
        assertEq(firstPage[1].tokenId, tokenId2);
        assertEq(firstPage[1].seller, seller);
        assertEq(firstPage[1].price, 200 * 1e18);
        assertEq(secondPage[0].tokenId, tokenId3);
        assertEq(secondPage[0].seller, buyer);
        assertEq(secondPage[0].price, 300 * 1e18);
    }

    function testMakeOfferAndAcceptOfferBurnsFee() public {
        uint256 tokenId = _mintGroupFor(seller, "MarketGroupThree");
        uint256 amount = 2_000 * 1e18;
        uint256 fee = market.calculateFee(amount);
        uint256 sellerProceeds = market.calculateSellerProceeds(amount);

        vm.startPrank(bidder);
        love20Token.approve(address(market), amount);
        market.makeOffer(tokenId, amount);
        vm.stopPrank();

        assertEq(market.offer(tokenId, bidder).amount, amount);
        assertEq(love20Token.balanceOf(address(market)), amount);

        uint256 sellerBalanceBefore = love20Token.balanceOf(seller);
        uint256 bidderBalanceBefore = love20Token.balanceOf(bidder);
        uint256 totalSupplyBefore = love20Token.totalSupply();

        vm.startPrank(seller);
        group.approve(address(market), tokenId);
        market.acceptOffer(tokenId, bidder);
        vm.stopPrank();

        assertEq(group.ownerOf(tokenId), bidder);
        assertEq(love20Token.balanceOf(seller), sellerBalanceBefore + sellerProceeds);
        assertEq(love20Token.balanceOf(bidder), bidderBalanceBefore);
        assertEq(love20Token.totalSupply(), totalSupplyBefore - fee);
        assertEq(love20Token.balanceOf(address(market)), 0);
        assertEq(market.offer(tokenId, bidder).amount, 0);
    }

    function testFuzzCalculateFeeMatchesTenPercent(uint256 amount) public view {
        amount = bound(amount, 0, type(uint256).max / market.FEE_BPS());

        uint256 fee = market.calculateFee(amount);
        uint256 sellerProceeds = market.calculateSellerProceeds(amount);

        assertEq(fee, (amount * market.FEE_BPS()) / market.BPS_DENOMINATOR());
        assertEq(sellerProceeds + fee, amount);
        assertLe(fee, amount);
    }

    function testCalculateFeeRevertsForMaxAmount() public {
        vm.expectRevert(stdError.arithmeticError);
        market.calculateFee(type(uint256).max);
    }

    function testFuzzMinimumReplacementAmountMatchesCeilIncrement(uint256 lowestAmount) public view {
        uint256 maxSafeLowest =
            (type(uint256).max - (market.BPS_DENOMINATOR() - 1)) / market.MIN_REPLACEMENT_INCREMENT_BPS();
        lowestAmount = bound(lowestAmount, 0, maxSafeLowest);

        uint256 minimumAmount = market.exposedMinimumReplacementAmount(lowestAmount);
        uint256 increment = (lowestAmount * market.MIN_REPLACEMENT_INCREMENT_BPS() + market.BPS_DENOMINATOR() - 1)
            / market.BPS_DENOMINATOR();

        assertEq(minimumAmount, lowestAmount + increment);
        assertGe(minimumAmount, lowestAmount);
        if (lowestAmount > 0) {
            assertGt(minimumAmount, lowestAmount);
        }
    }

    function testMinimumReplacementAmountRevertsForMaxAmount() public {
        vm.expectRevert(stdError.arithmeticError);
        market.exposedMinimumReplacementAmount(type(uint256).max);
    }

    function testIncreaseOfferOnlyTransfersDelta() public {
        uint256 tokenId = _mintGroupFor(seller, "MarketGroupThreeB");
        uint256 firstAmount = 700 * 1e18;
        uint256 secondAmount = 1_100 * 1e18;
        uint256 bidderBalanceBefore = love20Token.balanceOf(bidder);

        vm.startPrank(bidder);
        love20Token.approve(address(market), secondAmount);
        market.makeOffer(tokenId, firstAmount);
        assertEq(love20Token.balanceOf(bidder), bidderBalanceBefore - firstAmount);
        assertEq(love20Token.balanceOf(address(market)), firstAmount);

        market.makeOffer(tokenId, secondAmount);
        vm.stopPrank();

        assertEq(market.offer(tokenId, bidder).amount, secondAmount);
        assertEq(love20Token.balanceOf(bidder), bidderBalanceBefore - secondAmount);
        assertEq(love20Token.balanceOf(address(market)), secondAmount);
        assertEq(
            market.offer(tokenId, bidder).cancelAvailableBlock, block.number + market.OFFER_CANCEL_COOLDOWN_BLOCKS()
        );
        assertEq(uint256(market.offer(tokenId, bidder).status), uint256(IGroupMarket.OfferStatus.Active));
    }

    function testExistingOfferMustIncrease() public {
        uint256 tokenId = _mintGroupFor(seller, "MarketGroupThreeC");
        uint256 firstAmount = 1_200 * 1e18;

        vm.startPrank(bidder);
        love20Token.approve(address(market), firstAmount);
        market.makeOffer(tokenId, firstAmount);
        vm.expectRevert(abi.encodeWithSelector(IGroupMarketErrors.OfferMustIncrease.selector, firstAmount));
        market.makeOffer(tokenId, firstAmount);
        vm.stopPrank();
    }

    function testActiveOffersReturnsAllActiveOffersAndHighestOffer() public {
        uint256 tokenId = _mintGroupFor(seller, "MarketOfferPage");

        vm.startPrank(bidder);
        love20Token.approve(address(market), 800 * 1e18);
        market.makeOffer(tokenId, 800 * 1e18);
        vm.stopPrank();

        vm.startPrank(buyer);
        love20Token.approve(address(market), 1_300 * 1e18);
        market.makeOffer(tokenId, 1_300 * 1e18);
        vm.stopPrank();

        vm.startPrank(bidder2);
        love20Token.approve(address(market), 1_100 * 1e18);
        market.makeOffer(tokenId, 1_100 * 1e18);
        vm.stopPrank();

        IGroupMarket.OfferView[] memory offers = market.activeOffers(tokenId);
        IGroupMarket.OfferView memory highest = market.highestOffer(tokenId);

        assertEq(market.activeOfferCount(tokenId), 3);
        assertEq(offers.length, 3);

        assertEq(offers[0].bidder, bidder);
        assertEq(offers[0].amount, 800 * 1e18);
        assertEq(uint256(offers[0].status), uint256(IGroupMarket.OfferStatus.Active));
        assertEq(offers[1].bidder, buyer);
        assertEq(offers[1].amount, 1_300 * 1e18);
        assertEq(uint256(offers[1].status), uint256(IGroupMarket.OfferStatus.Active));
        assertEq(offers[2].bidder, bidder2);
        assertEq(offers[2].amount, 1_100 * 1e18);
        assertEq(uint256(offers[2].status), uint256(IGroupMarket.OfferStatus.Active));

        assertEq(highest.bidder, buyer);
        assertEq(highest.amount, 1_300 * 1e18);

        vm.roll(block.number + market.OFFER_CANCEL_COOLDOWN_BLOCKS());
        vm.prank(buyer);
        market.cancelOffer(tokenId);

        highest = market.highestOffer(tokenId);
        assertEq(highest.bidder, bidder2);
        assertEq(highest.amount, 1_100 * 1e18);
    }

    function testHighestOffersSupportsBatchQuery() public {
        uint256 tokenId1 = _mintGroupFor(seller, "MarketBatchOfferOne");
        uint256 tokenId2 = _mintGroupFor(seller, "MarketBatchOfferTwo");
        uint256 tokenId3 = _mintGroupFor(seller, "MarketBatchOfferThree");

        vm.startPrank(bidder);
        love20Token.approve(address(market), 2_000 * 1e18);
        market.makeOffer(tokenId1, 800 * 1e18);
        market.makeOffer(tokenId2, 900 * 1e18);
        vm.stopPrank();

        vm.startPrank(buyer);
        love20Token.approve(address(market), 1_500 * 1e18);
        market.makeOffer(tokenId1, 1_100 * 1e18);
        vm.stopPrank();

        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = tokenId1;
        tokenIds[1] = tokenId2;
        tokenIds[2] = tokenId3;

        IGroupMarket.OfferView[] memory highests = market.highestOffers(tokenIds);

        assertEq(highests.length, 3);

        assertEq(highests[0].bidder, buyer);
        assertEq(highests[0].amount, 1_100 * 1e18);
        assertEq(uint256(highests[0].status), uint256(IGroupMarket.OfferStatus.Active));

        assertEq(highests[1].bidder, bidder);
        assertEq(highests[1].amount, 900 * 1e18);
        assertEq(uint256(highests[1].status), uint256(IGroupMarket.OfferStatus.Active));

        assertEq(highests[2].bidder, address(0));
        assertEq(highests[2].amount, 0);
        assertEq(uint256(highests[2].status), uint256(IGroupMarket.OfferStatus.None));
    }

    function testAcceptOfferForListedToken() public {
        uint256 tokenId = _mintGroupFor(seller, "MarketGroupFour");
        uint256 listingPrice = 1_000 * 1e18;
        uint256 offerAmount = 1_500 * 1e18;

        vm.startPrank(seller);
        group.approve(address(market), tokenId);
        market.createListing(tokenId, listingPrice);
        vm.stopPrank();

        vm.startPrank(bidder);
        love20Token.approve(address(market), offerAmount);
        market.makeOffer(tokenId, offerAmount);
        vm.stopPrank();

        vm.prank(seller);
        market.acceptOffer(tokenId, bidder);

        assertEq(group.ownerOf(tokenId), bidder);
        assertEq(market.listing(tokenId).seller, address(0));
        assertEq(market.offer(tokenId, bidder).amount, 0);
        assertEq(love20Token.balanceOf(address(market)), 0);
    }

    function testCancelOfferRefundsBidder() public {
        uint256 tokenId = _mintGroupFor(seller, "MarketGroupFive");
        uint256 amount = 800 * 1e18;
        uint256 bidderBalanceBefore = love20Token.balanceOf(bidder);

        vm.startPrank(bidder);
        love20Token.approve(address(market), amount);
        market.makeOffer(tokenId, amount);
        vm.roll(block.number + market.OFFER_CANCEL_COOLDOWN_BLOCKS());
        market.cancelOffer(tokenId);
        vm.stopPrank();

        assertEq(love20Token.balanceOf(bidder), bidderBalanceBefore);
        assertEq(love20Token.balanceOf(address(market)), 0);
        assertEq(market.offer(tokenId, bidder).amount, 0);
    }

    function testCancelOfferRevertsBeforeCooldown() public {
        uint256 tokenId = _mintGroupFor(seller, "MarketGroupFiveB");
        uint256 amount = 800 * 1e18;
        uint256 cancelAvailableBlock = block.number + market.OFFER_CANCEL_COOLDOWN_BLOCKS();

        vm.startPrank(bidder);
        love20Token.approve(address(market), amount);
        market.makeOffer(tokenId, amount);
        vm.expectRevert(
            abi.encodeWithSelector(
                IGroupMarketErrors.OfferCancellationLocked.selector, block.number, cancelAvailableBlock
            )
        );
        market.cancelOffer(tokenId);
        vm.stopPrank();
    }

    function testFullOfferBookRejectsOfferBelowThreshold() public {
        uint256 tokenId = _mintGroupFor(seller, "MarketGroupFullA");
        address lowestBidder = _fillOfferBook(tokenId);
        uint256 lowestAmount = market.offer(tokenId, lowestBidder).amount;
        uint256 belowThresholdAmount = lowestAmount + 5e17;
        uint256 minimumRequiredAmount = lowestAmount + 1e18;
        address challenger = makeAddr("challenger");

        love20Token.mint(challenger, 1_000_000 * 1e18);

        vm.startPrank(challenger);
        love20Token.approve(address(market), belowThresholdAmount);
        vm.expectRevert(
            abi.encodeWithSelector(
                IGroupMarketErrors.OfferBelowMinimumToReplace.selector, lowestAmount, minimumRequiredAmount
            )
        );
        market.makeOffer(tokenId, belowThresholdAmount);
        vm.stopPrank();
    }

    function testFullOfferBookReplacesLowestOffer() public {
        uint256 tokenId = _mintGroupFor(seller, "MarketGroupFullB");
        address lowestBidder = _fillOfferBook(tokenId);
        uint256 lowestAmount = market.offer(tokenId, lowestBidder).amount;
        uint256 replacementAmount = lowestAmount + 1e18;
        uint256 lowestBidderBalanceBefore = love20Token.balanceOf(lowestBidder);
        address challenger = makeAddr("challenger2");

        love20Token.mint(challenger, 1_000_000 * 1e18);

        vm.startPrank(challenger);
        love20Token.approve(address(market), replacementAmount);
        market.makeOffer(tokenId, replacementAmount);
        vm.stopPrank();

        assertEq(market.activeOfferCount(tokenId), market.MAX_ACTIVE_OFFERS());
        assertEq(market.offer(tokenId, lowestBidder).amount, lowestAmount);
        assertEq(uint256(market.offer(tokenId, lowestBidder).status), uint256(IGroupMarket.OfferStatus.Pending));
        assertEq(market.offer(tokenId, lowestBidder).cancelAvailableBlock, 0);
        assertEq(love20Token.balanceOf(lowestBidder), lowestBidderBalanceBefore);
        assertEq(market.offer(tokenId, challenger).amount, replacementAmount);
        assertEq(uint256(market.offer(tokenId, challenger).status), uint256(IGroupMarket.OfferStatus.Active));
        assertEq(market.highestOffer(tokenId).amount, 119 * 1e18);
    }

    function testPendingOfferCanCancelImmediately() public {
        uint256 tokenId = _mintGroupFor(seller, "MarketGroupFullC");
        address lowestBidder = _fillOfferBook(tokenId);
        uint256 lowestAmount = market.offer(tokenId, lowestBidder).amount;
        uint256 lowestBidderBalanceBefore = love20Token.balanceOf(lowestBidder);
        address challenger = makeAddr("challenger3");

        love20Token.mint(challenger, 1_000_000 * 1e18);

        vm.startPrank(challenger);
        love20Token.approve(address(market), lowestAmount + 1e18);
        market.makeOffer(tokenId, lowestAmount + 1e18);
        vm.stopPrank();

        vm.prank(lowestBidder);
        market.cancelOffer(tokenId);

        assertEq(market.offer(tokenId, lowestBidder).amount, 0);
        assertEq(love20Token.balanceOf(lowestBidder), lowestBidderBalanceBefore + lowestAmount);
    }

    function testPendingOfferMustCancelBeforeReoffer() public {
        uint256 tokenId = _mintGroupFor(seller, "MarketGroupFullD");
        address lowestBidder = _fillOfferBook(tokenId);
        uint256 lowestAmount = market.offer(tokenId, lowestBidder).amount;
        address challenger = makeAddr("challenger4");

        love20Token.mint(challenger, 1_000_000 * 1e18);

        vm.startPrank(challenger);
        love20Token.approve(address(market), lowestAmount + 1e18);
        market.makeOffer(tokenId, lowestAmount + 1e18);
        vm.stopPrank();

        vm.startPrank(lowestBidder);
        love20Token.approve(address(market), 1_000_000 * 1e18);
        vm.expectRevert(IGroupMarketErrors.PendingOfferMustCancelFirst.selector);
        market.makeOffer(tokenId, lowestAmount + 2e18);
        vm.stopPrank();
    }

    function testPendingOfferCannotBeAccepted() public {
        uint256 tokenId = _mintGroupFor(seller, "MarketGroupPendingAccept");
        uint256 pendingAmount = _makePendingOfferFor(bidder, tokenId);

        vm.startPrank(seller);
        group.approve(address(market), tokenId);
        vm.expectRevert(abi.encodeWithSelector(IGroupMarketErrors.OfferNotActive.selector, tokenId, bidder));
        market.acceptOffer(tokenId, bidder);
        vm.stopPrank();

        assertEq(group.ownerOf(tokenId), seller);
        assertEq(market.offer(tokenId, bidder).amount, pendingAmount);
        assertEq(uint256(market.offer(tokenId, bidder).status), uint256(IGroupMarket.OfferStatus.Pending));
    }

    function testGetBidderOffersSupportsPaginationAndPendingStatus() public {
        uint256 activeTokenId = _mintGroupFor(seller, "MarketMyOfferActive");
        uint256 pendingTokenId = _mintGroupFor(seller, "MarketMyOfferPending");

        vm.startPrank(bidder);
        love20Token.approve(address(market), 2_000_000 * 1e18);
        market.makeOffer(activeTokenId, 700 * 1e18);
        vm.stopPrank();

        uint256 pendingAmount = _makePendingOfferFor(bidder, pendingTokenId);

        IGroupMarket.BidderOfferView[] memory firstPage = _bidderOffers(bidder, 0, 1);
        IGroupMarket.BidderOfferView[] memory secondPage = _bidderOffers(bidder, 1, 2);

        assertEq(_bidderOfferCount(bidder), 2);
        assertEq(firstPage.length, 1);
        assertEq(secondPage.length, 1);

        assertEq(firstPage[0].tokenId, activeTokenId);
        assertEq(firstPage[0].amount, 700 * 1e18);
        assertEq(uint256(firstPage[0].status), uint256(IGroupMarket.OfferStatus.Active));

        assertEq(secondPage[0].tokenId, pendingTokenId);
        assertEq(secondPage[0].amount, pendingAmount);
        assertEq(uint256(secondPage[0].status), uint256(IGroupMarket.OfferStatus.Pending));
        assertEq(secondPage[0].cancelAvailableBlock, 0);
    }

    function testBidderOfferListUpdatesAfterPendingAcceptAndCancel() public {
        uint256 activeTokenId = _mintGroupFor(seller, "MarketMyOfferCleanupA");
        uint256 pendingTokenId = _mintGroupFor(seller, "MarketMyOfferCleanupB");

        vm.startPrank(bidder);
        love20Token.approve(address(market), 2_000_000 * 1e18);
        market.makeOffer(activeTokenId, 900 * 1e18);
        vm.stopPrank();

        _makePendingOfferFor(bidder, pendingTokenId);

        vm.prank(bidder);
        market.cancelOffer(pendingTokenId);

        vm.roll(block.number + market.OFFER_CANCEL_COOLDOWN_BLOCKS());
        vm.prank(bidder);
        market.cancelOffer(activeTokenId);

        assertEq(_bidderOfferCount(bidder), 0);
        assertEq(_bidderOffers(bidder, 0, 10).length, 0);
    }

    function testSameBidderCanCancelOffersAcrossMultipleTokenIds() public {
        uint256 tokenId1 = _mintGroupFor(seller, "MarketMultiCancelA");
        uint256 tokenId2 = _mintGroupFor(seller, "MarketMultiCancelB");
        uint256 tokenId3 = _mintGroupFor(seller, "MarketMultiCancelC");
        uint256 amount1 = 100 * 1e18;
        uint256 amount2 = 200 * 1e18;
        uint256 amount3 = 300 * 1e18;
        uint256 totalAmount = amount1 + amount2 + amount3;
        uint256 bidderBalanceBefore = love20Token.balanceOf(bidder);

        vm.startPrank(bidder);
        love20Token.approve(address(market), totalAmount);
        market.makeOffer(tokenId1, amount1);
        market.makeOffer(tokenId2, amount2);
        market.makeOffer(tokenId3, amount3);
        vm.stopPrank();

        assertEq(_bidderOfferCount(bidder), 3);
        assertEq(love20Token.balanceOf(address(market)), totalAmount);

        vm.roll(block.number + market.OFFER_CANCEL_COOLDOWN_BLOCKS());

        vm.startPrank(bidder);
        market.cancelOffer(tokenId1);
        market.cancelOffer(tokenId2);
        market.cancelOffer(tokenId3);
        vm.stopPrank();

        assertEq(_bidderOfferCount(bidder), 0);
        assertEq(_bidderOffers(bidder, 0, 10).length, 0);
        assertEq(market.offer(tokenId1, bidder).amount, 0);
        assertEq(market.offer(tokenId2, bidder).amount, 0);
        assertEq(market.offer(tokenId3, bidder).amount, 0);
        assertEq(love20Token.balanceOf(bidder), bidderBalanceBefore);
        assertEq(love20Token.balanceOf(address(market)), 0);
    }

    function testOwnerCanMakeOfferForOwnToken() public {
        uint256 tokenId = _mintGroupFor(seller, "MarketGroupSix");

        vm.startPrank(seller);
        love20Token.approve(address(market), 100 * 1e18);
        market.makeOffer(tokenId, 100 * 1e18);
        vm.stopPrank();

        assertEq(market.offer(tokenId, seller).amount, 100 * 1e18);
        assertEq(uint256(market.offer(tokenId, seller).status), uint256(IGroupMarket.OfferStatus.Active));
    }

    function testOwnerCannotAcceptOwnOffer() public {
        uint256 tokenId = _mintGroupFor(seller, "MarketGroupSelfOffer");

        vm.startPrank(seller);
        love20Token.approve(address(market), 100 * 1e18);
        market.makeOffer(tokenId, 100 * 1e18);
        vm.expectRevert(abi.encodeWithSelector(IGroupMarketErrors.CannotAcceptOwnOffer.selector, tokenId));
        market.acceptOffer(tokenId, seller);
        vm.stopPrank();
    }

    function testMakeOfferRevertsForNonexistentToken() public {
        uint256 nonexistentTokenId = 999_999;

        vm.startPrank(bidder);
        love20Token.approve(address(market), 100 * 1e18);
        vm.expectRevert();
        market.makeOffer(nonexistentTokenId, 100 * 1e18);
        vm.stopPrank();
    }

    function testAcceptOfferRevertsWhenTokenNotApproved() public {
        uint256 tokenId = _mintGroupFor(seller, "MarketGroupSeven");
        uint256 amount = 900 * 1e18;

        vm.startPrank(bidder);
        love20Token.approve(address(market), amount);
        market.makeOffer(tokenId, amount);
        vm.stopPrank();

        vm.startPrank(seller);
        vm.expectRevert(abi.encodeWithSelector(IGroupMarketErrors.TokenNotApproved.selector, tokenId));
        market.acceptOffer(tokenId, bidder);
        vm.stopPrank();
    }

    function _mintGroupFor(address user, string memory groupName) internal returns (uint256 tokenId) {
        uint256 mintCost = group.calculateMintCost(groupName);

        vm.startPrank(user);
        love20Token.approve(address(group), mintCost);
        (tokenId,) = group.mint(groupName);
        vm.stopPrank();
    }

    function _fillOfferBook(uint256 tokenId) internal returns (address lowestBidder) {
        for (uint256 i = 0; i < market.MAX_ACTIVE_OFFERS(); i++) {
            address bidderAddress = vm.addr(100 + i);
            uint256 amount = (100 + i) * 1e18;

            love20Token.mint(bidderAddress, 1_000_000 * 1e18);

            vm.startPrank(bidderAddress);
            love20Token.approve(address(market), amount);
            market.makeOffer(tokenId, amount);
            vm.stopPrank();

            if (i == 0) {
                lowestBidder = bidderAddress;
            }
        }
    }

    function _makePendingOfferFor(address pendingBidder, uint256 tokenId) internal returns (uint256 pendingAmount) {
        pendingAmount = 100 * 1e18;

        vm.startPrank(pendingBidder);
        love20Token.approve(address(market), pendingAmount);
        market.makeOffer(tokenId, pendingAmount);
        vm.stopPrank();

        for (uint256 i = 0; i < market.MAX_ACTIVE_OFFERS() - 1; i++) {
            address bidderAddress = vm.addr(1_000 + i);
            uint256 amount = (101 + i) * 1e18;

            love20Token.mint(bidderAddress, 1_000_000 * 1e18);

            vm.startPrank(bidderAddress);
            love20Token.approve(address(market), amount);
            market.makeOffer(tokenId, amount);
            vm.stopPrank();
        }

        address challenger = makeAddr("pendingChallenger");
        love20Token.mint(challenger, 1_000_000 * 1e18);

        vm.startPrank(challenger);
        love20Token.approve(address(market), 120 * 1e18);
        market.makeOffer(tokenId, 120 * 1e18);
        vm.stopPrank();

        assertEq(uint256(market.offer(tokenId, pendingBidder).status), uint256(IGroupMarket.OfferStatus.Pending));
    }

    function _bidderOfferCount(address account) internal view returns (uint256) {
        return market.bidderOfferCount(account);
    }

    function _bidderOffers(address account, uint256 offset, uint256 limit)
        internal
        view
        returns (IGroupMarket.BidderOfferView[] memory)
    {
        return market.bidderOffers(account, offset, limit);
    }
}
