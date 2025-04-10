// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {BaseTest} from "../Base/Base.t.sol";
import {FragmentNFTs} from "../../../src/FragmentNFTs.sol";

contract FragmentNFTsCirculationTest is BaseTest {

    function setUp() public override {
        super.setUp();
    }

    /// ============================================
    /// ========= Circulation Tracking ============
    /// ============================================

    function test_AvailableFragmentNftIdsDecrease() public {
        vm.startPrank(user);

        // Get initial length of available NFTs
        uint256 initialLength = fragmentNFTs.getNFTsInCirculation().length;

        // Array to track which Fragment NFT IDs we've seen
        uint256[] memory mintedFragmentNftIds = new uint256[](initialLength);
        uint256[] memory fragmentsLeftPerNft = new uint256[](initialLength);

        // Initialize tracking arrays
        for(uint256 i = 0; i < initialLength; i++) {
            mintedFragmentNftIds[i] = 0;  // 0 means not seen yet
            fragmentsLeftPerNft[i] = 4;    // All start with 4 fragments available
        }

        // Main minting loop
        for(uint256 i = 0; i < 12; i++) {  // Max possible mints (3 NFTs * 4 fragments)
            // Mint and get Fragment NFT ID
            uint256 tokenId = fragmentNFTs.mint();
            uint256 fragmentNftId = fragmentNFTs.getFragmentNftIdByTokenId(tokenId);

            console.log("--------");
            console.log("Mint #", i + 1);
            console.log("--------");
            console.log("Fragment NFT ID:", fragmentNftId);

            // Find or add this Fragment NFT ID to our tracking
            bool found = false;
            for(uint256 j = 0; j < initialLength; j++) {
                if(mintedFragmentNftIds[j] == fragmentNftId || mintedFragmentNftIds[j] == 0) {
                    if(mintedFragmentNftIds[j] == 0) {
                        mintedFragmentNftIds[j] = fragmentNftId;
                    }
                    fragmentsLeftPerNft[j] = fragmentNFTs.getFragmentsLeftForNFT(fragmentNftId);
                    console.log("Fragments left for NFT", fragmentNftId, ":", fragmentsLeftPerNft[j]);
                    found = true;
                    break;
                }
            }
            require(found, "Fragment NFT ID tracking failed");

            // Check if any NFT has been completed
            uint256 currentLength = fragmentNFTs.getNFTsInCirculation().length;
            if(currentLength < initialLength) {
                console.log("----------------------------");
                console.log("NFT completed! Available NFTs reduced from", initialLength, "to", currentLength);
                // Verify reduction by exactly 1
                assertEq(currentLength, initialLength - 1, "Available NFTs should decrease by 1");
                break;
            }
        }

        vm.stopPrank();
    }

    function test_AllFragmentsMintedAndRevert() public {
        vm.startPrank(user);

        // Get initial length of available NFTs
        uint256 initialLength = fragmentNFTs.getNFTsInCirculation().length;

        // Arrays for tracking NFTs and their fragment counts
        uint256[] memory discoveredNftIds = new uint256[](initialLength);
        uint256[] memory fragmentCountPerNft = new uint256[](initialLength);
        uint256 discoveredCount = 0;

        console.log("\n=== Initial State ===");
        console.log("Initial NFTs in circulation:", initialLength);

        console.log("\n=== Starting Minting Process ===");

        // Main minting loop
        uint256 totalMints = initialLength * 4; // 3 NFTs * 4 fragments each = 12 mints
        for(uint256 i = 0; i < totalMints; i++) {
            uint256 tokenId = fragmentNFTs.mint();
            uint256 fragmentNftId = fragmentNFTs.getFragmentNftIdByTokenId(tokenId);

            console.log("--------");
            console.log("Mint #", i + 1);
            console.log("--------");
            console.log("Fragment NFT ID:", fragmentNftId);

            // Find or add NFT to tracking
            bool found = false;
            for(uint256 j = 0; j < discoveredCount; j++) {
                if(discoveredNftIds[j] == fragmentNftId) {
                    fragmentCountPerNft[j]++;
                    found = true;
                    break;
                }
            }

            // If not found, add it
            if(!found) {
                discoveredNftIds[discoveredCount] = fragmentNftId;
                fragmentCountPerNft[discoveredCount] = 1;
                discoveredCount++;
                console.log("New Fragment NFT (ID) discovered:", fragmentNftId);
            }

            // Get fragments left
            uint256 fragmentsLeft = fragmentNFTs.getFragmentsLeftForNFT(fragmentNftId);
            console.log("Fragments left for NFT", fragmentNftId, ":", fragmentsLeft);

            // Check circulation state
            uint256 currentLength = fragmentNFTs.getNFTsInCirculation().length;
            if(currentLength < initialLength) {
                console.log("\n=== NFT Completed! ===");
                console.log("Available NFTs reduced from", initialLength, "to", currentLength);
                initialLength = currentLength;
            }
        }

        // Verify final state
        uint256 finalLength = fragmentNFTs.getNFTsInCirculation().length;
        console.log("\n=== Final State ===");
        console.log("Final NFTs in circulation:", finalLength);
        assertEq(finalLength, 0, "All NFTs should be out of circulation");

        // Verify fragment counts
        console.log("\n=== Verifying Fragment Counts ===");
        for(uint256 i = 0; i < discoveredCount; i++) {
            console.log("NFT", discoveredNftIds[i], "::", fragmentCountPerNft[i]);
            assertEq(fragmentCountPerNft[i], 4, "Each NFT should have exactly 4 fragments");
        }

        // Test revert
        console.log("\n=== Testing Revert ===");
        console.log("Attempting to mint when no fragments available...");
        vm.expectRevert(FragmentNFTs.FragmentModule__NoFragmentNFTsAvailable.selector);
        fragmentNFTs.mint();
        console.log("Successfully reverted!");

        vm.stopPrank();
    }

    /// ============================================
    /// ======== Circulation Management ===========
    /// ============================================

    function test_RemoveNFTFromCirculation_LastElement() public {
        // Setup - mint until we complete one NFT set
        vm.startPrank(user);

        uint256 targetNftId;
        uint256 mintCount = 0;

        // Get the last NFT ID from initial set
        targetNftId = initialFragmentNftIds[initialFragmentNftIds.length - 1];

        // Mint until we complete the set for the last NFT
        while(mintCount < 4) {
            uint256 tokenId = fragmentNFTs.mint();
            uint256 nftId = fragmentNFTs.getFragmentNftIdByTokenId(tokenId);

            if(nftId == targetNftId) {
                mintCount++;
            }
        }

        // Check that the NFT was removed from circulation
        uint256[] memory remainingNFTs = fragmentNFTs.getNFTsInCirculation();
        for(uint256 i = 0; i < remainingNFTs.length; i++) {
            assertTrue(
                remainingNFTs[i] != targetNftId,
                "Target NFT should be removed from circulation"
            );
        }

        vm.stopPrank();
    }

    function test_RemoveNFTFromCirculation_FirstRemoval() public {
        vm.startPrank(user);

        // Store initial state
        uint256 initialLength = fragmentNFTs.getNFTsInCirculation().length;
        bool nftRemoved = false;
        uint256 mintCount = 0;
        uint256[] memory initialNFTs = fragmentNFTs.getNFTsInCirculation();

        // Keep minting until we see our first NFT removal
        while (!nftRemoved && mintCount < 12) { // 12 is max possible mints (3 NFTs * 4 fragments)
            uint256 currentLength = fragmentNFTs.getNFTsInCirculation().length;

            // If length decreased, we found our first removal
            if (currentLength < initialLength) {
                nftRemoved = true;

                // Get current NFTs in circulation
                uint256[] memory remainingNFTs = fragmentNFTs.getNFTsInCirculation();

                // Verify array length decreased by exactly 1
                assertEq(
                    remainingNFTs.length,
                    initialLength - 1,
                    "Array length should decrease by 1"
                );

                // Verify that exactly one NFT was removed
                uint256 removedCount = 0;
                for (uint256 i = 0; i < initialNFTs.length; i++) {
                    bool foundInRemaining = false;
                    for (uint256 j = 0; j < remainingNFTs.length; j++) {
                        if (initialNFTs[i] == remainingNFTs[j]) {
                            foundInRemaining = true;
                            break;
                        }
                    }
                    if (!foundInRemaining) {
                        removedCount++;
                    }
                }
                assertEq(removedCount, 1, "Exactly one NFT should be removed");
                break;
            }

            fragmentNFTs.mint();
            mintCount++;
            initialLength = currentLength;
        }

        assertTrue(nftRemoved, "No NFT was removed from circulation");
        vm.stopPrank();
    }

    function test_RemoveNFTIfCompleted_NotCompleted() public {
        vm.startPrank(user);

        // Mint just 3 fragments of an NFT (not completed)
        uint256 targetNftId;
        uint256 mintCount = 0;

        while(mintCount < 3) {
            uint256 tokenId = fragmentNFTs.mint();
            uint256 nftId = fragmentNFTs.getFragmentNftIdByTokenId(tokenId);

            if(mintCount == 0) {
                targetNftId = nftId;
                mintCount++;
            } else if(nftId == targetNftId) {
                mintCount++;
            }
        }

        // Verify NFT is still in circulation
        uint256[] memory nftsInCirculation = fragmentNFTs.getNFTsInCirculation();
        bool found = false;
        for(uint256 i = 0; i < nftsInCirculation.length; i++) {
            if(nftsInCirculation[i] == targetNftId) {
                found = true;
                break;
            }
        }

        assertTrue(found, "NFT should still be in circulation");

        vm.stopPrank();
    }
}
