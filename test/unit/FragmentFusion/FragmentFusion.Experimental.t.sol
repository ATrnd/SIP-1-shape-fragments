// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {BaseTest} from "../Base/Base.t.sol";
import {FragmentNFTs} from "../../../src/FragmentNFTs.sol";
import {FragmentFusion} from "../../../src/FragmentFusion.sol";

contract FragmentFusionExperimentalTest is BaseTest {

    FragmentFusion public fragmentFusion;

    function setUp() public override {
        super.setUp();

        fragmentFusion = new FragmentFusion(address(fragmentNFTs));
        // console.log('FragmentFusion :: Xperimental');

    }

    /// ============================================
    /// ============= Constructor Tests ===========
    /// ============================================

    function test_Constructor_Setup() public view {
        // Verify the contract references are set correctly
        assertEq(
            address(fragmentFusion.i_fragmentNFTsContract()),
            address(fragmentNFTs),
            "FragmentNFTs contract address mismatch"
        );

        // Verify max fusion NFTs is set correctly
        assertEq(
            fragmentFusion.i_maxFragmentFusionNFTs(),
            initialFragmentNftIds.length,
            "Max fragment fusion NFTs mismatch"
        );
    }

    /// ============================================
    /// =========== Verification Tests ============
    /// ============================================

    function test_VerifyFragmentFusionAddress_SetNotBurned() public {
        address alice = makeAddr("alice");

        vm.startPrank(alice);

        vm.expectRevert(FragmentFusion.FragmentFusion__SetNotBurned.selector);
        fragmentFusion.verifyFragmentFusionAddress(1);

        vm.stopPrank();
    }

    function test_VerifyFragmentFusionSet_Unfused() public {

        vm.startPrank(user);
        (uint256 targetNftId, ) = _mintCompleteSet();
        fragmentNFTs.burnFragmentSet(targetNftId);

        fragmentFusion.verifyFragmentFusionSet(targetNftId);

        vm.stopPrank();
    }

    function test_VerifyFragmentFusionAddress_NotBurner() public {
        // Create two addresses
        address originalBurner = makeAddr("originalBurner");
        address unauthorizedUser = makeAddr("unauthorizedUser");

        // Original burner mints and burns a complete set
        vm.startPrank(originalBurner);
        (uint256 targetNftId, ) = _mintCompleteSet();
        fragmentNFTs.burnFragmentSet(targetNftId);
        vm.stopPrank();

        // Verify the set is burned by checking the burner address
        address burner = fragmentNFTs.getFragmentSetBurner(targetNftId);
        assertEq(burner, originalBurner, "Original burner should be recorded correctly");

        // Unauthorized user tries to verify fusion address
        vm.startPrank(unauthorizedUser);
        vm.expectRevert(FragmentFusion.FragmentFusion__NotBurner.selector);
        fragmentFusion.verifyFragmentFusionAddress(targetNftId);
        vm.stopPrank();
    }

    function test_FuseFragmentSet_NotBurner() public {
        // Create two addresses
        address originalBurner = makeAddr("originalBurner");
        address unauthorizedUser = makeAddr("unauthorizedUser");

        // Original burner mints and burns a complete set
        vm.startPrank(originalBurner);
        (uint256 targetNftId, ) = _mintCompleteSet();
        fragmentNFTs.burnFragmentSet(targetNftId);
        vm.stopPrank();

        // Unauthorized user tries to fuse the set
        vm.startPrank(unauthorizedUser);
        vm.expectRevert(FragmentFusion.FragmentFusion__NotBurner.selector);
        fragmentFusion.fuseFragmentSet(targetNftId);
        vm.stopPrank();

        // Log test information
        console.log("\n=== Not Burner Test ===");
        console.log("Target NFT ID:", targetNftId);
        console.log("Original Burner:", originalBurner);
        console.log("Unauthorized User:", unauthorizedUser);
        console.log("Successfully prevented unauthorized fusion");
    }

    function test_FuseFragmentSet_AlreadyFused() public {
        // Setup - mint, burn, and fuse a set
        address owner = makeAddr("owner");

        vm.startPrank(owner);

        // Mint and burn a complete set
        (uint256 targetNftId, ) = _mintCompleteSet();

        console.log("\n=== Already Fused Test Setup ===");
        console.log("Target NFT ID:", targetNftId);
        console.log("Owner:", owner);

        // Burn the fragment set
        bool burnSuccess = fragmentNFTs.burnFragmentSet(targetNftId);
        assertTrue(burnSuccess, "Fragment set burn should succeed");
        console.log("Fragment set successfully burned");

        // First fusion - should succeed
        uint256 fusedTokenId = fragmentFusion.fuseFragmentSet(targetNftId);
        console.log("First fusion successful - Token ID:", fusedTokenId);

        // Verify fusion was successful
        assertEq(fragmentFusion.ownerOf(fusedTokenId), owner, "Owner should receive the fused NFT");

        // Verify fusion metadata
        FragmentFusion.FragmentFusionInfo memory fusionInfo = fragmentFusion.getFusedNFTInfo(fusedTokenId);
        assertEq(fusionInfo.fragmentNftId, targetNftId, "Fusion metadata should reference original NFT ID");
        assertEq(fusionInfo.fragmentFusedBy, owner, "Fusion metadata should record correct owner");

        console.log("\n=== Attempting Second Fusion ===");
        // Try to fuse the same set again
        vm.expectRevert(FragmentFusion.FragmentFusion__AlreadyFused.selector);
        fragmentFusion.fuseFragmentSet(targetNftId);
        console.log("Successfully caught attempt to fuse already fused set");

        vm.stopPrank();
    }

}
