import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre from "hardhat";

describe("NFT Marketplace", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployNFTMarketplaceFixture() {
    // Get the signers
    const [owner, otherAccount] = await hre.ethers.getSigners();

    // Deploy the NFTMarketplace contract
    const NFTMarketplace = await hre.ethers.getContractFactory("NFTMarketplace");
    const nftMarketplace = await NFTMarketplace.deploy("MyNFTMarketplace", "MNFTM");

    // Wait for the contract to be deployed
    await nftMarketplace.waitForDeployment();

    return { nftMarketplace, owner, otherAccount };
  }

  describe("Create listing", function () {
    it("Should create listing successfully", async function () {
      const { nftMarketplace, owner, otherAccount } = await loadFixture(deployNFTMarketplaceFixture);
      
      // Mock data for creating a listing
      const nftName = "Test NFT";
      const nftId = 1;
      const price = hre.ethers.parseEther("1"); // 1 ETH
      const nftAddress = await nftMarketplace;
      const acceptedToken = "0x1234567890123456789012345678901234567890"; // Mock ERC20 token address

      // Create the listing
      await expect(nftMarketplace.createListing(nftName, nftId, price, nftAddress, acceptedToken))
        .to.emit(nftMarketplace, "ListingCreated")
        .withArgs(0, owner.address, price);
    });
  });

  describe("Buy Listing", function () {
    it("Should buy listed NFT successfully", async function () {
      const { nftMarketplace, owner, otherAccount } = await loadFixture(deployNFTMarketplaceFixture);
      
      // Mock data for creating a listing
      const nftName = "Test NFT";
      const nftId = 0;
      const price = hre.ethers.parseUnits("1", 18);
      const nftAddress = await nftMarketplace;
      // const acceptedToken = await hre.ethers.deployContract("Reemarh");
      const myToken = await hre.ethers.getContractFactory("Reemarh");
      const acceptedToken = await myToken.connect(otherAccount).deploy();
      
      // Mint NFT to owner
      const mintedNFT = await nftMarketplace.safeMint(owner.address, "ipfs://testURI");

      const count = await nftMarketplace.nftCount();
      console.log({count});
      // expect(await acceptedToken.balanceOf(owner.address)).to.equal(price);
      
      // Create the listing
      await nftMarketplace.createListing(nftName, nftId, price, nftAddress, acceptedToken);
      
      // Mint tokens to buyer and approve marketplace
      await acceptedToken.connect(otherAccount).mint(price);
      await acceptedToken.connect(otherAccount).approve(nftMarketplace, price);

      await nftMarketplace.connect(owner).approve(nftMarketplace, nftId);
      
      // Buy the NFT
      await expect(nftMarketplace.connect(otherAccount).buyListedNFT(0))
        .to.emit(nftMarketplace, "ListingBought")
        .withArgs(0, otherAccount.address, price);
      
      // Check NFT ownership
      expect(await nftMarketplace.ownerOf(nftId)).to.equal(otherAccount.address);
      
      // Check token transfer
      expect(await acceptedToken.balanceOf(owner.address)).to.equal(price);
    });
  });

  describe("Deactivate Listing", function () {
    it("Should deactivate a listing successfully", async function () {
      const { nftMarketplace, owner, otherAccount } = await loadFixture(deployNFTMarketplaceFixture);
      
      // Mock data for creating a listing
      const nftName = "Test NFT";
      const nftId = 1;
      const price = hre.ethers.parseEther("1"); // 1 ETH
      const nftAddress = await nftMarketplace;
      const acceptedToken = "0x1234567890123456789012345678901234567890"; // Mock ERC20 token address

      // Create the listing
      await nftMarketplace.createListing(nftName, nftId, price, nftAddress, acceptedToken);

      // Deactivate the listing
      await expect(nftMarketplace.deactivateListing(0))
        .to.emit(nftMarketplace, "ListingDeactivated")
        .withArgs(0);

      // Check if the listing is deactivated
      const listing = await nftMarketplace.getListing(0);
      expect(listing.active).to.be.false;

      // Attempt to buy the deactivated listing should fail
      await expect(nftMarketplace.connect(otherAccount).buyListedNFT(0))
        .to.be.revertedWith("Listing is no longer active");
    });
  });

  describe("Update Listing", function () {
    it("Should update a listing price successfully", async function () {
      const { nftMarketplace, owner, otherAccount } = await loadFixture(deployNFTMarketplaceFixture);
      
      // Mock data for creating a listing
      const nftName = "Test NFT";
      const nftId = 1;
      const initialPrice = hre.ethers.parseEther("1"); // 1 ETH
      const nftAddress = await nftMarketplace;
      const acceptedToken = "0x1234567890123456789012345678901234567890"; // Mock ERC20 token address

      // Create the listing
      await nftMarketplace.createListing(nftName, nftId, initialPrice, nftAddress, acceptedToken);

      // Update the listing price
      const newPrice = hre.ethers.parseEther("2"); // 2 ETH
      await expect(nftMarketplace.updatePrice(0, newPrice))
        .to.emit(nftMarketplace, "ListingUpdated")
        .withArgs(0, newPrice);

      // Check if the listing price is updated
      const updatedListing = await nftMarketplace.getListing(0);
      expect(updatedListing.price).to.equal(newPrice);

      // Attempt to update price with non-owner account should fail
      await expect(nftMarketplace.connect(otherAccount).updatePrice(0, initialPrice))
        .to.be.revertedWith("Unauthorized");

      // Attempt to update price to zero should fail
      await expect(nftMarketplace.updatePrice(0, 0))
        .to.be.revertedWith("Price can't be 0");
    });
  });
});
