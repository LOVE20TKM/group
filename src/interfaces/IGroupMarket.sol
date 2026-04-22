// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ILOVE20Group} from "./ILOVE20Group.sol";
import {ILOVE20Token} from "./ILOVE20Token.sol";

interface IGroupMarketEvents {
    event Initialized(address indexed group, address indexed love20Token);

    event ListingCreated(uint256 indexed tokenId, address indexed seller, uint256 price);

    event ListingCancelled(uint256 indexed tokenId, address indexed seller);

    event ListingPurchased(
        uint256 indexed tokenId,
        address indexed seller,
        address indexed buyer,
        uint256 price,
        uint256 fee,
        uint256 sellerProceeds
    );

    event OfferCreated(uint256 indexed tokenId, address indexed bidder, uint256 amount);

    event OfferUpdated(uint256 indexed tokenId, address indexed bidder, uint256 previousAmount, uint256 newAmount);

    event OfferReplaced(
        uint256 indexed tokenId,
        address indexed displacedBidder,
        address indexed newBidder,
        uint256 displacedAmount,
        uint256 newAmount
    );

    event OfferCancelled(uint256 indexed tokenId, address indexed bidder, uint256 amount);

    event OfferAccepted(
        uint256 indexed tokenId,
        address indexed seller,
        address indexed bidder,
        uint256 amount,
        uint256 fee,
        uint256 sellerProceeds
    );
}

interface IGroupMarketErrors {
    error InvalidAddress();
    error InvalidAmount();
    error ListingAlreadyExists(uint256 tokenId);
    error ListingNotFound(uint256 tokenId);
    error OfferNotFound(uint256 tokenId, address bidder);
    error OfferNotActive(uint256 tokenId, address bidder);
    error NotTokenOwner(uint256 tokenId, address caller);
    error NotListingSeller(uint256 tokenId, address caller);
    error CannotBuyOwnListing(uint256 tokenId);
    error CannotAcceptOwnOffer(uint256 tokenId);
    error TokenNotApproved(uint256 tokenId);
    error OfferMustIncrease(uint256 currentAmount);
    error OfferCancellationLocked(uint256 currentBlock, uint256 cancelAvailableBlock);
    error OfferBelowMinimumToReplace(uint256 currentLowestAmount, uint256 minimumRequiredAmount);
    error PendingOfferMustCancelFirst();
}

interface IGroupMarket is IGroupMarketEvents, IGroupMarketErrors {
    enum OfferStatus {
        None,
        Active,
        Pending
    }

    struct Listing {
        address seller;
        uint256 price;
    }

    struct ListingView {
        uint256 tokenId;
        address seller;
        uint256 price;
    }

    struct Offer {
        uint256 amount;
        uint256 cancelAvailableBlock;
        OfferStatus status;
    }

    struct OfferView {
        address bidder;
        uint256 amount;
        uint256 cancelAvailableBlock;
        OfferStatus status;
    }

    struct BidderOfferView {
        uint256 tokenId;
        uint256 amount;
        uint256 cancelAvailableBlock;
        OfferStatus status;
    }

    function group() external view returns (ILOVE20Group);

    function love20Token() external view returns (ILOVE20Token);

    function FEE_BPS() external view returns (uint256);

    function BPS_DENOMINATOR() external view returns (uint256);

    function MAX_ACTIVE_OFFERS() external view returns (uint256);

    function MIN_REPLACEMENT_INCREMENT_BPS() external view returns (uint256);

    function OFFER_CANCEL_COOLDOWN_BLOCKS() external view returns (uint256);

    function createListing(uint256 tokenId, uint256 price) external;

    function cancelListing(uint256 tokenId) external;

    function buy(uint256 tokenId) external;

    function makeOffer(uint256 tokenId, uint256 amount) external;

    function cancelOffer(uint256 tokenId) external;

    function acceptOffer(uint256 tokenId, address bidder) external;

    function listing(uint256 tokenId) external view returns (Listing memory);

    function offer(uint256 tokenId, address bidder) external view returns (Offer memory);

    function listingCount() external view returns (uint256);

    function activeOfferCount(uint256 tokenId) external view returns (uint256);

    function bidderOfferCount(address bidder) external view returns (uint256);

    function listings(uint256 offset, uint256 limit) external view returns (ListingView[] memory);

    function activeOffers(uint256 tokenId) external view returns (OfferView[] memory);

    function bidderOffers(address bidder, uint256 offset, uint256 limit)
        external
        view
        returns (BidderOfferView[] memory);

    function highestOffer(uint256 tokenId) external view returns (OfferView memory);

    function calculateFee(uint256 amount) external pure returns (uint256);

    function calculateSellerProceeds(uint256 amount) external pure returns (uint256);
}
