// SPDX-License-Identifier: MIT
// Additional features implemented: Minimum price for each NFT, and the ability to bid on multiple NFTs.

pragma solidity ^0.8.26;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract EnglishAuction {
    event Start();
    event Bid(address indexed sender, uint256 nftId, uint256 amount);
    event Withdraw(address indexed bidder, uint256 amount);
    event End(uint256 nftIde, address winner, uint256 amount);

    IERC721 public nft;
    uint256[] public nftIds;
    mapping(uint256 => uint256) public reservePrices; //Minimum bid price for each NFT

    address payable public seller;
    bool public started;
    bool public ended;
    uint256 public endAt;

    mapping(uint256 => address) public highestBidder;
    mapping(uint256 => uint256) public highestBid;

    constructor(address _nft, uint256[] memory _nftIds, uint256[] memory _reservePrices, uint256 _duration) {
        require(_nftIds.length == _reservePrices.length, "Mismatched array lengths");

        nft = IERC721(_nft);
        nftIds = _nftIds;
        seller = payable(msg.sender);

        for (uint256 i = 0; i < _nftIds.length; i++) {
            reservePrices[_nftIds[i]] = _reservePrices[i];
        }

        endAt = block.timestamp + _duration;
       
    }

    function start() external {
        require(!started, "Auction has already started");
        require(msg.sender == seller, "Only the seller can start the auction");

        for (uint256 i = 0; i < nftIds.length; i++) {
            nft.transferFrom(msg.sender, address(this), nftIds[i]);
        }

        started = true;

        emit Start();
    }

    function bid(uint256 nftId) external payable {
        require(started, "Auction has not started");
        require(!ended, "Auction has already ended");
        require(NftIsInAuction(nftId), "Provided NFT Id is not being auctioned");
        require(msg.value > highestBid[nftId], "New bid must be higher than the current highest bid");

        //Implemented checks effects rule here to update the highestBid and highestBidder states here before calling external functions.
        // Even if caller can reenter the function using a call back function they'll have to to attach a higher amount of ether than they had stored previously.
        address previousHighestBidder = highestBidder[nftId];
        uint256 previousHighestBid = highestBid[nftId];

        highestBidder[nftId] = msg.sender;
        highestBid[nftId] = msg.value;

        emit Bid(msg.sender, nftId, msg.value);
        
        if (previousHighestBidder != address(0)){
            payable(previousHighestBidder).transfer(previousHighestBid);
        }
    }

    function end() external {
        require(started, "Auction has not started");
        require(!ended, "Auction has already ended");
        require(msg.sender == seller || block.timestamp >= endAt, "Auction can be ended only after predetermined duration or by the seller");

        ended = true;

        for (uint256 i = 0; i < nftIds.length; i++) {
            uint256 nftId = nftIds[i];

            if (highestBid[nftId] >= reservePrices[nftId]) {
                nft.safeTransferFrom(address(this), highestBidder[nftId], nftId);
                seller.transfer(highestBid[nftId]);
                emit End(nftId, highestBidder[nftId], highestBid[nftId]);
            } else {
                if (highestBidder[nftId] != address(0)) {
                   // Attackers can't reenter this function because ended has already been set to true
                   payable(highestBidder[nftId]).transfer(highestBid[nftId]);
                 }
                nft.safeTransferFrom(address(this), seller, nftId);
                emit End(nftId, address(0), 0);
            }
        }
    }

    function NftIsInAuction(uint256 nftId) internal view returns (bool) {
        for (uint256 i = 0; i < nftIds.length; i++) {
            if (nftIds[i] == nftId) {
                return true;
            }
        }
        return false;
    }
}
