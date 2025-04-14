// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {FragmentNFTs} from "../../../src/FragmentNFTs.sol";
import {FragmentRandomness} from "../../../src/FragmentRandomness.sol";

contract BaseTest is Test {
    using Strings for uint256;

    // Common contract instances
    FragmentNFTs public fragmentNFTs;
    FragmentRandomness public fragmentRandomness;

    // Common addresses
    address public owner;
    address public user;

    // Initial NFT IDs
    uint256[] public initialFragmentNftIds;

    function setUp() public virtual {
        // Setup addresses
        owner = makeAddr("owner");
        user = makeAddr("user");

        // Setup contracts
        fragmentRandomness = new FragmentRandomness();

        // Setup initial NFT IDs
        initialFragmentNftIds = new uint256[](3);
        initialFragmentNftIds[0] = 1;
        initialFragmentNftIds[1] = 2;
        initialFragmentNftIds[2] = 3;

        // Deploy main contract
        vm.prank(owner);
        fragmentNFTs = new FragmentNFTs(
            owner,
            address(fragmentRandomness),
            initialFragmentNftIds
        );
    }

    // Common setup functions for specific test scenarios
    function _mintCompleteSet() internal virtual returns (uint256 targetNftId, uint256[] memory fragmentTokenIds) {
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

    function _mintPartialSet(uint256 count) internal returns (uint256 targetNftId, uint256[] memory fragmentTokenIds) {
        require(count > 0 && count < 4, "Invalid partial set count");

        fragmentTokenIds = new uint256[](count);
        uint256 mintCount = 0;

        while(mintCount < count) {
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

    // Test for the Base class itself
    function test_BaseSetup() public view {
        assertEq(address(fragmentRandomness), address(fragmentNFTs.i_fragmentRandomnessContract()),
                "Randomness contract should be set correctly");
        assertEq(initialFragmentNftIds.length, 3, "Should have 3 initial NFT IDs");
        assertEq(initialFragmentNftIds[0], 1, "First NFT ID should be 1");
    }

    function test_MintHelpers() public {
        vm.startPrank(user);

        // Test complete set minting
        (, uint256[] memory completeTokens) = _mintCompleteSet();
        assertEq(completeTokens.length, 4, "Complete set should have 4 fragments");

        // Test partial set minting
        (, uint256[] memory partialTokens) = _mintPartialSet(2);
        assertEq(partialTokens.length, 2, "Partial set should have requested fragment count");

        vm.stopPrank();
    }
}
