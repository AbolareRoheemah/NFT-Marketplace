// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplace is ERC721, ERC721URIStorage, Ownable {
    uint256 listingCount;
    uint256 private _nextTokenId;
    
    constructor(string memory nftName, string memory nftSymbol) ERC721(nftName, nftSymbol) {

    };

    struct Listing {
        uint256 listingId;
        string NftName;
        uint256 NftId;
        uint256 price;
        address seller;
        address NftAddress;
        address acceptedToken;
        bool active;
    }

    Listing[] allListings;
    mapping (uint => Listing) listings;

    event ListingCreated();
    event ListingBought();
    event ListingDeactivated();
    event ListingUpdated();
    event NFTMinted(uint id, address to, string uri);

    function checkZeroAddress(address caller, string memory errorMsg) private {
        require(caller != address(0), errorMsg);
    }

    function safeMint(address to, string memory uri) public onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        emit NFTMinted(tokenId, to, uri);

        return tokenId;
    }

    function createListing (string memory _nftName, uint _nftId, uint _price, address _nftAddress, address _acceptedToken) external {
        checkZeroAddress(msg.sender, "Invalid Caller");
        checkZeroAddress(_nftAddress, "Invalid NFT address");
        require(_price > 0, "price cant be 0");

        uint count = listingCount++;
        Listing storage newListing = listings[count];
        newListing.listingId = count;
        newListing.NftName = _nftName;
        newListing.NftId = _nftId;
        newListing.price = _price;
        newListing.seller = msg.sender;
        newListing.NftAddress = _nftAddress;
        newListing.acceptedToken = _acceptedToken;
        newListing.active = true;

        listingCount = count;
        allListings.push(newListing);

        emit ListingCreated()
    }

    function buyListedNFT(uint _listingId, address tokenAddress) external {
        checkZeroAddress(msg.sender, "Invalid caller");
        checkZeroAddress(tokenAddress, "Invalid NFT address");
        Listing storage targetListing = listings[_listingId];
        require(targetListing.listingId != 0, "Listing not found");
        require(targetListing.active, "Listing is no more active");
        require(targetListing.acceptedToken == tokenAddress, "token not accepted");
        require(IERC20(tokenAddress).balanceOf(msg.sender) >= targetListing.price, "Insufficient balance");

        targetListing.active = false;

        IERC20(tokenAddress).safeTransfer(targetListing.seller, targetListing.price);
        IERC721(targetListing.NftAddress).safeTransferFrom(targetListing.seller, msg.sender, targetListing.NftId);

        emit ListingBought();
    }

    function deactivateListing(uint _listingId) external returns () {
        checkZeroAddress(msg.sender, "Invalid caller");
        Listing storage targetListing = listings[_listingId];
        require(targetListing.listingId != 0, "Listing not found");
        require(targetListing.active, "Listing is no more active");
        require(msg.sender == targetListing.seller, "Unathorized");

        targetListing.active = false;

        emit ListingDeactivated();
    }

    function updatePrice(uint _listingId, uint _price) external {
        checkZeroAddress(msg.sender, "Invalid caller");
        Listing storage targetListing = listings[_listingId];
        require(targetListing.listingId != 0, "Listing not found");
        require(targetListing.active, "Listing is no more active");
        require(msg.sender == targetListing.seller, "Unathorized");
        require(_price > 0, "price cant be 0");

        targetListing.price = _price;

        emit ListingUpdated();
    }

    function getListing(uint256 _listingId) external view returns (Listing memory) {
        return listings[_listingId];
    }
}
