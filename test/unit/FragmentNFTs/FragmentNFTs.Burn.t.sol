// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {BaseTest} from "../Base/Base.t.sol";
import {FragmentNFTs} from "../../../src/FragmentNFTs.sol";

contract FragmentNFTsBurnTest is BaseTest {

    function setUp() public override {
        super.setUp();
    }

    /// ============================================
    /// =========== Successful Burns ==============
    /// ============================================

    function test_BurnFragmentSet_Success() public {
        vm.startPrank(user);

        // Mint until we get a complete set of the same NFT ID
        uint256 targetNftId;
        uint256[] memory fragmentTokenIds = new uint256[](4);
        uint256 mintCount = 0;

        while(mintCount < 4) {
            uint256 tokenId = fragmentNFTs.mint();
            uint256 nftId = fragmentNFTs.getFragmentNftIdByTokenId(tokenId);

            if(mintCount == 0) {
                targetNftId = nftId;
                fragmentTokenIds[mintCount] = tokenId;
                mintCount++;
            } else if(nftId == targetNftId) {
                fragmentTokenIds[mintCount] = tokenId;
                mintCount++;
            }
        }

        // Log pre-burn state
        console.log("\n=== Pre-Burn State ===");
        console.log("Target NFT ID:", targetNftId);
        console.log("Number of fragments:", fragmentTokenIds.length);

        // Verify we can burn the set
        bool burnSuccess = fragmentNFTs.burnFragmentSet(targetNftId);
        assertTrue(burnSuccess, "Burn should succeed");

        console.log("\n=== Post-Burn State ===");
        console.log("Burn successful, verifying token states...");

        // Verify tokens are burned
        for(uint256 i = 0; i < fragmentTokenIds.length; i++) {
            vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", fragmentTokenIds[i]));
            fragmentNFTs.ownerOf(fragmentTokenIds[i]);
            console.log("Verified token", fragmentTokenIds[i], "is burned");
        }

        vm.stopPrank();
    }

    /// ============================================
    /// =========== Revert Conditions ============
    /// ============================================

    function test_BurnFragmentSet_RevertAlreadyBurned() public {
        vm.startPrank(user);

        // First mint and burn a complete set
        (uint256 targetNftId, ) = _mintCompleteSet();

        // Burn the set
        fragmentNFTs.burnFragmentSet(targetNftId);

        console.log("\n=== Testing Double Burn ===");
        console.log("First burn successful, attempting second burn...");

        // Try to burn again
        vm.expectRevert(FragmentNFTs.FragmentModule__SetAlreadyBurned.selector);
        fragmentNFTs.burnFragmentSet(targetNftId);

        console.log("Successfully caught double burn attempt");

        vm.stopPrank();
    }

    function test_BurnFragmentSet_RevertIncompleteSet() public {
        vm.startPrank(user);

        // Mint just one fragment
        uint256 tokenId = fragmentNFTs.mint();
        uint256 nftId = fragmentNFTs.getFragmentNftIdByTokenId(tokenId);

        console.log("\n=== Testing Incomplete Set Burn ===");
        console.log("NFT ID:", nftId);
        console.log("Fragments minted: 1");
        console.log("Attempting to burn incomplete set...");

        // Try to burn incomplete set
        vm.expectRevert(FragmentNFTs.FragmentModule__IncompleteSet.selector);
        fragmentNFTs.burnFragmentSet(nftId);

        console.log("Successfully caught incomplete set burn attempt");

        vm.stopPrank();
    }

    function test_BurnFragmentSet_RevertWrongOwner() public {
        address otherUser = makeAddr("otherUser");

        vm.startPrank(user);

        // Mint complete set
        uint256 targetNftId;
        uint256[] memory fragmentTokenIds = new uint256[](4);
        uint256 mintCount = 0;

        while(mintCount < 4) {
            uint256 tokenId = fragmentNFTs.mint();
            uint256 nftId = fragmentNFTs.getFragmentNftIdByTokenId(tokenId);

            if(mintCount == 0) {
                targetNftId = nftId;
                fragmentTokenIds[mintCount] = tokenId;
                mintCount++;
            } else if(nftId == targetNftId) {
                fragmentTokenIds[mintCount] = tokenId;
                mintCount++;
            }
        }

        console.log("\n=== Testing Wrong Owner Burn ===");
        console.log("Initial owner:", user);
        console.log("Transferring one fragment to:", otherUser);

        // Transfer one fragment to other user
        fragmentNFTs.transferFrom(user, otherUser, fragmentTokenIds[0]);

        console.log("Attempting to burn set while not owning all fragments...");

        // Try to burn set while not owning all fragments
        vm.expectRevert(FragmentNFTs.FragmentModule__NotOwnerOfAll.selector);
        fragmentNFTs.burnFragmentSet(targetNftId);

        console.log("Successfully caught unauthorized burn attempt");

        vm.stopPrank();
    }

    /// ============================================
    /// =========== Helper Functions =============
    /// ============================================

    function _mintCompleteSet() internal override returns (uint256 targetNftId, uint256[] memory fragmentTokenIds) {
        fragmentTokenIds = new uint256[](4);
        uint256 mintCount = 0;

        while(mintCount < 4) {
            uint256 tokenId = fragmentNFTs.mint();
            uint256 nftId = fragmentNFTs.getFragmentNftIdByTokenId(tokenId);

            if(mintCount == 0) {
                targetNftId = nftId;
                fragmentTokenIds[mintCount] = tokenId;
                mintCount++;
            } else if(nftId == targetNftId) {
                fragmentTokenIds[mintCount] = tokenId;
                mintCount++;
            }
        }
    }
}
