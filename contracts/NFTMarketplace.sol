// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplace is ERC721URIStorage, Ownable {
    using SafeERC20 for IERC20;

    uint256 public nftCount;

    uint256 private listingCount;
    uint256 private _nextTokenId;
    
    constructor(string memory nftName, string memory nftSymbol) ERC721(nftName, nftSymbol) Ownable(msg.sender) {
    }

    struct Listing {
        uint256 listingId;
        string nftName;
        uint256 nftId;
        uint256 price;
        address seller;
        address nftAddress;
        address acceptedToken;
        bool active;
    }

    Listing[] public allListings;
    mapping(uint256 => Listing) public listings;

    event ListingCreated(uint256 indexed listingId, address indexed seller, uint256 price);
    event ListingBought(uint256 indexed listingId, address indexed buyer, uint256 price);
    event ListingDeactivated(uint256 indexed listingId);
    event ListingUpdated(uint256 indexed listingId, uint256 newPrice);
    event NFTMinted(uint256 indexed tokenId, address indexed to, string uri);

    function checkZeroAddress(address addr, string memory errorMsg) private pure {
        require(addr != address(0), errorMsg);
    }

    function safeMint(address to, string memory uri) public onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        emit NFTMinted(tokenId, to, uri);

        nftCount++;

        return tokenId;
    }

    function createListing(string memory _nftName, uint256 _nftId, uint256 _price, address _nftAddress, address _acceptedToken) external {
        checkZeroAddress(msg.sender, "Invalid Caller");
        checkZeroAddress(_nftAddress, "Invalid NFT address");
        checkZeroAddress(_acceptedToken, "Invalid token address");
        require(_price > 0, "Price can't be 0");

        uint256 newListingId = listingCount++;
        Listing storage newListing = listings[newListingId];
        newListing.listingId = newListingId;
        newListing.nftName = _nftName;
        newListing.nftId = _nftId;
        newListing.price = _price;
        newListing.seller = msg.sender;
        newListing.nftAddress = _nftAddress;
        newListing.acceptedToken = _acceptedToken;
        newListing.active = true;

        allListings.push(newListing);

        emit ListingCreated(newListingId, msg.sender, _price);
    }

    function buyListedNFT(uint256 _listingId) external {
        checkZeroAddress(msg.sender, "Invalid caller");
        Listing storage targetListing = listings[_listingId];
        require(targetListing.listingId == _listingId, "Listing not found");
        require(targetListing.active, "Listing is no longer active");
        
        IERC20 token = IERC20(targetListing.acceptedToken);
        require(token.balanceOf(msg.sender) >= targetListing.price, "Insufficient balance");

        targetListing.active = false;

        token.safeTransferFrom(msg.sender, targetListing.seller, targetListing.price);
        IERC721(targetListing.nftAddress).safeTransferFrom(targetListing.seller, msg.sender, targetListing.nftId);

        emit ListingBought(_listingId, msg.sender, targetListing.price);
    }

    function deactivateListing(uint256 _listingId) external {
        checkZeroAddress(msg.sender, "Invalid caller");
        Listing storage targetListing = listings[_listingId];
        require(targetListing.listingId == _listingId, "Listing not found");
        require(targetListing.active, "Listing is no longer active");
        require(msg.sender == targetListing.seller, "Unauthorized");

        targetListing.active = false;

        emit ListingDeactivated(_listingId);
    }

    function updatePrice(uint256 _listingId, uint256 _price) external {
        checkZeroAddress(msg.sender, "Invalid caller");
        Listing storage targetListing = listings[_listingId];
        require(targetListing.listingId == _listingId, "Listing not found");
        require(targetListing.active, "Listing is no longer active");
        require(msg.sender == targetListing.seller, "Unauthorized");
        require(_price > 0, "Price can't be 0");

        targetListing.price = _price;

        emit ListingUpdated(_listingId, _price);
    }

    function getListing(uint256 _listingId) external view returns (Listing memory) {
        require(listings[_listingId].listingId == _listingId, "Listing not found");
        return listings[_listingId];
    }

    // Override required by Solidity
    function tokenURI(uint256 tokenId) public view override(ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    // Override required by Solidity
    function supportsInterface(bytes4 interfaceId) public view override(ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
