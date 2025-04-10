// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {BaseTest} from "../Base/Base.t.sol";
import {FragmentNFTs} from "../../../src/FragmentNFTs.sol";

contract FragmentNFTsMintOperationsTest is BaseTest {

    struct Fragment {
        uint256 fragmentNftId;
        uint256 fragmentId;
    }

    function setUp() public override {
        super.setUp();
    }

    /// ============================================
    /// =========== Mint Limitations ==============
    /// ============================================

    function test_RevertWhenNoFragmentNFTsAvailable() public {
        vm.startPrank(user);
        for(uint256 i = 0; i < 12; i++) {
            fragmentNFTs.mint();
        }

        vm.expectRevert(FragmentNFTs.FragmentModule__NoFragmentNFTsAvailable.selector);
        fragmentNFTs.mint();
        vm.stopPrank();
    }

    /// ============================================
    /// =========== Fragment ID Logic =============
    /// ============================================

    function test_FragmentIdLookupByTokenId() public {
        // max tokens / fragment (4) - 1 (on mint) = 3
        uint256 expectedTokensLeft = 3;
        vm.prank(user);
        uint256 userTokenId = fragmentNFTs.mint();
        uint256 userMintedFragmentId = fragmentNFTs.getFragmentNftIdByTokenId(userTokenId);
        uint256 fragmentsLeftAfterMintByTokenId = fragmentNFTs.getFragmentsLeftForNFT(userMintedFragmentId);
        vm.stopPrank();
        assertEq(fragmentsLeftAfterMintByTokenId, expectedTokensLeft, "Should have exactly 3 fragment tokens left after the first mint");
    }

    function test_GetNextAvailableFragmentId() public {
        // First mint a fragment
        vm.prank(user);
        uint256 tokenId = fragmentNFTs.mint();
        uint256 nftId = fragmentNFTs.getFragmentNftIdByTokenId(tokenId);

        uint256 nextId = fragmentNFTs.getNextAvailableFragmentId(nftId);
        assertEq(nextId, 2, "Next available fragment ID should be 2 after first mint");
    }

    /// ============================================
    /// =========== Token ID Sequence =============
    /// ============================================

    function test_NextFragmentTokenIdDefaultsToZero() public view {
        uint256 expectedDefaultValue = 0;
        uint256 s_nextFragmentTokenId = fragmentNFTs.getNextFragmentTokenId(fragmentNFTs.s_nextFragmentTokenId());
        uint256 s_nextFragmentTokenIdDefault = s_nextFragmentTokenId - 1;
        assertEq(s_nextFragmentTokenIdDefault, expectedDefaultValue, "s_nextFragmentTokenIdDefault :: should be zero by default");
    }

    function test_NextFragmentTokenIdIncrements() public view {
        uint256 expectedDefaultValue = 1;
        uint256 s_nextFragmentTokenId = fragmentNFTs.getNextFragmentTokenId(fragmentNFTs.s_nextFragmentTokenId());
        assertEq(s_nextFragmentTokenId, expectedDefaultValue, "s_nextFragmentTokenIdDefault :: should be one on first mint");
    }

    function test_NextFragmentTokenIdIncrementsMore() public {
        uint256 initialLength = fragmentNFTs.getNFTsInCirculation().length;
        uint256 totalMints = initialLength * 4; // 3 NFTs * 4 fragments each = 12 mints

        for(uint256 i = 0; i < totalMints; i++) {
            vm.prank(user);
            uint256 tokenId = fragmentNFTs.mint();
            console.log("tokenId ::", tokenId);
            vm.stopPrank();
        }
    }

    function test_GetNextFragmentTokenId() public view {
        uint256 currentId = 5;
        uint256 nextId = fragmentNFTs.getNextFragmentTokenId(currentId);
        assertEq(nextId, 6, "Next token ID should increment by 1");
    }

    /// ============================================
    /// =========== Fragment Counting =============
    /// ============================================

    function test_MintedFragmentsCount() public {
        uint256 expectedFragmentID = 2;
        vm.prank(user);
        uint256 tokenId = fragmentNFTs.mint();
        uint256 nftFragmentID = fragmentNFTs.getFragmentNftIdByTokenId(tokenId);
        uint256 nextFragmentId = fragmentNFTs.getNextAvailableFragmentId(nftFragmentID);
        assertEq(nextFragmentId,expectedFragmentID, "nextFragmentId should be 2 after the first mint");
        vm.stopPrank();
    }

    function test_FragmentProgression() public {
        vm.startPrank(user);

        uint256 initialLength = fragmentNFTs.getNFTsInCirculation().length;
        uint256[] memory discoveredNftIds = new uint256[](initialLength);
        uint256[] memory currentFragmentCounters = new uint256[](initialLength);
        uint256 discoveredCount = 0;

        console.log("\n=== Starting Minting Process ===");

        uint256 totalMints = initialLength * 4;
        for(uint256 i = 0; i < totalMints; i++) {
            console.log("--------");
            console.log("Mint #", i + 1);
            console.log("--------");

            uint256 tokenId = fragmentNFTs.mint();
            uint256 nftFragmentId = fragmentNFTs.getFragmentNftIdByTokenId(tokenId);
            uint256 nextFragmentId = fragmentNFTs.getNextAvailableFragmentId(nftFragmentId);

            console.log("Fragment NFT ID:", nftFragmentId);
            console.log("Next Fragment Count ID:", nextFragmentId);

            bool found = false;
            uint256 nftIndex;
            for(uint256 j = 0; j < discoveredCount; j++) {
                if(discoveredNftIds[j] == nftFragmentId) {
                    found = true;
                    nftIndex = j;
                    break;
                }
            }

            if(!found) {
                console.log("New discovery!");
                assertEq(nextFragmentId, 2, "getNextAvailableFragmentId :: should be at fragment counter 2 after the first mint");

                discoveredNftIds[discoveredCount] = nftFragmentId;
                currentFragmentCounters[discoveredCount] = nextFragmentId;
                nftIndex = discoveredCount;
                discoveredCount++;
            } else {
                console.log("Existing NFT! Checking counter increment");
                assertEq(nextFragmentId, currentFragmentCounters[nftIndex] + 1,
                         "Fragment counter should increment by 1");
                         currentFragmentCounters[nftIndex] = nextFragmentId;
            }
        }

        vm.stopPrank();
    }

    /// ============================================
    /// ============= Debug Tests ================
    /// ============================================

    function test_DebugTokenIdSequence() public {
        vm.prank(user);
        console.log("Before mint - nextFragmentTokenId:", fragmentNFTs.s_nextFragmentTokenId());

        vm.prank(user);
        uint256 tokenId = fragmentNFTs.mint();
        console.log("Minted tokenId:", tokenId);

        FragmentNFTs.Fragment memory fragData = fragmentNFTs.getFragmentData(tokenId);
        console.log("Fragment NFT ID:", fragData.fragmentNftId);
        console.log("Fragment ID:", fragData.fragmentId);

        console.log("After mint - nextFragmentTokenId:", fragmentNFTs.s_nextFragmentTokenId());
    }
}
