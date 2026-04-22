// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20Group} from "./interfaces/ILOVE20Group.sol";
import {ILOVE20Token} from "./interfaces/ILOVE20Token.sol";
import {IGroupMarket} from "./interfaces/IGroupMarket.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title GroupMarket
 * @notice Marketplace for LOVE20 Group NFTs settled in LOVE20 token
 * @dev 10% trading fee is burned through LOVE20Token, returning it to unminted supply
 */
contract GroupMarket is ERC721Holder, ReentrancyGuard, IGroupMarket {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    uint256 public constant FEE_BPS = 1_000;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MAX_ACTIVE_OFFERS = 20;
    uint256 public constant MIN_REPLACEMENT_INCREMENT_BPS = 100;
    uint256 public constant OFFER_CANCEL_COOLDOWN_BLOCKS = 30_126;

    ILOVE20Group public immutable group;
    ILOVE20Token public immutable love20Token;

    struct OfferExtremes {
        address highestBidder;
        address lowestBidder;
    }

    mapping(uint256 => Listing) internal _listings;
    mapping(uint256 => mapping(address => Offer)) internal _offers;
    EnumerableSet.UintSet internal _listedTokenIds;
    mapping(uint256 => EnumerableSet.AddressSet) internal _offerBidders;
    mapping(address => EnumerableSet.UintSet) internal _bidderOfferTokenIds;
    mapping(uint256 => OfferExtremes) internal _offerExtremes;

    constructor(ILOVE20Group group_, ILOVE20Token love20Token_) {
        if (address(group_) == address(0) || address(love20Token_) == address(0)) {
            revert InvalidAddress();
        }

        group = group_;
        love20Token = love20Token_;

        emit Initialized(address(group_), address(love20Token_));
    }

    function createListing(uint256 tokenId, uint256 price) external nonReentrant {
        if (price == 0) revert InvalidAmount();
        if (_listings[tokenId].seller != address(0)) {
            revert ListingAlreadyExists(tokenId);
        }

        IERC721 groupNft = IERC721(address(group));
        if (groupNft.ownerOf(tokenId) != msg.sender) {
            revert NotTokenOwner(tokenId, msg.sender);
        }

        _listings[tokenId] = Listing({seller: msg.sender, price: price});
        _listedTokenIds.add(tokenId);
        groupNft.safeTransferFrom(msg.sender, address(this), tokenId);

        emit ListingCreated(tokenId, msg.sender, price);
    }

    function cancelListing(uint256 tokenId) external nonReentrant {
        Listing memory listing_ = _requireListing(tokenId);
        if (listing_.seller != msg.sender) {
            revert NotListingSeller(tokenId, msg.sender);
        }

        delete _listings[tokenId];
        _listedTokenIds.remove(tokenId);
        IERC721(address(group)).safeTransferFrom(address(this), msg.sender, tokenId);

        emit ListingCancelled(tokenId, msg.sender);
    }

    function buy(uint256 tokenId) external nonReentrant {
        Listing memory listing_ = _requireListing(tokenId);
        if (listing_.seller == msg.sender) revert CannotBuyOwnListing(tokenId);

        delete _listings[tokenId];
        _listedTokenIds.remove(tokenId);

        IERC20 token = IERC20(address(love20Token));
        token.safeTransferFrom(msg.sender, address(this), listing_.price);

        IERC721(address(group)).safeTransferFrom(address(this), msg.sender, tokenId);

        (uint256 fee, uint256 sellerProceeds) = _payoutAndBurn(listing_.seller, listing_.price);

        emit ListingPurchased(tokenId, listing_.seller, msg.sender, listing_.price, fee, sellerProceeds);
    }

    function makeOffer(uint256 tokenId, uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        IERC721(address(group)).ownerOf(tokenId);

        Offer storage existingOffer = _offers[tokenId][msg.sender];
        uint256 previousAmount = existingOffer.amount;

        IERC20 token = IERC20(address(love20Token));
        if (previousAmount != 0) {
            if (existingOffer.status == OfferStatus.Pending) {
                revert PendingOfferMustCancelFirst();
            }
            if (amount <= previousAmount) revert OfferMustIncrease(previousAmount);

            token.safeTransferFrom(msg.sender, address(this), amount - previousAmount);
            existingOffer.amount = amount;
            existingOffer.cancelAvailableBlock = block.number + OFFER_CANCEL_COOLDOWN_BLOCKS;
            existingOffer.status = OfferStatus.Active;

            _refreshOfferExtremes(tokenId);
            emit OfferUpdated(tokenId, msg.sender, previousAmount, amount);
            return;
        }

        EnumerableSet.AddressSet storage bidders = _offerBidders[tokenId];
        uint256 currentActiveOfferCount = bidders.length();

        if (currentActiveOfferCount < MAX_ACTIVE_OFFERS) {
            bidders.add(msg.sender);
            _bidderOfferTokenIds[msg.sender].add(tokenId);
            token.safeTransferFrom(msg.sender, address(this), amount);
            _offers[tokenId][msg.sender] = Offer({
                amount: amount,
                cancelAvailableBlock: block.number + OFFER_CANCEL_COOLDOWN_BLOCKS,
                status: OfferStatus.Active
            });

            _refreshOfferExtremes(tokenId);
            emit OfferCreated(tokenId, msg.sender, amount);
        } else {
            address lowestBidder = _offerExtremes[tokenId].lowestBidder;
            uint256 lowestAmount = _offers[tokenId][lowestBidder].amount;
            uint256 minimumRequiredAmount = _minimumReplacementAmount(lowestAmount);

            if (amount < minimumRequiredAmount) {
                revert OfferBelowMinimumToReplace(lowestAmount, minimumRequiredAmount);
            }

            token.safeTransferFrom(msg.sender, address(this), amount);

            _offers[tokenId][lowestBidder].cancelAvailableBlock = 0;
            _offers[tokenId][lowestBidder].status = OfferStatus.Pending;
            bidders.remove(lowestBidder);

            bidders.add(msg.sender);
            _bidderOfferTokenIds[msg.sender].add(tokenId);
            _offers[tokenId][msg.sender] = Offer({
                amount: amount,
                cancelAvailableBlock: block.number + OFFER_CANCEL_COOLDOWN_BLOCKS,
                status: OfferStatus.Active
            });

            _refreshOfferExtremes(tokenId);
            emit OfferReplaced(tokenId, lowestBidder, msg.sender, lowestAmount, amount);
        }
    }

    function cancelOffer(uint256 tokenId) external nonReentrant {
        Offer memory offer_ = _requireOffer(tokenId, msg.sender);
        if (offer_.status == OfferStatus.Active && block.number < offer_.cancelAvailableBlock) {
            revert OfferCancellationLocked(block.number, offer_.cancelAvailableBlock);
        }

        delete _offers[tokenId][msg.sender];
        _bidderOfferTokenIds[msg.sender].remove(tokenId);
        if (offer_.status == OfferStatus.Active) {
            _offerBidders[tokenId].remove(msg.sender);
            _refreshOfferExtremes(tokenId);
        }
        IERC20(address(love20Token)).safeTransfer(msg.sender, offer_.amount);

        emit OfferCancelled(tokenId, msg.sender, offer_.amount);
    }

    function acceptOffer(uint256 tokenId, address bidder) external nonReentrant {
        if (bidder == msg.sender) revert CannotAcceptOwnOffer(tokenId);

        Offer memory offer_ = _requireOffer(tokenId, bidder);
        if (offer_.status != OfferStatus.Active) revert OfferNotActive(tokenId, bidder);
        delete _offers[tokenId][bidder];
        _bidderOfferTokenIds[bidder].remove(tokenId);
        _offerBidders[tokenId].remove(bidder);
        _refreshOfferExtremes(tokenId);

        Listing memory listing_ = _listings[tokenId];
        IERC721 groupNft = IERC721(address(group));

        if (listing_.seller != address(0)) {
            if (listing_.seller != msg.sender) {
                revert NotListingSeller(tokenId, msg.sender);
            }
            delete _listings[tokenId];
            _listedTokenIds.remove(tokenId);
            groupNft.safeTransferFrom(address(this), bidder, tokenId);
        } else {
            if (groupNft.ownerOf(tokenId) != msg.sender) {
                revert NotTokenOwner(tokenId, msg.sender);
            }
            if (!_isApproved(groupNft, tokenId, msg.sender)) {
                revert TokenNotApproved(tokenId);
            }
            groupNft.safeTransferFrom(msg.sender, bidder, tokenId);
        }

        (uint256 fee, uint256 sellerProceeds) = _payoutAndBurn(msg.sender, offer_.amount);

        emit OfferAccepted(tokenId, msg.sender, bidder, offer_.amount, fee, sellerProceeds);
    }

    function listing(uint256 tokenId) external view returns (Listing memory) {
        return _listings[tokenId];
    }

    function offer(uint256 tokenId, address bidder) external view returns (Offer memory) {
        return _offers[tokenId][bidder];
    }

    function listingCount() external view returns (uint256) {
        return _listedTokenIds.length();
    }

    function activeOfferCount(uint256 tokenId) external view returns (uint256) {
        return _offerBidders[tokenId].length();
    }

    function bidderOfferCount(address bidder) external view returns (uint256) {
        return _bidderOfferTokenIds[bidder].length();
    }

    function listings(uint256 offset, uint256 limit) external view returns (ListingView[] memory page) {
        uint256 total = _listedTokenIds.length();
        uint256 size = _pageSize(total, offset, limit);
        page = new ListingView[](size);

        for (uint256 i = 0; i < size; i++) {
            uint256 tokenId = _listedTokenIds.at(offset + i);
            Listing memory listing_ = _listings[tokenId];
            page[i] = ListingView({tokenId: tokenId, seller: listing_.seller, price: listing_.price});
        }
    }

    function activeOffers(uint256 tokenId) external view returns (OfferView[] memory page) {
        EnumerableSet.AddressSet storage bidders = _offerBidders[tokenId];
        uint256 total = bidders.length();
        page = new OfferView[](total);

        for (uint256 i = 0; i < total; i++) {
            address bidder = bidders.at(i);
            Offer memory offer_ = _offers[tokenId][bidder];
            page[i] = OfferView({
                bidder: bidder,
                amount: offer_.amount,
                cancelAvailableBlock: offer_.cancelAvailableBlock,
                status: offer_.status
            });
        }
    }

    function bidderOffers(address bidder, uint256 offset, uint256 limit)
        external
        view
        returns (BidderOfferView[] memory page)
    {
        EnumerableSet.UintSet storage tokenIds = _bidderOfferTokenIds[bidder];
        uint256 total = tokenIds.length();
        uint256 size = _pageSize(total, offset, limit);
        page = new BidderOfferView[](size);

        for (uint256 i = 0; i < size; i++) {
            uint256 tokenId = tokenIds.at(offset + i);
            Offer memory offer_ = _offers[tokenId][bidder];
            page[i] = BidderOfferView({
                tokenId: tokenId,
                amount: offer_.amount,
                cancelAvailableBlock: offer_.cancelAvailableBlock,
                status: offer_.status
            });
        }
    }

    function highestOffer(uint256 tokenId) external view returns (OfferView memory highest) {
        address highestBidder = _offerExtremes[tokenId].highestBidder;
        if (highestBidder != address(0)) {
            Offer memory offer_ = _offers[tokenId][highestBidder];
            highest = OfferView({
                bidder: highestBidder,
                amount: offer_.amount,
                cancelAvailableBlock: offer_.cancelAvailableBlock,
                status: offer_.status
            });
        }
    }

    function calculateFee(uint256 amount) public pure returns (uint256) {
        return (amount * FEE_BPS) / BPS_DENOMINATOR;
    }

    function calculateSellerProceeds(uint256 amount) public pure returns (uint256) {
        return amount - calculateFee(amount);
    }

    function _requireListing(uint256 tokenId) internal view returns (Listing memory listing_) {
        listing_ = _listings[tokenId];
        if (listing_.seller == address(0)) revert ListingNotFound(tokenId);
    }

    function _requireOffer(uint256 tokenId, address bidder) internal view returns (Offer memory offer_) {
        offer_ = _offers[tokenId][bidder];
        if (offer_.amount == 0) revert OfferNotFound(tokenId, bidder);
    }

    function _isApproved(IERC721 groupNft, uint256 tokenId, address owner) internal view returns (bool) {
        return groupNft.getApproved(tokenId) == address(this) || groupNft.isApprovedForAll(owner, address(this));
    }

    function _payoutAndBurn(address seller, uint256 amount) internal returns (uint256 fee, uint256 sellerProceeds) {
        fee = calculateFee(amount);
        sellerProceeds = amount - fee;

        if (fee != 0) {
            love20Token.burn(fee);
        }

        if (sellerProceeds != 0) {
            IERC20(address(love20Token)).safeTransfer(seller, sellerProceeds);
        }
    }

    function _refreshOfferExtremes(uint256 tokenId) internal {
        EnumerableSet.AddressSet storage bidders = _offerBidders[tokenId];
        uint256 total = bidders.length();
        OfferExtremes storage extremes = _offerExtremes[tokenId];

        if (total == 0) {
            extremes.highestBidder = address(0);
            extremes.lowestBidder = address(0);
            return;
        }

        address highestBidder = bidders.at(0);
        address lowestBidder = highestBidder;
        uint256 highestAmount = _offers[tokenId][highestBidder].amount;
        uint256 lowestAmount = highestAmount;

        for (uint256 i = 1; i < total; i++) {
            address bidder = bidders.at(i);
            uint256 amount = _offers[tokenId][bidder].amount;

            if (amount > highestAmount) {
                highestBidder = bidder;
                highestAmount = amount;
            }

            if (amount < lowestAmount) {
                lowestBidder = bidder;
                lowestAmount = amount;
            }
        }

        extremes.highestBidder = highestBidder;
        extremes.lowestBidder = lowestBidder;
    }

    function _minimumReplacementAmount(uint256 lowestAmount) internal pure returns (uint256) {
        uint256 increment = (lowestAmount * MIN_REPLACEMENT_INCREMENT_BPS + BPS_DENOMINATOR - 1) / BPS_DENOMINATOR;
        return lowestAmount + increment;
    }

    function _pageSize(uint256 total, uint256 offset, uint256 limit) internal pure returns (uint256) {
        if (offset >= total || limit == 0) {
            return 0;
        }

        uint256 remaining = total - offset;
        if (limit < remaining) {
            return limit;
        }
        return remaining;
    }
}
