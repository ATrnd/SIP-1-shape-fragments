// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title Fragment Randomness
 * @author ATrnd
 * @notice Provides pseudo-random number generation for the fragment distribution system
 * @dev SECURITY NOTICE: This implementation is NOT secure for production use and will be replaced
 *      with Gelato VRF (https://www.gelato.network/vrf) before mainnet deployment
 */
contract FragmentRandomness {

    /*//////////////////////////////////////////////////////////////
                       RANDOMNESS FUNCTIONALITY
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Generates a pseudo-random index within a given range
     * @dev WARNING: This implementation uses block.timestamp which can be manipulated by miners.
     * @param maxLength The maximum value (exclusive) for the generated index
     * @param salt Additional entropy source for randomness
     * @return A pseudo-random number between 0 and maxLength-1
     */
    function generateRandomIndex(uint256 maxLength, uint256 salt) public view returns (uint256) {
        // This implementation combines block.timestamp, msg.sender, and a salt value
        // to generate pseudorandom numbers, but is vulnerable to miner manipulation
        return uint256(keccak256(abi.encodePacked(
            block.timestamp,
            msg.sender,
            salt
        ))) % maxLength;
    }

}
