// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {FragmentRandomness} from "./FragmentRandomness.sol";

/**
 * @title Fragment NFTs
 * @author ATrnd
 * @notice This contract manages the creation, verification, and burning of fragment NFTs
 * @dev Implements ERC721 standard with additional fragment-specific functionality
 */
contract FragmentNFTs is ERC721Enumerable, Ownable, ReentrancyGuard {


    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when attempting to burn a set that's already been burned
    error FragmentModule__SetAlreadyBurned();

    /// @notice Thrown when set verification fails during burning
    error FragmentModule__SetVerificationFailed();

    /// @notice Thrown when attempting to verify a non-existent NFT ID
    error FragmentModule__NonexistentNftId();

    /// @notice Thrown when no fragment NFTs are available for minting
    error FragmentModule__NoFragmentNFTsAvailable();

    /// @notice Thrown when attempting to verify an incomplete fragment set
    error FragmentModule__IncompleteSet();

    /// @notice Thrown when caller doesn't own all fragments in a set
    error FragmentModule__NotOwnerOfAll();


    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a complete set of fragments is burned
    /// @param fragmentBurner Address that initiated the burn
    /// @param fragmentNftId ID of the fragment NFT set that was burned
    event FragmentSetBurned(
        address indexed fragmentBurner,
        uint256 indexed fragmentNftId
    );

    event FragmentMinted(
        address indexed minter,
        uint256 indexed tokenId,
        uint256 indexed fragmentNftId,
        uint256 fragmentId
    );

    event NFTRemovedFromCirculation(
        uint256 indexed fragmentNftId,
        uint256 timestamp
    );


    /*//////////////////////////////////////////////////////////////
                              DATA TYPES
    //////////////////////////////////////////////////////////////*/

    /// @notice Defines the properties of a fragment NFT
    /// @param fragmentNftId ID of the complete NFT this fragment belongs to
    /// @param fragmentId Unique identifier within the fragment set (1-4)
    struct Fragment {
        uint256 fragmentNftId;
        uint256 fragmentId;
    }

    /// @notice Stores information about a burned fragment set
    /// @param burner Address that burned the fragments
    /// @param burnTimestamp When the burn occurred
    struct BurnInfo {
        address burner;
        uint256 burnTimestamp;
    }


    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Constants for fragment management
    /// @dev These values are fundamental to the fragment system and cannot be changed
    uint256 private constant MINTED_FRAGMENT_INCREMENT = 1;

    /// @notice Maximum number of fragments per NFT
    /// @dev Represents how many fragments constitute a complete set
    uint256 public constant MAX_FRAGMENTS_PER_NFT = 4;


    /*//////////////////////////////////////////////////////////////
                           IMMUTABLE STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice The initial number of NFT IDs available for minting
    /// @dev Set during contract deployment and remains constant
    uint256 public immutable i_initialNFTCount;

    /// @notice Reference to the randomness contract for fragment distribution
    /// @dev Used to generate random indexes for fair fragment distribution
    FragmentRandomness public immutable i_fragmentRandomnessContract;


    /*//////////////////////////////////////////////////////////////
                           MUTABLE STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Counter for tracking the next token ID to be minted
    /// @dev Increments by 1 for each new fragment
    uint256 public s_nextFragmentTokenId;

    /// @notice Array of NFT IDs available for minting
    /// @dev Dynamically updated as fragments are minted and sets completed
    uint256[] private s_availableFragmentNftIds;

    /// @notice Tracks burned NFT sets by NFT ID and burner address
    /// @dev Maps NFT ID => burner address => burned status
    mapping(uint256 => mapping(address => bool)) private s_fragmentBurnedSets;

    /// @notice Tracks the number of fragments minted for each NFT ID
    /// @dev Maps NFT ID => count of minted fragments
    mapping(uint256 => uint256) private s_mintedFragmentsCount;

    /// @notice Maps NFT IDs to their index in the available NFTs array
    /// @dev Used for efficient removal of completed sets
    mapping(uint256 => uint256) private s_fragmentNftIdToAvailableIndex;

    /// @notice Stores fragment data for each token ID
    /// @dev Maps token ID => Fragment struct
    mapping(uint256 => Fragment) public s_fragmentData;

    /// @notice Maps token IDs to their Fragment NFT IDs
    /// @dev Maps token ID => NFT ID
    mapping(uint256 => uint256) private s_tokenIdToFragmentNftId;

    /// @notice Maps NFT ID and fragment ID to the token ID
    /// @dev Maps NFT ID => fragment ID (1-4) => token ID
    mapping(uint256 => mapping(uint256 => uint256)) private s_fragmentNftIdToFragmentTokenId;

    /// @notice Maps NFT ID to the address that burned it
    /// @dev Returns address(0) if not burned
    /// [duplicate]
    mapping(uint256 => address) private s_fragmentSetBurner;

    /// @notice Maps NFT ID to burn information
    /// @dev Stores metadata about burn events
    /// [duplicate]
    mapping(uint256 => BurnInfo) private s_fragmentSetBurnInfo;


    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the Fragment NFTs contract
    /// @dev Sets up initial state with owner, randomness contract, and available NFT IDs
    /// @param _initialOwner Address that will own and control the contract
    /// @param _fragmentRandomnessContract Address of the deployed randomness contract
    /// @param _initialNftIds Array of NFT IDs that will be available for minting
    constructor(
        address _initialOwner,
        address _fragmentRandomnessContract,
        uint256[] memory _initialNftIds
    ) ERC721("FragmentNFTs", "FRAG") Ownable(_initialOwner) {
        i_fragmentRandomnessContract = FragmentRandomness(_fragmentRandomnessContract);
        i_initialNFTCount = _initialNftIds.length;
        s_availableFragmentNftIds = _initialNftIds;
    }


    /*//////////////////////////////////////////////////////////////
                         MINT FUNCTIONALITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Mints a new fragment NFT
    /// @dev Randomly selects an NFT ID and mints a fragment for it
    /// @return The ID of the newly minted token
    /// @custom:security nonReentrant
    function mint() public nonReentrant returns (uint256) {
        _validateFragmentNFTsAvailable();

        uint256 randomIndex = i_fragmentRandomnessContract.generateRandomIndex(
            s_availableFragmentNftIds.length,
            s_nextFragmentTokenId
        );

        uint256 selectedFragmentNftId = s_availableFragmentNftIds[randomIndex];
        uint256 fragmentCountId = _getNextAvailableFragmentId(selectedFragmentNftId);
        s_nextFragmentTokenId = _getNextFragmentTokenId(s_nextFragmentTokenId);

        _initializeFirstFragment(selectedFragmentNftId, randomIndex);

        s_fragmentData[s_nextFragmentTokenId] = Fragment({
            fragmentNftId: selectedFragmentNftId,
            fragmentId: fragmentCountId
        });

        s_mintedFragmentsCount[selectedFragmentNftId] += MINTED_FRAGMENT_INCREMENT;
        s_fragmentNftIdToFragmentTokenId[selectedFragmentNftId][fragmentCountId] = s_nextFragmentTokenId;
        s_tokenIdToFragmentNftId[s_nextFragmentTokenId] = selectedFragmentNftId;

        emit FragmentMinted(
            msg.sender,
            s_nextFragmentTokenId,
            selectedFragmentNftId,
            fragmentCountId
        );

        _removeNFTIfCompleted(selectedFragmentNftId);
        _safeMint(msg.sender, s_nextFragmentTokenId);

        return s_nextFragmentTokenId;
    }


    /*//////////////////////////////////////////////////////////////
                       BURN FUNCTIONALITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Public wrapper to burn a complete set of fragments
    /// @dev Verifies set eligibility before burning
    /// @param fragmentNftId The NFT ID of the set to burn
    /// @return success True if burning was successful
    /// @custom:security nonReentrant
    function burnFragmentSet(uint256 fragmentNftId) public nonReentrant returns (bool success) {
        return _burnFragmentSet(fragmentNftId);
    }

    /// @notice Internal implementation of fragment set burning
    /// @dev Core logic for burning complete sets
    /// @param fragmentNftId The NFT ID of the set to burn
    /// @return success True if burning was successful
    function _burnFragmentSet(uint256 fragmentNftId) internal returns (bool success) {
        if (_isFragmentSetBurned(fragmentNftId)) {
            revert FragmentModule__SetAlreadyBurned();
        }

        bool verified = _verifyFragmentSet(fragmentNftId);
        if (!verified) {
            revert FragmentModule__SetVerificationFailed();
        }

        s_fragmentBurnedSets[fragmentNftId][msg.sender] = true;
        s_fragmentSetBurner[fragmentNftId] = msg.sender;

        s_fragmentSetBurnInfo[fragmentNftId] = BurnInfo({
            burner: msg.sender,
            burnTimestamp: block.timestamp
        });

        uint256[] memory fragmentTokenIds = getFragmentTokenIds(fragmentNftId);
        for (uint256 i = 0; i < MAX_FRAGMENTS_PER_NFT; i++) {
            uint256 fragmentTokenId = fragmentTokenIds[i];
            _burn(fragmentTokenId);
        }

        emit FragmentSetBurned(msg.sender, fragmentNftId);
        return true;
    }


    /*//////////////////////////////////////////////////////////////
                       VERIFICATION FUNCTIONALITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Public wrapper to verify a fragment set
    /// @dev Checks if a set is complete and owned by the caller
    /// @param fragmentNftId The NFT ID to verify
    /// @return verified True if verification passed
    function verifyFragmentSet(uint256 fragmentNftId) public view returns (bool verified) {
        return _verifyFragmentSet(fragmentNftId);
    }

    /// @notice Internal implementation of fragment set verification
    /// @dev Checks for existence, completeness, and ownership
    /// @param fragmentNftId The NFT ID to verify
    /// @return verified True if verification passed
    function _verifyFragmentSet(uint256 fragmentNftId) internal view returns (bool verified) {
        if (s_mintedFragmentsCount[fragmentNftId] == 0) {
            revert FragmentModule__NonexistentNftId();
        }

        uint256[] memory fragmentTokenIds = getFragmentTokenIds(fragmentNftId);
        if (fragmentTokenIds.length != MAX_FRAGMENTS_PER_NFT) {
            revert FragmentModule__IncompleteSet();
        }

        for (uint256 i = 0; i < MAX_FRAGMENTS_PER_NFT; i++) {
            uint256 fragmentTokenId = fragmentTokenIds[i];

            if (ownerOf(fragmentTokenId) != msg.sender) {
                revert FragmentModule__NotOwnerOfAll();
            }
        }

        return true;
    }


    /*//////////////////////////////////////////////////////////////
                       CIRCULATION MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes tracking for the first fragment of an NFT
    /// @dev Only sets the index if this is the first fragment minted
    /// @param fragmentNftId The NFT ID to initialize
    /// @param randomIndex The index in the available NFTs array
    function _initializeFirstFragment(uint256 fragmentNftId, uint256 randomIndex) private {
        if(s_mintedFragmentsCount[fragmentNftId] == 0) {
            s_fragmentNftIdToAvailableIndex[fragmentNftId] = randomIndex;
        }
    }

    /// @notice Removes an NFT from circulation if all fragments are minted
    /// @dev Checks if fragment count equals or exceeds maximum
    /// @param fragmentNftId The NFT ID to check and potentially remove
    function _removeNFTIfCompleted(uint256 fragmentNftId) private {
        if (s_mintedFragmentsCount[fragmentNftId] >= MAX_FRAGMENTS_PER_NFT) {
            _removeNFTFromCirculation(fragmentNftId);
            emit NFTRemovedFromCirculation(fragmentNftId, block.timestamp);
        }
    }

    /// @notice Removes an NFT from the available circulation
    /// @dev Updates array and index mapping to maintain consistency
    /// @param fragmentNftId The NFT ID to remove
    function _removeNFTFromCirculation(uint256 fragmentNftId) private {
        uint256 index = s_fragmentNftIdToAvailableIndex[fragmentNftId];
        uint256 lastIndex = s_availableFragmentNftIds.length - 1;

        if (index != lastIndex) {
            uint256 lastNftId = s_availableFragmentNftIds[lastIndex];
            s_availableFragmentNftIds[index] = lastNftId;
            s_fragmentNftIdToAvailableIndex[lastNftId] = index;
        }

        s_availableFragmentNftIds.pop();
        delete s_fragmentNftIdToAvailableIndex[fragmentNftId];
    }


    /*//////////////////////////////////////////////////////////////
                       UTILITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Validates that fragments are available for minting
    /// @dev Reverts if no fragments are available
    function _validateFragmentNFTsAvailable() private view {
        if (s_availableFragmentNftIds.length == 0) {
            revert FragmentModule__NoFragmentNFTsAvailable();
        }
    }

    /// @notice Internal implementation for getting the next available fragment ID
    /// @dev Calculates next ID based on minted count
    /// @param fragmentNftId The NFT ID to get next fragment for
    /// @return nextFragmentId The next available fragment ID
    function _getNextAvailableFragmentId(uint256 fragmentNftId) private view returns (uint256 nextFragmentId) {
        return (s_mintedFragmentsCount[fragmentNftId] + 1);
    }

    /// @notice Internal implementation for getting the next fragment token ID
    /// @dev Simple increment function kept internal for consistency
    /// @param fragmentTokenId Current token ID
    /// @return nextFragmentTokenId Next token ID in sequence
    function _getNextFragmentTokenId(uint256 fragmentTokenId) private pure returns(uint256 nextFragmentTokenId) {
        return fragmentTokenId + 1;
    }

    /// @notice Checks if a fragment set has been burned
    /// @param fragmentNftId The NFT ID to check
    /// @return True if the set was burned by the caller
    function _isFragmentSetBurned(uint256 fragmentNftId) private view returns (bool) {
        return s_fragmentBurnedSets[fragmentNftId][msg.sender];
    }


    /*//////////////////////////////////////////////////////////////
                       PUBLIC VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Public wrapper to get the next fragment token ID
    /// @param fragmentTokenId Current token ID
    /// @return nextFragmentTokenId Next token ID in sequence
    function getNextFragmentTokenId(uint256 fragmentTokenId) public pure returns(uint256 nextFragmentTokenId) {
        return _getNextFragmentTokenId(fragmentTokenId);
    }

    /// @notice Public wrapper to get the next available fragment ID for an NFT
    /// @param fragmentNftId The NFT ID to query
    /// @return nextFragmentId The next available fragment ID
    function getNextAvailableFragmentId(uint256 fragmentNftId) public view returns (uint256 nextFragmentId) {
        return _getNextAvailableFragmentId(fragmentNftId);
    }

    /// @notice Gets all available fragment NFT IDs
    /// @return Array of NFT IDs still available for minting
    function getNFTsInCirculation() public view returns (uint256[] memory) {
        return s_availableFragmentNftIds;
    }

    /// @notice Gets the number of fragments left to mint for an NFT
    /// @param fragmentNftId The NFT ID to query
    /// @return Number of fragments that can still be minted
    function getFragmentsLeftForNFT(uint256 fragmentNftId) public view returns (uint256) {
        return MAX_FRAGMENTS_PER_NFT - s_mintedFragmentsCount[fragmentNftId];
    }

    /// @notice Retrieves fragment data for a specific token
    /// @param tokenId The token ID to query
    /// @return Fragment data structure containing the fragment's properties
    function getFragmentData(uint256 tokenId) public view returns (Fragment memory) {
        return s_fragmentData[tokenId];
    }

    /// @notice Gets the Fragment NFT ID associated with a token ID
    /// @param tokenId The token ID to lookup
    /// @return The NFT ID this fragment belongs to
    function getFragmentNftIdByTokenId(uint256 tokenId) public view returns (uint256) {
        return s_tokenIdToFragmentNftId[tokenId];
    }

    /// @notice Gets all token IDs for fragments of a specific NFT
    /// @param nftId The NFT ID to query
    /// @return Array of token IDs belonging to the NFT
    function getFragmentTokenIds(uint256 nftId) public view returns (uint256[] memory) {
        uint256 fragmentCount = s_mintedFragmentsCount[nftId];
        uint256[] memory tokenIds = new uint256[](fragmentCount);

        for (uint256 i = 0; i < fragmentCount; i++) {
            tokenIds[i] = s_fragmentNftIdToFragmentTokenId[nftId][i + 1];
        }

        return tokenIds;
    }

    /// @notice Gets the address that burned a specific fragment set
    /// @param fragmentNftId The NFT ID to check
    /// @return The address that burned the set, or address(0) if not burned
    function getFragmentSetBurner(uint256 fragmentNftId) public view returns (address) {
        return s_fragmentSetBurner[fragmentNftId];
    }

    /// @notice Gets the burn information for a specific fragment set
    /// @param fragmentNftId The NFT ID to query
    /// @return Burn information including burner address and timestamp
    function getFragmentSetBurnInfo(uint256 fragmentNftId) public view returns (BurnInfo memory) {
        return s_fragmentSetBurnInfo[fragmentNftId];
    }

    /// @notice Public function to check if a fragment set has been burned by a specific address
    /// @param fragmentNftId The NFT ID to check
    /// @param burnerAddress The address to verify against
    /// @return True if the set was burned by the specified address
    function isFragmentSetBurnedByAddress(uint256 fragmentNftId, address burnerAddress) public view returns (bool) {
        return s_fragmentBurnedSets[fragmentNftId][burnerAddress];
    }

}
