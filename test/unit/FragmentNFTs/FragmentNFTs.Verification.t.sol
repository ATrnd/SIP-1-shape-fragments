// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {BaseTest} from "../Base/Base.t.sol";
import {FragmentNFTs} from "../../../src/FragmentNFTs.sol";

contract FragmentNFTsVerificationTest is BaseTest {

    function setUp() public override {
        super.setUp();
    }

    /// ============================================
    /// ========== Complete Set Tests =============
    /// ============================================

    function test_VerifyFragmentSet_CompleteSet() public {
        // Setup - mint complete set for user
        vm.startPrank(user);
        uint256 targetNftId;
        uint256[] memory fragmentTokenIds = new uint256[](4);

        // Mint until we get 4 fragments of the same NFT
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

        // Verify the complete set
        bool verified = fragmentNFTs.verifyFragmentSet(targetNftId);

        assertTrue(verified, "Complete set should verify successfully");
        vm.stopPrank();
    }

    /// ============================================
    /// =========== Revert Conditions ============
    /// ============================================

    function test_VerifyFragmentSet_RevertIncompleteSet() public {
        vm.startPrank(user);
        // Mint just one fragment
        uint256 tokenId = fragmentNFTs.mint();
        uint256 nftId = fragmentNFTs.getFragmentNftIdByTokenId(tokenId);

        vm.expectRevert(FragmentNFTs.FragmentModule__IncompleteSet.selector);
        fragmentNFTs.verifyFragmentSet(nftId);
        vm.stopPrank();
    }

    function test_VerifyFragmentSet_RevertNotOwner() public {
        address alice = makeAddr("alice");

        // Setup - mint complete set for user
        vm.startPrank(user);
        uint256 targetNftId;
        uint256[] memory fragmentTokenIds = new uint256[](4);

        // Mint until we get 4 fragments of the same NFT
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

        // Transfer one fragment to other user
        fragmentNFTs.transferFrom(user, alice, fragmentTokenIds[0]);
        vm.stopPrank();

        // Try to verify set as original user
        vm.prank(user);
        vm.expectRevert(FragmentNFTs.FragmentModule__NotOwnerOfAll.selector);
        fragmentNFTs.verifyFragmentSet(targetNftId);
    }

    function test_VerifyFragmentSet_NonexistentNftId() public {
        vm.prank(user);
        vm.expectRevert(FragmentNFTs.FragmentModule__NonexistentNftId.selector);
        fragmentNFTs.verifyFragmentSet(999);
    }

    function test_VerifyFragmentSet_EmptyFragments() public {
        vm.prank(user);
        vm.expectRevert(FragmentNFTs.FragmentModule__NonexistentNftId.selector);
        fragmentNFTs.verifyFragmentSet(999); // Non-existent NFT ID
    }

    /// ============================================
    /// ========= Comprehensive Tests ============
    /// ============================================

    function test_VerifyFragmentSet_AllBranches() public {
        vm.startPrank(user);

        // First test: Non-existent NFT
        vm.expectRevert(FragmentNFTs.FragmentModule__NonexistentNftId.selector);
        fragmentNFTs.verifyFragmentSet(999);

        // Get our first fragment and remember its NFT ID
        uint256 firstTokenId = fragmentNFTs.mint();
        uint256 firstNftId = fragmentNFTs.getFragmentNftIdByTokenId(firstTokenId);

        // Test incomplete set with our known NFT ID
        vm.expectRevert(FragmentNFTs.FragmentModule__IncompleteSet.selector);
        fragmentNFTs.verifyFragmentSet(firstNftId);

        // Continue minting until we get more fragments of our first NFT ID
        uint256[] memory fragmentTokenIds = new uint256[](4);
        fragmentTokenIds[0] = firstTokenId;
        uint256 mintCount = 1;  // We already have one fragment

        while(mintCount < 4) {
            uint256 newTokenId = fragmentNFTs.mint();
            uint256 newNftId = fragmentNFTs.getFragmentNftIdByTokenId(newTokenId);

            if(newNftId == firstNftId) {
                fragmentTokenIds[mintCount] = newTokenId;
                mintCount++;
            }
        }
        vm.stopPrank();

        // Test ownership check
        address otherUser = makeAddr("otherUser");
        vm.prank(user);
        fragmentNFTs.transferFrom(user, otherUser, fragmentTokenIds[0]);

        vm.prank(user);
        vm.expectRevert(FragmentNFTs.FragmentModule__NotOwnerOfAll.selector);
        fragmentNFTs.verifyFragmentSet(firstNftId);

        // Logging for visibility
        console.log("\n=== Test Completion ===");
        console.log("Tested all verification branches successfully");
        console.log("- Non-existent NFT");
        console.log("- Incomplete set");
        console.log("- Ownership verification");
    }

    /// ============================================
    /// =========== Helper Functions =============
    /// ============================================

    function _mintFragmentsForNFT(uint256 count) internal returns (uint256 targetNftId, uint256[] memory tokenIds) {
        require(count > 0 && count <= 4, "Invalid fragment count");

        tokenIds = new uint256[](count);
        uint256 mintCount = 0;

        while(mintCount < count) {
            uint256 tokenId = fragmentNFTs.mint();
            uint256 nftId = fragmentNFTs.getFragmentNftIdByTokenId(tokenId);

            if(mintCount == 0) {
                targetNftId = nftId;
                tokenIds[mintCount] = tokenId;
                mintCount++;
            } else if(nftId == targetNftId) {
                tokenIds[mintCount] = tokenId;
                mintCount++;
            }
        }
    }

    /// ============================================
    /// ========== Burner Tracking Tests ===========
    /// ============================================

    function test_GetFragmentSetBurner_NotBurned() public view {
        // Check a random NFT ID that hasn't been burned
        address burner = fragmentNFTs.getFragmentSetBurner(999);
        assertEq(burner, address(0), "Burner should be address(0) for non-burned set");
    }

    function test_GetFragmentSetBurner_AfterBurn() public {
        vm.startPrank(user);

        // Mint a complete set
        (uint256 targetNftId, ) = _mintCompleteSet();

        // Verify no burner is recorded before burning
        address burnerBefore = fragmentNFTs.getFragmentSetBurner(targetNftId);
        assertEq(burnerBefore, address(0), "No burner should be recorded before burning");

        // Burn the set
        fragmentNFTs.burnFragmentSet(targetNftId);

        // Check the burner is correctly recorded
        address burnerAfter = fragmentNFTs.getFragmentSetBurner(targetNftId);
        assertEq(burnerAfter, user, "User should be recorded as the burner");

        vm.stopPrank();
    }

    function test_GetFragmentSetBurner_MultipleBurners() public {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");

        uint256 aliceNftId;
        uint256 bobNftId;
        uint256[] memory aliceTokenIds;

        // Alice mints a complete set and collects all token IDs she receives
        vm.startPrank(alice);
        uint256[] memory allTokensMinted = new uint256[](12); // Maximum possible mints
        uint256 mintCount = 0;

        while(true) {
            uint256 tokenId = fragmentNFTs.mint();
            allTokensMinted[mintCount] = tokenId;
            mintCount++;

            // Try to identify a complete set
            uint256[] memory completeSetTokens = new uint256[](4);
            uint256 targetNftId = 0;
            uint256 completeCount = 0;

            for (uint256 i = 0; i < mintCount; i++) {
                uint256 nftId = fragmentNFTs.getFragmentNftIdByTokenId(allTokensMinted[i]);

                if (targetNftId == 0) {
                    targetNftId = nftId;
                    completeSetTokens[0] = allTokensMinted[i];
                    completeCount = 1;
                } else if (nftId == targetNftId && completeCount < 4) {
                    completeSetTokens[completeCount] = allTokensMinted[i];
                    completeCount++;
                }
            }

            // Break if we have a complete set
            if (completeCount == 4) {
                aliceNftId = targetNftId;
                aliceTokenIds = completeSetTokens;
                break;
            }

            // Safety check to prevent infinite loop
            if (mintCount >= 12) {
                break;
            }
        }

        // Alice burns her complete set
        fragmentNFTs.burnFragmentSet(aliceNftId);

        // Collect all remaining tokens (those not in the burned set)
        uint256[] memory remainingTokens = new uint256[](mintCount - 4);
        uint256 remainingCount = 0;

        for (uint256 i = 0; i < mintCount; i++) {
            bool isInBurnedSet = false;
            for (uint256 j = 0; j < 4; j++) {
                if (allTokensMinted[i] == aliceTokenIds[j]) {
                    isInBurnedSet = true;
                    break;
                }
            }

            if (!isInBurnedSet) {
                remainingTokens[remainingCount] = allTokensMinted[i];
                remainingCount++;
            }
        }

        // Transfer all remaining fragments to Bob
        for (uint256 i = 0; i < remainingCount; i++) {
            fragmentNFTs.transferFrom(alice, bob, remainingTokens[i]);
        }
        vm.stopPrank();

        // Bob mints and burns a set using one of Alice's fragments as a target
        vm.startPrank(bob);
        if (remainingCount > 0) {
            // Get the NFT ID of the first remaining token as target
            bobNftId = fragmentNFTs.getFragmentNftIdByTokenId(remainingTokens[0]);

            // Count how many tokens Bob has for the target NFT ID
            uint256 bobHasCount = 0;
        for (uint256 i = 0; i < remainingCount; i++) {
            if (fragmentNFTs.getFragmentNftIdByTokenId(remainingTokens[i]) == bobNftId) {
                bobHasCount++;
            }
        }

        // Mint additional fragments until Bob has a complete set
        while (bobHasCount < 4) {
            uint256 tokenId = fragmentNFTs.mint();
            if (fragmentNFTs.getFragmentNftIdByTokenId(tokenId) == bobNftId) {
                bobHasCount++;
            }
        }

        // Bob burns his set
        fragmentNFTs.burnFragmentSet(bobNftId);
        }
        vm.stopPrank();

        // Verify correct burners are recorded
        address aliceBurner = fragmentNFTs.getFragmentSetBurner(aliceNftId);
        address bobBurner = fragmentNFTs.getFragmentSetBurner(bobNftId);

        assertEq(aliceBurner, alice, "Alice should be recorded as the burner for her set");
        assertEq(bobBurner, bob, "Bob should be recorded as the burner for his set");
    }

    function test_GetFragmentSetBurner_PersistsAfterTransfer() public {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");

        // Alice mints a set but doesn't burn it
        vm.startPrank(alice);
        (uint256 targetNftId, uint256[] memory tokenIds) = _mintCompleteSet();

        // Transfer one fragment to Bob
        fragmentNFTs.transferFrom(alice, bob, tokenIds[0]);
        vm.stopPrank();

        // Bob transfers it back to Alice
        vm.prank(bob);
        fragmentNFTs.transferFrom(bob, alice, tokenIds[0]);

        // Alice burns the set
        vm.prank(alice);
        fragmentNFTs.burnFragmentSet(targetNftId);

        // Verify Alice is recorded as the burner
        address burner = fragmentNFTs.getFragmentSetBurner(targetNftId);
        assertEq(burner, alice, "Alice should be recorded as the burner despite transfers");
    }

}
