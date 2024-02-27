// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTMarketplace {
  error NFTMarketplace__PriceCannotBeZero();
  error NFTMarketplace__NotOwner();
  error NFTMarketplace__NotApprovedForMarketplace();
  error NFTMarketplace__AlreadyListed(address nftAddress, uint256 tokenId);
  error NFTMarketplace__NotListed();
  error NFTMarketplace__PriceNotMet();
  error NFTMarketplace__NoProceeds();
  error NFTMarketplace__TransferFailed();

  struct Listing {
    address owner;
    uint256 price;
  }

  mapping(address => mapping(uint256 => Listing)) public s_listings;
  mapping(address => uint256) private s_proceeds;

  event ItemListed(address indexed seller, address indexed nftAddress, uint256 indexed tokenId, uint256 price);
  event ItemBought(address indexed buyer, address nftAddress, uint256 indexed tokenId, uint256 price);
  event ItemCancelled(address indexed nftAddress, uint256 indexed tokenId);
  event ItemUpdated(address indexed nftAddress, uint256 indexed tokenId, uint256 price);

  modifier onlyOwner(address nftAddress, uint256 tokenId, address owner) {
    IERC721 nft = IERC721(nftAddress);
    if(owner != nft.ownerOf(tokenId)) {
      revert NFTMarketplace__NotOwner();
    }

    _;
  }

  modifier isListed(address nftAddress, uint256 tokenId, address owner) {
    Listing memory listing  = s_listings[nftAddress][tokenId];
    if(listing.price > 0) {
      revert NFTMarketplace__AlreadyListed(nftAddress, tokenId);
    }

    _;
  }

  modifier notListed(address nftAddress, uint256 tokenId) {
     Listing memory listing = s_listings[nftAddress][tokenId];
    if(listing.price < 0) {
      revert NFTMarketplace__NotListed();
    }

    _;
  }

  function listItem(address nftAddress, uint256 tokenId, uint256 price) external onlyOwner(nftAddress, tokenId, msg.sender) notListed(nftAddress, tokenId) {
    if(price <= 0) {
      revert NFTMarketplace__PriceCannotBeZero();
    }

    IERC721 nft = IERC721(nftAddress);

    if(nft.getApproved(tokenId) != address(this)) {
      revert NFTMarketplace__NotApprovedForMarketplace();
    }

    nft.approve(address(this), tokenId);
    s_listings[nftAddress][tokenId] = Listing(msg.sender, price);
    emit ItemListed(msg.sender, nftAddress, tokenId, price);

  }

  function buyItem(address nftAddress, uint256 tokenId) external payable {
    Listing memory listing = s_listings[nftAddress][tokenId];

    if(msg.value < listing.price) {
      revert NFTMarketplace__PriceNotMet();
    }
    delete(s_listings[nftAddress][tokenId]);
    s_proceeds[listing.owner] += msg.value;

    IERC721(nftAddress).safeTransferFrom(listing.owner, msg.sender, tokenId);
    emit ItemListed(listing.owner, nftAddress, tokenId, listing.price);
  }

  function cancelListing(address nftAddress, uint256 tokenId) external isListed(nftAddress, tokenId, msg.sender) onlyOwner(nftAddress, tokenId, msg.sender) {
      delete(s_listings[nftAddress][tokenId]);
      emit ItemCancelled(nftAddress, tokenId);
  }

  function updateListing(address nftAddress, uint256 tokenId, uint256 newPrice) external onlyOwner(nftAddress, tokenId, msg.sender) isListed(nftAddress, tokenId, msg.sender) {
    if(newPrice <= 0) {
      revert NFTMarketplace__PriceCannotBeZero();
    }

    s_listings[nftAddress][tokenId].price = newPrice;
    emit ItemListed(msg.sender, nftAddress, tokenId, newPrice);
    emit ItemUpdated(nftAddress, tokenId, newPrice);
  }


  function withdrawProceeds() external {
    uint256 proceeds = s_proceeds[msg.sender];

    if(proceeds <= 0) {
      revert NFTMarketplace__NoProceeds();
    }

    s_proceeds[msg.sender] = 0;

    (bool success, ) = payable(msg.sender).call{ value: proceeds}("");

    if(!success) {
      s_proceeds[msg.sender] = proceeds;
      revert NFTMarketplace__TransferFailed();
    }
  }

  function getListing(address nftAddress, uint256 tokenId) external view returns (Listing memory) {
    return s_listings[nftAddress][tokenId];
  }

  function getProceeds() external view returns (uint256) {
    return s_proceeds[msg.sender];
  }
}