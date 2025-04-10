// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {BaseTest} from "../Base/Base.t.sol";
import {FragmentNFTs} from "../../../src/FragmentNFTs.sol";
import {FragmentFusion} from "../../../src/FragmentFusion.sol";

contract FragmentFusionBaseTest is BaseTest {

    // Main contract to test
    FragmentFusion public fragmentFusion;

    function setUp() public override {
        super.setUp();

        // Deploy FragmentFusion contract
        fragmentFusion = new FragmentFusion(address(fragmentNFTs));
    }

    /// ============================================
    /// ============= Constructor Tests ===========
    /// ============================================
    function test_ConstructorSetup() public view {
        // Verify the contract references are set correctly
        assertEq(
            address(fragmentFusion.i_fragmentNFTsContract()),
            address(fragmentNFTs),
            "FragmentNFTs contract address mismatch"
        );
    }

    /// ============================================
    /// =========== Eligibility Tests =============
    /// ============================================

    function test_VerifyBurnerEligibility_Success() public {
        vm.startPrank(user);

        // Mint a complete set (4 fragments of the same NFT ID)
        (uint256 targetNftId, uint256[] memory fragmentTokenIds) = _mintCompleteSet();

        console.log("\n=== Minted Complete Set ===");
        console.log("Target NFT ID:", targetNftId);
        console.log("Number of fragments:", fragmentTokenIds.length);

        // Burn the fragment set
        bool burnSuccess = fragmentNFTs.burnFragmentSet(targetNftId);
        assertTrue(burnSuccess, "Burn should succeed");

        console.log("\n=== Burned Fragment Set ===");
        console.log("Successfully burned set with NFT ID:", targetNftId);

        // Verify user's eligibility to fuse this set
        fragmentFusion.verifyFragmentFusionAddress(targetNftId);
        vm.stopPrank();
    }

     function test_VerifyBurnerEligibility_RevertSetNotBurned() public {
         vm.startPrank(user);

         // Mint a complete set but DON'T burn it
         (uint256 targetNftId, uint256[] memory fragmentTokenIds) = _mintCompleteSet();

         console.log("\n=== Minted Complete Set (Not Burned) ===");
         console.log("Target NFT ID:", targetNftId);
         console.log("Number of fragments:", fragmentTokenIds.length);

         // Try to verify eligibility without burning
         vm.expectRevert(FragmentFusion.FragmentFusion__SetNotBurned.selector);
         fragmentFusion.verifyFragmentFusionAddress(targetNftId);

         console.log("Successfully reverted with SetNotBurned as expected");

         vm.stopPrank();
     }

    function test_VerifyBurnerEligibility_RevertNotBurner() public {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");

        console.log("\n=== Testing Wrong Burner Scenario ===");

        // Alice mints and burns a set
        vm.startPrank(alice);
        (uint256 targetNftId, ) = _mintCompleteSet();
        console.log("Alice minted and will burn set with NFT ID:", targetNftId);
        fragmentNFTs.burnFragmentSet(targetNftId);
        vm.stopPrank();

        // Bob tries to claim eligibility for Alice's burned set
        vm.startPrank(bob);
        console.log("Bob attempts to verify eligibility for Alice's burned set");
        vm.expectRevert(FragmentFusion.FragmentFusion__NotBurner.selector);
        fragmentFusion.verifyFragmentFusionAddress(targetNftId);

        console.log("Successfully reverted with NotBurner as expected");
        vm.stopPrank();
    }

    function test_VerifyBurnerEligibility_NonexistentNftId() public {
        vm.startPrank(user);

        // Try to verify eligibility for an NFT ID that doesn't exist
        uint256 nonexistentNftId = 999;

        console.log("\n=== Testing Nonexistent NFT ID ===");
        console.log("Attempting to verify nonexistent NFT ID:", nonexistentNftId);

        // This should revert with SetNotBurned since it hasn't been burned
        vm.expectRevert(FragmentFusion.FragmentFusion__SetNotBurned.selector);
        fragmentFusion.verifyFragmentFusionAddress(nonexistentNftId);

        console.log("Successfully reverted with SetNotBurned as expected");

        vm.stopPrank();
    }

}
