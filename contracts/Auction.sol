// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "./IERC721.sol";
import "./IERC20.sol";
import "./utils/AddressUtils.sol";
import "./utils/Ownable.sol";
import "./utils/SafeMath.sol";
import "./Globals.sol";

contract Auction is Ownable {
    using SafeMath for uint256;
    using AddressUtils for address;

    enum AuctionStatus {NONE, PENDING, ACTIVE, FINISHED}

    struct AuctionInfo {
        address creator;
        uint256 startPrice;
        uint256 buyNowPrice;
        uint256 startTime;
        uint256 duration;
        uint256 durationIncrement;
        uint256 bidIncrement;
        string description;
        address assetAddress;
        uint256 assetId;
        address currencyAddress;

        address currentBidder;
        uint256 highestBid;

        bool lotBought;
        bool repaymentTransferred;
        bool lotTransferred;

        AuctionStatus status;
    }

    event AuctionCreated(address _creator, address _asset, uint256 assetId, address _token, uint256 _auctionId);
    event AuctionClosed(uint256 _auctionId);
    event AuctionBid(uint256 _auctionId, address _bidder, uint256 _amount);
    event TokensClaimed(uint256 _auctionId, address _creator);
    event AssetClaimed(uint256 _auctionId, address _winner);

    uint256 private countOfAuctions;
    mapping(uint256 => AuctionInfo) private auctions;
    mapping(uint256 => mapping(address => uint256)) public userBids;

    constructor() {}

    function createAuction(
        address _assetAddress,
        uint256 _assetId,
        address _currencyAddress,
        uint256 _startPrice,
        uint256 _buyNowPrice,
        uint256 _startTime,
        uint256 _duration,
        uint256 _durationIncrement,
        uint256 _bidIncrement,
        string memory _description
    ) public returns (uint256) {
        require(_assetAddress.isContract(), "Given asset is not a contract");
        IERC721 _asset = IERC721(_assetAddress);
        require(_asset.ownerOf(_assetId) == msg.sender, "Is not owner of asset");
        require(_asset.getApproved(_assetId) == address(this), "Asset is not approved");
        require(_currencyAddress.isContract(), "Given token is not a contract");
        require(_startPrice != 0, "Invalid start price");
        require(_buyNowPrice >= _startPrice, "Buy now price should higher or equal to start price");
        require(_startTime > block.timestamp, "Invalid start time of auction");
        require(_duration != 0, "Invalid auction duration");
        require(_durationIncrement != 0, "Invalid auction increment");
        require(0 < _bidIncrement && _bidIncrement <= getDecimal(), "Invalid bid increment");

        AuctionInfo memory _auction;
        _auction.creator = msg.sender;
        _auction.assetAddress = _assetAddress;
        _auction.assetId = _assetId;
        _auction.currencyAddress = _currencyAddress;
        _auction.startPrice = _startPrice;
        _auction.buyNowPrice = _buyNowPrice;
        _auction.startTime = _startTime;
        _auction.duration = _duration;
        _auction.bidIncrement = _bidIncrement;
        _auction.description = _description;

        uint256 _auctionId = countOfAuctions;
        auctions[_auctionId] = _auction;
        countOfAuctions++;

        emit AuctionCreated(_auction.creator, _auction.assetAddress, _auction.assetId, _auction.currencyAddress, _auctionId);

        return _auctionId;
    }

    function getStatus(uint256 _auctionId) public view returns (AuctionStatus) {
        AuctionInfo memory _auction = auctions[_auctionId];

        if (_auction.creator == address(0)) {
            return AuctionStatus.NONE;
        }
        if (_auction.lotBought) {
            return AuctionStatus.FINISHED;
        }
        if (block.timestamp < _auction.startTime) {
            return AuctionStatus.PENDING;
        }
        if (block.timestamp < _auction.startTime.add(_auction.duration)) {
            return AuctionStatus.ACTIVE;
        }

        return AuctionStatus.FINISHED;
    }

    function getAuctionInfo(uint256 _auctionId) public shouldExist(_auctionId) view returns (AuctionInfo memory) {
        return auctions[_auctionId];
    }

    function getUserLatestBid(uint256 _auctionId) public shouldBeActive(_auctionId) view returns (uint256) {
        return userBids[_auctionId][msg.sender];
    }

    function bid(uint256 _auctionId, uint256 _amount) public shouldBeActive(_auctionId) {
        require(
            _amount >= _getRaisingBid(_auctionId),
            "Bid amount must exceed the highest bid by the minimum increment percentage or more."
        );

        AuctionInfo memory _auction = auctions[_auctionId];
        IERC20 _token = IERC20(_auction.currencyAddress);

        bool _ok = _token.transferFrom(msg.sender, address(this), _amount);
        require(_ok, "Failed to transfer tokens to bid");

        if (_auction.highestBid != 0) {
            _ok = _token.transfer(
                _auction.currentBidder,
                _auction.highestBid
            );
            require(_ok, "Failed to pay back");
        }

        _auction.highestBid = _amount;
        _auction.currentBidder = msg.sender;
        _auction.duration = _auction.duration.add(_auction.durationIncrement);

        auctions[_auctionId] = _auction;
        userBids[_auctionId][msg.sender] = _amount;

        emit AuctionBid(_auctionId, msg.sender, _amount);
    }

    function getRaisingBid(uint256 _auctionId) public shouldBeActive(_auctionId) view returns (uint256) {
        return _getRaisingBid(_auctionId);
    }

    function _getRaisingBid(uint256 _auctionId) internal view returns (uint256) {
        AuctionInfo memory _auction = auctions[_auctionId];
        uint256 _highestBid = _auction.highestBid;
        return _highestBid.mul(_auction.bidIncrement).div(getDecimal()).add(_highestBid);
    }

    function claimRepayment(uint256 _auctionId) public shouldBeFinished(_auctionId) {
        AuctionInfo memory _auction = auctions[_auctionId];
        require(_auction.creator == msg.sender, "Sender is not auction owner");
        require(!_auction.repaymentTransferred, "The repayment has already been transferred");

        bool _ok = IERC20(_auction.currencyAddress).transfer(_auction.creator, _auction.highestBid);
        require(_ok, "Failed to transfer the repayment");

        auctions[_auctionId].repaymentTransferred = true;

        emit TokensClaimed(_auctionId, _auction.creator);
    }

    function claimLot(uint256 _auctionId) public shouldBeFinished(_auctionId) {
        AuctionInfo memory _auction = auctions[_auctionId];
        require(_auction.currentBidder == msg.sender, "Sender is not winner");
        require(!_auction.lotTransferred, "The lot has already been transferred");

        IERC721(_auction.assetAddress).transferFrom(_auction.creator, _auction.currentBidder, _auction.assetId);

        auctions[_auctionId].lotTransferred = true;

        emit AssetClaimed(_auctionId, msg.sender);
    }

    function buyNow(uint256 _auctionId) public shouldBeActive(_auctionId) {
        AuctionInfo memory _auction = auctions[_auctionId];

        bool _ok = IERC20(_auction.currencyAddress).transferFrom(msg.sender, address(this), _auction.buyNowPrice);
        require(_ok, "Failed to transfer the repayment");

        IERC721(_auction.assetAddress).transferFrom(_auction.creator, _auction.currentBidder, _auction.assetId);

        _auction.lotBought = true;
        _auction.lotTransferred = true;
        auctions[_auctionId] = _auction;

        emit AssetClaimed(_auctionId, msg.sender);
    }

    function closeAuction(uint256 _auctionId) public onlyOwner shouldBeFinished(_auctionId) {
        AuctionInfo memory _auction = auctions[_auctionId];

        if (!_auction.repaymentTransferred) {
            bool _ok = IERC20(_auction.currencyAddress).transferFrom(msg.sender, address(this), _auction.buyNowPrice);
            require(_ok, "Failed to transfer the repayment");
            _auction.repaymentTransferred = true;
        }
        if (!_auction.lotTransferred) {
            IERC721(_auction.assetAddress).transferFrom(_auction.creator, _auction.currentBidder, _auction.assetId);
            _auction.lotTransferred = true;
        }

        auctions[_auctionId] = _auction;

        emit AuctionClosed(_auctionId);
    }

    modifier shouldBeActive(uint256 _auctionId) {
        require(
            getStatus(_auctionId) == AuctionStatus.ACTIVE,
            "Auction is not active"
        );
        _;
    }

    modifier shouldBeFinished(uint256 _auctionId) {
        require(
            getStatus(_auctionId) == AuctionStatus.FINISHED,
            "Auction is not finished"
        );
        _;
    }

    modifier shouldExist(uint256 _auctionId) {
        require(
            getStatus(_auctionId) != AuctionStatus.NONE,
            "Auction does not exist"
        );
        _;
    }
}
