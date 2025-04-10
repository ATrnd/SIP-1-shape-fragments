// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {FragmentNFTs} from "../src/FragmentNFTs.sol";
import {FragmentRandomness} from "../src/FragmentRandomness.sol";
import {FragmentFusion} from "../src/FragmentFusion.sol";

contract DeployScript is Script {

    address public deployer;
    FragmentNFTs public fragmentNFTs;
    FragmentRandomness public fragmentRandomness;
    FragmentFusion public fragmentFusion;

    uint256[] public initialFragmentNftIds;

    constructor(address _deployer) {
        deployer = _deployer;
    }

    function run() public {
        vm.startBroadcast(deployer);
        fragmentRandomness = new FragmentRandomness();

        initialFragmentNftIds = new uint256[](3);
        initialFragmentNftIds[0] = 1;
        initialFragmentNftIds[1] = 2;
        initialFragmentNftIds[2] = 3;

        fragmentNFTs = new FragmentNFTs(
            deployer,
            address(fragmentRandomness),
            initialFragmentNftIds
        );

        fragmentFusion = new FragmentFusion(address(fragmentNFTs));

        vm.stopBroadcast();
    }
}
