// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BaseTest} from "../Base/Base.t.sol";

contract FragmentNFTsBaseTest is BaseTest {

    function setUp() public override {
        super.setUp();
    }

    /// ============================================
    /// ============= Contract Setup ===============
    /// ============================================

    function test_FragmentWorldStateContractAddress() public view {
        assertEq(
            address(fragmentNFTs.i_fragmentRandomnessContract()),
            address(fragmentRandomness),
            "FragmentWorldState contract address mismatch"
        );
    }

    /// ============================================
    /// ============ Initial State ================
    /// ============================================

    function test_AvailableFragmentNftIds() public view {
        assertEq(
            initialFragmentNftIds.length,
            fragmentNFTs.getNFTsInCirculation().length,
            "initialFragmentNftIds length should match NFTsInCirculation on init"
        );
    }

}
