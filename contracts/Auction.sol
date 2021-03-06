// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./Globals.sol";

contract Auction {
    using SafeMath for uint256;
    using Address for address;

    enum AuctionStatus {NONE, PENDING, ACTIVE, FINISHED, CLOSED}

    struct AuctionInfo {
        address creator;
        uint256 startPrice;
        uint256 buyNowPrice;
        uint256 startTime;
        uint256 duration;
        uint256 durationIncrement;
        uint256 bidIncrement;
        string description;
        address tokenAddress;
        uint256 tokenId;
        address currencyAddress;

        address currentBidder;
        uint256 highestBid;

        bool lotBought;
        bool repaymentTransferred;
        bool lotTransferred;
    }

    event AuctionCreated(address _creator, address _tokenAddress, uint256 _tokenId, address _currencyAddress, uint256 _auctionId);
    event AuctionClosed(uint256 _auctionId);
    event AuctionBid(uint256 _auctionId, address _bidder, uint256 _amount);
    event RepaymentTransferred(uint256 _auctionId, address _creator);
    event LotTransferred(uint256 _auctionId, address _winner);

    uint256 public countOfAuctions;
    mapping(uint256 => AuctionInfo) private auctions;

    constructor() {}

    function createAuction(
        address _tokenAddress,
        uint256 _tokenId,
        address _currencyAddress,
        uint256 _startPrice,
        uint256 _buyNowPrice,
        uint256 _startTime,
        uint256 _duration,
        uint256 _durationIncrement,
        uint256 _bidIncrement,
        string memory _description
    ) external returns (uint256) {
        require(_tokenAddress.isContract(), "Given token is not a contract");
        IERC721 _tokenContract = IERC721(_tokenAddress);
        require(_tokenContract.ownerOf(_tokenId) == msg.sender, "Is not owner of asset");
        require(_tokenContract.getApproved(_tokenId) == address(this), "Lot is not approved");
        require(_currencyAddress.isContract(), "Given currency is not a contract");
        require(_startPrice != 0, "Invalid start price");
        require(_buyNowPrice >= _startPrice, "Buy now price should higher or equal to start price");
        require(_duration != 0, "Invalid auction duration");
        require(_durationIncrement != 0, "Invalid auction increment");
        require(0 < _bidIncrement && _bidIncrement <= getDecimal(), "Invalid bid increment");

        _tokenContract.transferFrom(msg.sender, address(this), _tokenId);

        AuctionInfo memory _auction;

        if (_startTime < block.timestamp) {
            _auction.startTime = block.timestamp;
            _auction.duration = _duration.sub(block.timestamp.sub(_startTime));
        } else {
            _auction.startTime = _startTime;
            _auction.duration = _duration;
        }

        _auction.creator = msg.sender;
        _auction.tokenAddress = _tokenAddress;
        _auction.tokenId = _tokenId;
        _auction.currencyAddress = _currencyAddress;
        _auction.startPrice = _startPrice;
        _auction.buyNowPrice = _buyNowPrice;
        _auction.bidIncrement = _bidIncrement;
        _auction.description = _description;

        uint256 _auctionId = countOfAuctions;
        auctions[_auctionId] = _auction;
        countOfAuctions++;

        emit AuctionCreated(_auction.creator, _auction.tokenAddress, _auction.tokenId, _auction.currencyAddress, _auctionId);

        return _auctionId;
    }

    function getAuctionInfo(uint256 _auctionId) external shouldExist(_auctionId) view returns (AuctionInfo memory) {
        return auctions[_auctionId];
    }

    function getStatus(uint256 _auctionId) public view returns (AuctionStatus) {
        AuctionInfo memory _auction = auctions[_auctionId];

        if (_auction.creator == address(0)) {
            return AuctionStatus.NONE;
        }
        if (_auction.repaymentTransferred && _auction.lotTransferred) {
            return AuctionStatus.CLOSED;
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

    function bid(uint256 _auctionId, uint256 _amount) external {
        require(
            _amount >= getRaisingBid(_auctionId),
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

        emit AuctionBid(_auctionId, msg.sender, _amount);
    }

    function getRaisingBid(uint256 _auctionId) public view shouldBeActive(_auctionId) returns (uint256) {
        AuctionInfo memory _auction = auctions[_auctionId];

        if (_auction.highestBid == 0) {
            return _auction.startPrice;
        }

        uint256 _highestBid = _auction.highestBid;
        return _highestBid.mul(_auction.bidIncrement).div(getDecimal()).add(_highestBid);
    }

    function claimRepayment(uint256 _auctionId) external shouldBeFinished(_auctionId) {
        AuctionInfo memory _auction = auctions[_auctionId];
        require(_auction.creator == msg.sender, "The Sender is not a auction creator");
        require(!_auction.repaymentTransferred, "The repayment has already been transferred");

        bool _ok = IERC20(_auction.currencyAddress).transfer(_auction.creator, _auction.highestBid);
        require(_ok, "Failed to transfer the repayment");

        auctions[_auctionId].repaymentTransferred = true;

        emit RepaymentTransferred(_auctionId, _auction.creator);
    }

    function claimLot(uint256 _auctionId) external shouldBeFinished(_auctionId) {
        AuctionInfo memory _auction = auctions[_auctionId];
        require(_auction.currentBidder == msg.sender, "The sender is not a winner");
        require(!_auction.lotTransferred, "The lot has already been transferred");

        IERC721(_auction.tokenAddress).transferFrom(address(this), _auction.currentBidder, _auction.tokenId);

        auctions[_auctionId].lotTransferred = true;

        emit LotTransferred(_auctionId, msg.sender);
    }

    function buyNow(uint256 _auctionId) external shouldBeActive(_auctionId) {
        AuctionInfo memory _auction = auctions[_auctionId];

        require(_auction.buyNowPrice > _auction.highestBid, "Buying immediately is no longer relevant");

        bool _ok = IERC20(_auction.currencyAddress).transferFrom(msg.sender, address(this), _auction.buyNowPrice);
        require(_ok, "Failed to transfer the repayment");

        IERC721(_auction.tokenAddress).transferFrom(address(this), msg.sender, _auction.tokenId);

        _auction.lotBought = true;
        _auction.lotTransferred = true;
        auctions[_auctionId] = _auction;

        emit LotTransferred(_auctionId, msg.sender);
    }

    function regainLot(uint256 _auctionId) external shouldBeFinished(_auctionId) {
        AuctionInfo memory _auction = auctions[_auctionId];
        require(msg.sender == _auction.creator, "The sender is not an auction creator");
        require(_auction.highestBid == 0, "The lot belongs to the winner of the auction");

        IERC721(_auction.tokenAddress).transferFrom(address(this), _auction.creator, _auction.tokenId);

        _auction.repaymentTransferred = true;
        _auction.lotTransferred = true;
        auctions[_auctionId] = _auction;

        emit LotTransferred(_auctionId, _auction.creator);
    }

    modifier shouldBeActive(uint256 _auctionId)  {
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
