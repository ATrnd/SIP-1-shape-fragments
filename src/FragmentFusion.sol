// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {FragmentNFTs} from "./FragmentNFTs.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/**
 * @title Fragment Fusion
 * @author ATrnd
 * @notice This contract allows users to fuse burned fragment sets into complete NFTs
 * @dev Inherits from ERC721 to mint new tokens representing fused fragment sets
 */
contract FragmentFusion is ERC721Enumerable {


    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when no fragment NFTs are available
    error FragmentFusion__NoFragmentNFTsAvailable();

    /// @notice Thrown when a caller tries to fuse a fragment set burned by someone else
    error FragmentFusion__NotBurner();

    /// @notice Thrown when trying to fuse a fragment set that hasn't been burned
    error FragmentFusion__SetNotBurned();

    /// @notice Thrown when trying to fuse a fragment set that has already been fused
    error FragmentFusion__AlreadyFused();

    /// @notice Thrown when the maximum number of fusion NFTs has been reached
    error FragmentFusion__MaxFragmentFusionReached();


    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event FragmentSetFused(
        address indexed fuser,
        uint256 indexed fragmentNftId,
        uint256 indexed fusionTokenId,
        uint256 timestamp
    );


    /*//////////////////////////////////////////////////////////////
                              DATA TYPES
    //////////////////////////////////////////////////////////////*/

    /// @notice Metadata for a fused NFT
    /// @param fragmentNftId The original fragment NFT ID that was fused
    /// @param fragmentFusedBy Address of the user who fused the fragment set
    /// @param fragmentFusedTimestamp When the fusion occurred
    struct FragmentFusionInfo {
        uint256 fragmentNftId;
        address fragmentFusedBy;
        uint256 fragmentFusedTimestamp;
    }


    /*//////////////////////////////////////////////////////////////
                            IMMUTABLE STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Reference to the FragmentNFTs contract
    /// @dev Immutable reference set during contract deployment
    FragmentNFTs public immutable i_fragmentNFTsContract;

    /// @notice Maximum number of fusion NFTs that can be created
    /// @dev Set to the initial number of fragment NFT IDs
    uint256 public immutable i_maxFragmentFusionNFTs;


    /*//////////////////////////////////////////////////////////////
                            MUTABLE STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Counter for tracking the next token ID to be minted
    /// @dev Increments by 1 for each new fusion NFT, starts at 0
    uint256 private s_nextFragmentFusionTokenId;

    /// @notice Tracks which fragment sets have been fused
    /// @dev Maps fragment NFT ID => fused status
    mapping(uint256 => bool) private s_fragmentSetFused;

    /// @notice Maps fragment NFT IDs to their corresponding fusion token IDs
    /// @dev Enables lookup of fusion token by original fragment NFT ID
    mapping(uint256 => uint256) private s_fragmentTokenIdToFragmentFusionTokenId;

    /// @notice Stores metadata for fused NFTs
    /// @dev Maps fusion token ID => fusion metadata
    mapping(uint256 => FragmentFusionInfo) private s_fragmentFusionInfo;


    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the Fragment Fusion contract
    /// @dev Sets up the initial state with reference to the FragmentNFTs contract
    /// @param _fragmentNFTsContract Address of the deployed FragmentNFTs contract
    constructor(address _fragmentNFTsContract) ERC721("FragmentFusionNFTs", "FRAGFUSION") {
        i_fragmentNFTsContract = FragmentNFTs(_fragmentNFTsContract);

        if (i_fragmentNFTsContract.i_initialNFTCount() == 0) revert FragmentFusion__NoFragmentNFTsAvailable();

        i_maxFragmentFusionNFTs = i_fragmentNFTsContract.i_initialNFTCount();
    }


    /*//////////////////////////////////////////////////////////////
                           FUSION FUNCTIONALITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new fusion NFT from a burned fragment set
    /// @dev Verifies eligibility, stores metadata, and mints a new ERC721 token
    /// @param fragmentNftId The ID of the fragment set to fuse
    /// @return The ID of the newly minted fusion NFT
    function fuseFragmentSet(uint256 fragmentNftId) public returns (uint256) {
        // Verify the caller has burned this fragment set
        _verifyFragmentFusionAddress(fragmentNftId);

        // Check if this set has already been fused
        _verifyFragmentFusionSet(fragmentNftId);

        // Check if we've reached the maximum number of fusion NFTs
        _verifyFragmentFusionMax();

        // Mark the set as fused
        s_fragmentSetFused[fragmentNftId] = true;

        // Increment token ID counter
        s_nextFragmentFusionTokenId++;

        // Store fusion metadata
        s_fragmentFusionInfo[s_nextFragmentFusionTokenId] = FragmentFusionInfo({
            fragmentNftId: fragmentNftId,
            fragmentFusedBy: msg.sender,
            fragmentFusedTimestamp: block.timestamp
        });

        // Map the fragment NFT ID to the fusion token ID for lookups
        s_fragmentTokenIdToFragmentFusionTokenId[fragmentNftId] = s_nextFragmentFusionTokenId;

        emit FragmentSetFused(
            msg.sender,
            fragmentNftId,
            s_nextFragmentFusionTokenId,
            block.timestamp
        );

        // Mint the new fusion NFT
        _safeMint(msg.sender, s_nextFragmentFusionTokenId);

        return s_nextFragmentFusionTokenId;
    }


    /*//////////////////////////////////////////////////////////////
                          VERIFICATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Verifies that the caller is eligible to fuse a specific fragment set
    /// @dev Checks if the set was burned and if the caller was the one who burned it
    /// @param fragmentNftId The fragment NFT ID to verify
    function _verifyFragmentFusionAddress(uint256 fragmentNftId) private view {
        address fragmentFusionRequestAddress = i_fragmentNFTsContract.getFragmentSetBurner(fragmentNftId);
        if (fragmentFusionRequestAddress == address(0)) {
            revert FragmentFusion__SetNotBurned();
        } else if (fragmentFusionRequestAddress != msg.sender) {
            revert FragmentFusion__NotBurner();
        }
    }

    /// @notice Verifies that a fragment set hasn't already been fused
    /// @dev Reverts if the set has been previously fused
    /// @param fragmentNftId The fragment NFT ID to check
    function _verifyFragmentFusionSet(uint256 fragmentNftId) private view {
        if (s_fragmentSetFused[fragmentNftId]) revert FragmentFusion__AlreadyFused();
    }

    /// @notice Verifies that the fusion limit hasn't been reached
    /// @dev Reverts if the maximum number of fusion NFTs has been minted
    function _verifyFragmentFusionMax() private view {
        if (s_nextFragmentFusionTokenId >= i_maxFragmentFusionNFTs) revert FragmentFusion__MaxFragmentFusionReached();
    }

    /// @notice Public wrapper to verify caller eligibility for fusion
    /// @dev External access to address verification logic
    /// @param fragmentNftId The fragment NFT ID to verify
    function verifyFragmentFusionAddress(uint256 fragmentNftId) public view {
        _verifyFragmentFusionAddress(fragmentNftId);
    }

    /// @notice Public wrapper to verify a fragment set hasn't been fused
    /// @dev External access to set verification logic
    /// @param fragmentNftId The fragment NFT ID to check
    function verifyFragmentFusionSet(uint256 fragmentNftId) public view {
        _verifyFragmentFusionSet(fragmentNftId);
    }

    /// @notice Public wrapper to verify fusion limit
    /// @dev External access to maximum fusion verification
    function verifyFragmentFusionMax() public view {
        _verifyFragmentFusionMax();
    }


    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Retrieves the metadata for a fusion NFT
    /// @dev Returns all stored information about a fusion
    /// @param fusionTokenId The fusion token ID to query
    /// @return The complete fusion metadata
    function getFusedNFTInfo(uint256 fusionTokenId) public view returns (FragmentFusionInfo memory) {
        return s_fragmentFusionInfo[fusionTokenId];
    }

    /// @notice Gets the fusion token ID corresponding to a fragment NFT ID
    /// @dev Enables lookup of fusion tokens by their original fragment ID
    /// @param fragmentNftId The original fragment NFT ID
    /// @return The fusion token ID
    function getFusedNftIdByFragmentNftId(uint256 fragmentNftId) public view returns (uint256) {
        return s_fragmentTokenIdToFragmentFusionTokenId[fragmentNftId];
    }
}
