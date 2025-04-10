// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {DeployScript} from "../../script/Deploy.s.sol";
import {FragmentRandomness} from "../../src/FragmentRandomness.sol";
import {FragmentNFTs} from "../../src/FragmentNFTs.sol";
import {FragmentFusion} from "../../src/FragmentFusion.sol";

contract DeployTest is Test {
    DeployScript public deployer;
    address public deployerAddress;

    // Contract references
    FragmentRandomness public fragmentRandomness;
    FragmentNFTs public fragmentNFTs;
    FragmentFusion public fragmentFusion;

    function setUp() public {
        deployerAddress = makeAddr("deployer");
        vm.deal(deployerAddress, 100 ether);
        deployer = new DeployScript(deployerAddress);
    }

    function test_DeployScript() public {
        // Run deployment with the deployer account
        // vm.startPrank(deployerAddress);
        deployer.run();
        vm.stopPrank();

        // Get deployed contract addresses
        fragmentRandomness = FragmentRandomness(deployer.fragmentRandomness());
        fragmentNFTs = FragmentNFTs(deployer.fragmentNFTs());
        fragmentFusion = FragmentFusion(deployer.fragmentFusion());

        // Verify contracts were deployed
        assertTrue(address(fragmentRandomness) != address(0), "FragmentRandomness not deployed");
        assertTrue(address(fragmentNFTs) != address(0), "FragmentNFTs not deployed");
        assertTrue(address(fragmentFusion) != address(0), "FragmentFusion not deployed");

        // Verify contracts have code
        assertTrue(address(fragmentRandomness).code.length > 0, "No code at FragmentRandomness address");
        assertTrue(address(fragmentNFTs).code.length > 0, "No code at FragmentNFTs address");
        assertTrue(address(fragmentFusion).code.length > 0, "No code at FragmentFusion address");

        // Verify contract connections
        assertEq(
            address(fragmentNFTs.i_fragmentRandomnessContract()),
            address(fragmentRandomness),
            "FragmentNFTs not connected to RandomnessContract"
        );

        assertEq(
            address(fragmentFusion.i_fragmentNFTsContract()),
            address(fragmentNFTs),
            "FragmentFusion not connected to FragmentNFTs"
        );

        // Verify initial NFT IDs were set up
        assertTrue(
            fragmentNFTs.i_initialNFTCount() > 0,
            "Initial NFT count should be greater than 0"
        );

        assertTrue(
            fragmentNFTs.getNFTsInCirculation().length > 0,
            "No NFTs in circulation after deployment"
        );

        // Verify ownership
        assertEq(
            fragmentNFTs.owner(),
            deployerAddress,
            "FragmentNFTs owner should be deployer"
        );
    }

    function test_DeployScript_GasUsage() public {
        // Measure gas usage
        uint256 gasStart = gasleft();
        deployer.run();
        uint256 gasUsed = gasStart - gasleft();

        // Log gas usage for analysis
        console.log("Gas used for deployment:", gasUsed);

        // Verify gas usage is within reasonable limits
        assertTrue(gasUsed < 8_000_000, "Deployment gas too high");
    }

}
