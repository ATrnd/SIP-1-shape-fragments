# Shape Fragments System Specification

## 1. Terminology

**Fragment**: An ERC721 token representing one part of a complete NFT. Each complete NFT is divided into exactly four fragments that can be individually owned, transferred, and traded.

**Fragment NFT ID**: A unique identifier for a complete NFT that has been fragmented. Multiple fragment tokens can share the same Fragment NFT ID, indicating they belong to the same complete set.

**Fragment ID**: A number (1-4) that identifies a fragment's position within its set. Each Fragment NFT ID has exactly four fragments with IDs 1, 2, 3, and 4.

**Complete Set**: A collection of all four fragments belonging to the same Fragment NFT ID, owned by the same address.

**Set Verification**: The process of confirming that a user owns all four fragments of a specific Fragment NFT ID.

**Burning**: The irreversible destruction of a complete fragment set after verification. Burning is a prerequisite for fusion.

**Fusion**: The process of creating a new ERC721 token (Fusion NFT) based on a previously burned complete fragment set.

**Fusion NFT**: An ERC721 token created through the fusion process, representing ownership of a completed and burned fragment set.

**Burner Address**: The Ethereum address that executed the burning of a complete fragment set.

**Fragment Set Burner**: A mapping that associates Fragment NFT IDs with the addresses that burned them.

**Minted Fragments Count**: The number of fragments that have been minted for a specific Fragment NFT ID.

**Available Fragment NFT IDs**: The collection of Fragment NFT IDs that still have fragments available for minting.

**Circulation**: The state of Fragment NFT IDs being available for fragment minting. NFT IDs are removed from circulation when all their fragments have been minted.

## 2. System Flow

### 2.1 Process Overview

The Shape Fragments system implements a sequential flow from fragment minting to fusion:

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│              │     │              │     │              │     │              │
│  Mint        │────▶│  Collect     │────▶│  Burn        │────▶│  Fuse        │
│  Fragments   │     │  Complete Set│     │  Fragment Set│     │  New NFT     │
│              │     │              │     │              │     │              │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
```

### 2.2 Technical Process Flow

Below is a detailed technical flow describing the complete lifecycle of fragment NFTs:

#### 1. Fragment Minting
- User calls `FragmentNFTs.mint()`
- System checks available Fragment NFT IDs
- FragmentRandomness contract generates a random index
- Fragment NFT ID is selected based on the random index
- Next available Fragment ID (1-4) is determined for the selected NFT ID
- Fragment data is stored and token is minted to the caller
- Fragment counter for the NFT ID is incremented
- If all fragments for an NFT ID are minted, it's removed from circulation

#### 2. Fragment Collection
- Users acquire fragments through:
  - Direct minting from the contract
  - Secondary market purchases
  - Transfers from other users
- Users monitor their fragment collection to identify complete sets
- A complete set consists of all four fragments (IDs 1-4) of the same Fragment NFT ID

#### 3. Set Verification & Burning
- User calls `FragmentNFTs.verifyFragmentSet(fragmentNftId)` to validate ownership
- System checks:
  - Fragment NFT ID exists
  - All four fragments for the NFT ID exist
  - Caller owns all four fragments
- If verification passes, user calls `FragmentNFTs.burnFragmentSet(fragmentNftId)`
- System marks the set as burned and records the burner's address
- All four fragment tokens are permanently burned
- The `FragmentSetBurned` event is emitted with the burner's address and Fragment NFT ID

#### 4. Fusion Process
- User calls `FragmentFusion.fuseFragmentSet(fragmentNftId)`
- System verifies:
  - The fragment set was burned
  - The caller is the same address that burned the set
  - The set hasn't already been fused
  - Maximum fusion limit hasn't been reached
- If all checks pass, a new Fusion NFT is minted to the caller
- Fusion metadata is stored, linking the new token to the original Fragment NFT ID
- The `FragmentSetFused` event is emitted with fusion details

### 2.3 Contract Interaction Flow
```
┌──────────────────────────────────────────────────────────────────┐
│                        User Wallet                               │
└───────────────────────────────┬──────────────────────────────────┘
                                │
                                ▼
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│  ┌─────────────────┐          │           ┌─────────────────┐    │
│  │ FragmentNFTs    │◄─────────┴──────────▶│ FragmentFusion  │    │
│  │                 │                      │                 │    │
│  │ - mint()        │                      │ - fuseFragment  │    │
│  │ - burnFragment  │                      │   Set()         │    │
│  │   Set()         │                      │                 │    │
│  └────────┬────────┘                      └─────────────────┘    │
│           │                                                      │
│           │                                                      │
│           ▼                                                      │
│  ┌─────────────────┐                                             │
│  │ FragmentRandom- │                                             │
│  │ ness            │                                             │
│  │                 │                                             │
│  │ - generateRandom│                                             │
│  │   Index()       │                                             │
│  └─────────────────┘                                             │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## Smart Contract System
This flow represents the complete lifecycle from initial fragment minting through collection, verification, burning, and finally fusion into a new NFT. At each stage, specific checks ensure the integrity of the fragment-fusion process.

## 3. Technical Specification

### 3.1 FragmentNFTs Contract

**Purpose**: Manages the creation, verification, and burning of fragment NFTs.

**Inheritance**:
- ERC721Enumerable
- Ownable
- ReentrancyGuard

**State Variables**:
- `MAX_FRAGMENTS_PER_NFT`: Constant (4) defining fragments per complete NFT
- `i_initialNFTCount`: Immutable count of initial NFT IDs
- `i_fragmentRandomnessContract`: Immutable reference to randomness contract
- `s_nextFragmentTokenId`: Counter for token ID assignment
- `s_availableFragmentNftIds`: Array of NFT IDs available for minting
- `s_fragmentBurnedSets`: Mapping tracking burned sets by NFT ID and address
- `s_mintedFragmentsCount`: Mapping tracking minted fragments per NFT ID
- `s_fragmentNftIdToAvailableIndex`: Mapping for efficient array management
- `s_fragmentData`: Mapping of token ID to Fragment data struct
- `s_tokenIdToFragmentNftId`: Mapping of token ID to its NFT ID
- `s_fragmentNftIdToFragmentTokenId`: Mapping of NFT ID and fragment ID to token ID
- `s_fragmentSetBurner`: Mapping of NFT ID to address that burned it
- `s_fragmentSetBurnInfo`: Mapping of NFT ID to burn metadata

**Key Functions**:
- `mint()`: Mints a new random fragment NFT
- `burnFragmentSet(uint256 fragmentNftId)`: Burns a complete fragment set
- `verifyFragmentSet(uint256 fragmentNftId)`: Verifies ownership of a complete set
- `getFragmentTokenIds(uint256 nftId)`: Returns all token IDs for an NFT ID
- `getFragmentSetBurner(uint256 fragmentNftId)`: Returns address that burned a set

### 3.2 FragmentFusion Contract

**Purpose**: Creates and manages fusion NFTs from burned fragment sets.

**Inheritance**:
- ERC721Enumerable

**State Variables**:
- `i_fragmentNFTsContract`: Immutable reference to FragmentNFTs contract
- `i_maxFragmentFusionNFTs`: Immutable maximum number of fusion NFTs
- `s_nextFragmentFusionTokenId`: Counter for fusion token IDs
- `s_fragmentSetFused`: Mapping tracking which sets have been fused
- `s_fragmentTokenIdToFragmentFusionTokenId`: Mapping of fragment NFT ID to fusion token ID
- `s_fragmentFusionInfo`: Mapping of fusion token ID to fusion metadata

**Key Functions**:
- `fuseFragmentSet(uint256 fragmentNftId)`: Creates a fusion NFT from a burned set
- `verifyFragmentFusionAddress(uint256 fragmentNftId)`: Verifies caller eligibility
- `verifyFragmentFusionSet(uint256 fragmentNftId)`: Verifies set hasn't been fused
- `verifyFragmentFusionMax()`: Verifies fusion limit hasn't been reached
- `getFusedNFTInfo(uint256 fusionTokenId)`: Returns metadata for a fusion NFT

### 3.3 FragmentRandomness Contract

**Purpose**: Provides pseudo-random number generation for fragment distribution.

**State Variables**: None

**Key Functions**:
- `generateRandomIndex(uint256 maxLength, uint256 salt)`: Generates a pseudo-random index

**Security Notice**: This implementation uses block.timestamp and is NOT secure for production. It should be replaced with a verifiable random function (VRF) service.

### 3.4 Integration Requirements

To properly integrate the Shape Fragments system, implementers must:

1. **Deploy Contracts in Sequence**:
   - First deploy FragmentRandomness
   - Then deploy FragmentNFTs with reference to FragmentRandomness
   - Finally deploy FragmentFusion with reference to FragmentNFTs

2. **Initialization Parameters**:
   - Provide an array of initial NFT IDs to FragmentNFTs constructor
   - Set appropriate ownership addresses

3. **Security Considerations**:
   - Replace FragmentRandomness with a secure VRF implementation for production
   - Implement proper access control for administrative functions

4. **Required Dependencies**:
   - OpenZeppelin Contracts v4.8.0 or later:
     - ERC721
     - ERC721Enumerable
     - Ownable
     - ReentrancyGuard

5. **Gas Optimization**:
   - Consider the number of initial NFT IDs carefully as this affects deployment cost
   - Batch operations where possible to reduce gas costs

6. **Event Handling**:
   - Implement listeners for key events:
     - `FragmentMinted`
     - `FragmentSetBurned`
     - `FragmentSetFused`
   - Use these events for off-chain tracking and UI updates

## 4. Interface Definition

### 4.1 FragmentNFTs Interface

#### 4.1.1 Key Functions

```solidity
/// @notice Mints a new fragment NFT
/// @dev Randomly selects an NFT ID and mints a fragment for it
/// @return The ID of the newly minted token
function mint() public nonReentrant returns (uint256);

/// @notice Burns a complete set of fragments
/// @dev Verifies set eligibility before burning
/// @param fragmentNftId The NFT ID of the set to burn
/// @return success True if burning was successful
function burnFragmentSet(uint256 fragmentNftId) public nonReentrant returns (bool success);

/// @notice Verifies a fragment set is complete and owned by the caller
/// @param fragmentNftId The NFT ID to verify
/// @return verified True if verification passed
function verifyFragmentSet(uint256 fragmentNftId) public view returns (bool verified);

/// @notice Gets all token IDs for fragments of a specific NFT
/// @param nftId The NFT ID to query
/// @return Array of token IDs belonging to the NFT
function getFragmentTokenIds(uint256 nftId) public view returns (uint256[] memory);

/// @notice Gets the address that burned a specific fragment set
/// @param fragmentNftId The NFT ID to check
/// @return The address that burned the set, or address(0) if not burned
function getFragmentSetBurner(uint256 fragmentNftId) public view returns (address);

/// @notice Gets NFT IDs still available for minting
/// @return Array of NFT IDs in circulation
function getNFTsInCirculation() public view returns (uint256[] memory);

/// @notice Gets the number of fragments left to mint for an NFT
/// @param fragmentNftId The NFT ID to query
/// @return Number of fragments that can still be minted
function getFragmentsLeftForNFT(uint256 fragmentNftId) public view returns (uint256);
```

#### 4.1.2 Events
```solidity
/// @notice Emitted when a fragment is minted
/// @param minter Address that minted the fragment
/// @param tokenId ID of the minted token
/// @param fragmentNftId ID of the NFT this fragment belongs to
/// @param fragmentId Unique identifier within the fragment set (1-4)
event FragmentMinted(
    address indexed minter,
    uint256 indexed tokenId,
    uint256 indexed fragmentNftId,
    uint256 fragmentId
);

/// @notice Emitted when a complete set of fragments is burned
/// @param fragmentBurner Address that initiated the burn
/// @param fragmentNftId ID of the fragment NFT set that was burned
event FragmentSetBurned(
    address indexed fragmentBurner,
    uint256 indexed fragmentNftId
);

/// @notice Emitted when an NFT is removed from circulation
/// @param fragmentNftId ID of the NFT removed
/// @param timestamp When the removal occurred
event NFTRemovedFromCirculation(
    uint256 indexed fragmentNftId,
    uint256 timestamp
);
```

### 4.2 FragmentFusion Interface

#### 4.2.1 Key Functions

```solidity
/// @notice Creates a new fusion NFT from a burned fragment set
/// @dev Verifies eligibility, stores metadata, and mints a new ERC721 token
/// @param fragmentNftId The ID of the fragment set to fuse
/// @return The ID of the newly minted fusion NFT
function fuseFragmentSet(uint256 fragmentNftId) public returns (uint256);

/// @notice Verifies that the caller is eligible to fuse a specific fragment set
/// @param fragmentNftId The fragment NFT ID to verify
function verifyFragmentFusionAddress(uint256 fragmentNftId) public view;

/// @notice Verifies that a fragment set hasn't already been fused
/// @param fragmentNftId The fragment NFT ID to check
function verifyFragmentFusionSet(uint256 fragmentNftId) public view;

/// @notice Verifies that the fusion limit hasn't been reached
function verifyFragmentFusionMax() public view;

/// @notice Retrieves the metadata for a fusion NFT
/// @param fusionTokenId The fusion token ID to query
/// @return The complete fusion metadata
function getFusedNFTInfo(uint256 fusionTokenId) public view returns (FragmentFusionInfo memory);

/// @notice Gets the fusion token ID corresponding to a fragment NFT ID
/// @param fragmentNftId The original fragment NFT ID
/// @return The fusion token ID
function getFusedNftIdByFragmentNftId(uint256 fragmentNftId) public view returns (uint256);
```

#### 4.2.2 Events

```solidity
/// @notice Emitted when a fragment set is fused into a new NFT
/// @param fuser Address that performed the fusion
/// @param fragmentNftId Original fragment NFT ID
/// @param fusionTokenId New fusion token ID
/// @param timestamp When the fusion occurred
event FragmentSetFused(
    address indexed fuser,
    uint256 indexed fragmentNftId,
    uint256 indexed fusionTokenId,
    uint256 timestamp
);
```

### 4.3 FragmentRandomness Interface

#### 4.3.1 Key Functions

```solidity
/// @notice Generates a pseudo-random index within a given range
/// @dev WARNING: Uses block.timestamp which can be manipulated by miners
/// @param maxLength The maximum value (exclusive) for the generated index
/// @param salt Additional entropy source for randomness
/// @return A pseudo-random number between 0 and maxLength-1
function generateRandomIndex(uint256 maxLength, uint256 salt) public view returns (uint256);
```

#### 4.3.2 Events
None.

### 4.4 Data Structures

```solidity
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

/// @notice Metadata for a fused NFT
/// @param fragmentNftId The original fragment NFT ID that was fused
/// @param fragmentFusedBy Address of the user who fused the fragment set
/// @param fragmentFusedTimestamp When the fusion occurred
struct FragmentFusionInfo {
    uint256 fragmentNftId;
    address fragmentFusedBy;
    uint256 fragmentFusedTimestamp;
}
```

## 5. Security Considerations

The Shape Fragments system has been designed with several security considerations in mind, but implementers should be aware of potential vulnerabilities and appropriate mitigation strategies.

### 5.1 Randomness Implementation

**Vulnerability**: The current `FragmentRandomness` contract uses `block.timestamp`, `msg.sender`, and a salt value to generate pseudo-random numbers. This approach is vulnerable to miner manipulation and prediction attacks.

**Impact**:
- Miners could theoretically manipulate the block timestamp to influence fragment distribution
- Users with sufficient resources could predict and exploit the randomness to target specific fragments
- Attackers could game the system to acquire complete sets more efficiently than intended

**Mitigation**:
- The current implementation is **explicitly marked as not suitable for production use**
- For production deployment, replace with a secure Verifiable Random Function (VRF) such as:
  - Chainlink VRF
  - Gelato VRF
  - API3 QRNG
- Implementing commit-reveal schemes as an alternative, although with different security tradeoffs

### 5.2 Front-Running Attacks

**Vulnerability**: The public nature of pending transactions in the mempool could allow attackers to observe and front-run certain operations.

**Impact**:
- Front-running the `mint()` function is not directly profitable due to the randomness
- Front-running `burnFragmentSet()` has no clear advantage as burning requires ownership

**Mitigation**:
- The system inherently restricts the value of front-running through ownership requirements
- Consider implementing commit-reveal patterns for sensitive operations in production versions

### 5.3 Reentrancy Vulnerabilities

**Vulnerability**: Callback mechanisms in ERC721 transfers could potentially be exploited for reentrancy attacks.

**Impact**:
- Potential manipulation of state between external calls
- Risk to the integrity of set verification and burning processes

**Mitigation**:
- The contract uses OpenZeppelin's `ReentrancyGuard` for critical functions
- `nonReentrant` modifier applied to `mint()` and `burnFragmentSet()` functions
- Following the checks-effects-interactions pattern throughout the codebase

### 5.4 Centralization Risks

**Vulnerability**: The contracts have owner-controlled functionality which represents a centralization risk.

**Impact**:
- Contract owner has privileged control over certain system parameters
- Potential for abuse if owner keys are compromised

**Mitigation**:
- Minimize owner privileges to only essential functions
- Consider implementing time-locks for sensitive owner operations
- In production, use multi-signature wallets or DAOs for administrative control

### 5.5 Gas Optimization Attacks

**Vulnerability**: Potential for gas-related DoS attacks if the system handles large arrays inefficiently.

**Impact**:
- Operations involving large arrays of NFT IDs could become prohibitively expensive
- Functions might exceed block gas limits as the system scales

**Mitigation**:
- Efficient array management for `s_availableFragmentNftIds`
- Using mappings for O(1) lookups where appropriate
- Careful consideration of initial NFT ID count and scaling limitations

### 5.6 Unbounded Loops

**Vulnerability**: Functions that iterate through arrays without bounds checking could potentially exceed gas limits.

**Impact**:
- Operations might become unusable if arrays grow too large
- Potential for system functionality to be blocked

**Mitigation**:
- The system implements efficient removal of completed NFTs from circulation
- Array operations are carefully designed to minimize gas usage
- Consider implementing batch processing for large-scale operations in production versions

## 6. Backwards Compatibility

The Shape Fragments system is designed to maintain compatibility with existing NFT infrastructure while extending functionality through its fragmentation and fusion mechanics.

### 6.1 ERC721 Compliance

Both `FragmentNFTs` and `FragmentFusion` contracts implement the full ERC721 standard:

- All fragments and fusion tokens are fully compliant ERC721 tokens
- Standard ownership methods (`ownerOf`, `balanceOf`, etc.) function as expected
- Transfer mechanisms (`transferFrom`, `safeTransferFrom`) behave according to the ERC721 specification
- Approval mechanisms (`approve`, `getApproved`, `setApprovalForAll`, `isApprovedForAll`) function normally

This ensures compatibility with:
- All standard NFT wallets
- NFT marketplaces
- Portfolio tracking tools
- DeFi protocols accepting ERC721 tokens as collateral

### 6.2 ERC721Enumerable Support

The system implements the ERC721Enumerable extension, providing on-chain enumeration capabilities:
- `tokenOfOwnerByIndex` allows efficient iteration of tokens owned by an address
- `totalSupply` provides the total count of tokens in circulation
- `tokenByIndex` enables accessing tokens by their position in the supply

This enhances compatibility with platforms requiring on-chain enumeration support and simplifies integration with frontends and analysis tools.

### 6.3 Integration Patterns

#### 6.3.1 Standalone Implementation

The system can be deployed as a standalone NFT collection with its fragmentation mechanics, requiring no integration with existing collections.

#### 6.3.2 Wrapper for Existing Collections

The fragment system can wrap around existing NFT collections by:
- Using NFT IDs from an existing collection as the `initialFragmentNftIds`
- Implementing custom logic to verify ownership of the original NFT before minting related fragments
- Creating a redemption mechanism to relate fusion NFTs back to original collection NFTs

#### 6.3.3 Extension of Rights

The system can be used to extend rights for existing NFT holders:
- Fragment IDs can be generated based on existing NFT ownership
- Fusion NFTs can grant additional utility or access beyond the original NFT
- This creates a two-tier ownership system with original NFTs and their corresponding fusion tokens

### 6.4 Technical Integration Considerations

When integrating with existing NFT systems, implementers should consider:

1. **Token ID Namespace Collision**: Ensure Fragment NFT IDs don't collide with existing token IDs
2. **Metadata Management**: Design metadata systems that appropriately reference original NFTs
3. **Ownership Verification**: If fragments relate to existing NFTs, implement secure verification
4. **Event Handling**: Design event listeners that can correlate events across multiple contracts
5. **Gas Efficiency**: Consider batching operations when bridging between existing and fragment systems

### 6.5 Limitations

While the Shape Fragments system is compatible with existing NFT standards, there are some limitations:

1. **No Direct ERC-1155 Support**: The system is designed for ERC721 tokens only
2. **No Native Metadata Standard**: Implementers must handle metadata separately
3. **Standard Transfer Fees**: The system doesn't implement royalty standards (ERC-2981)
4. **Non-Upgradeable By Default**: Integration with upgradeable contracts requires additional implementation

## 7. Test Cases

The Shape Fragments system includes extensive test coverage to ensure functionality, security, and proper handling of edge cases. Tests are implemented using the Foundry testing framework.

### 7.1 Test Coverage Summary

| Contract | Test File | Coverage |
|----------|-----------|----------|
| FragmentNFTs | FragmentNFTsBaseTest.t.sol<br>FragmentNFTsMintOperationsTest.t.sol<br>FragmentNFTsVerificationTest.t.sol<br>FragmentNFTsBurnTest.t.sol<br>FragmentNFTsCirculationTest.t.sol | ~95% |
| FragmentFusion | FragmentFusionBaseTest.t.sol<br>FragmentFusionExperimentalTest.t.sol | ~90% |
| FragmentRandomness | (Tested via integration) | ~85% |
| Deployment | DeployTest.t.sol | 100% |

### 7.2 Key Scenarios Tested

#### 7.2.1 Fragment Minting

- **Basic Minting**: Verifies that fragments can be minted and assigned correct metadata
  - Test: `test_FragmentIdLookupByTokenId()`

- **Random Distribution**: Confirms fragments are distributed using the randomness implementation
  - Test: `test_MintedFragmentsCount()`

- **Token ID Sequence**: Ensures token IDs increment correctly
  - Test: `test_NextFragmentTokenIdIncrements()`

- **Depletion Handling**: Tests system behavior when all fragments have been minted
  - Test: `test_RevertWhenNoFragmentNFTsAvailable()`

- **Fragment Counter Management**: Verifies fragment counters increment properly
  - Test: `test_FragmentProgression()`

#### 7.2.2 Fragment Set Verification

- **Complete Set Verification**: Tests verification of complete fragment sets
  - Test: `test_VerifyFragmentSet_CompleteSet()`

- **Incomplete Set Handling**: Confirms rejection of incomplete sets
  - Test: `test_VerifyFragmentSet_RevertIncompleteSet()`

- **Ownership Verification**: Tests verification of fragment ownership
  - Test: `test_VerifyFragmentSet_RevertNotOwner()`

- **Nonexistent Set Handling**: Confirms proper handling of nonexistent set verification
  - Test: `test_VerifyFragmentSet_NonexistentNftId()`

#### 7.2.3 Fragment Set Burning

- **Successful Burning**: Verifies complete sets can be burned
  - Test: `test_BurnFragmentSet_Success()`

- **Double-Burn Prevention**: Tests prevention of burning the same set twice
  - Test: `test_BurnFragmentSet_RevertAlreadyBurned()`

- **Incomplete Set Burning**: Confirms incomplete sets cannot be burned
  - Test: `test_BurnFragmentSet_RevertIncompleteSet()`

- **Ownership Requirement**: Tests burning requires ownership of all fragments
  - Test: `test_BurnFragmentSet_RevertWrongOwner()`

- **Burn Tracking**: Verifies system correctly tracks which address burned each set
  - Test: `test_GetFragmentSetBurner_AfterBurn()`

#### 7.2.4 Fragment Circulation

- **Available NFT Management**: Tests how NFT IDs are managed in circulation
  - Test: `test_AvailableFragmentNftIdsDecrease()`

- **Circulation Depletion**: Verifies behavior when all fragments are minted
  - Test: `test_AllFragmentsMintedAndRevert()`

- **NFT Removal**: Tests removal of NFTs from circulation when all fragments are minted
  - Test: `test_RemoveNFTFromCirculation_FirstRemoval()`

- **Partial Set Handling**: Tests management of NFTs with incomplete fragment sets
  - Test: `test_RemoveNFTIfCompleted_NotCompleted()`

#### 7.2.5 Fusion Verification

- **Burner Eligibility**: Tests verification of burner eligibility for fusion
  - Test: `test_VerifyBurnerEligibility_Success()`

- **Non-Burner Rejection**: Confirms only the burner can fuse a set
  - Test: `test_VerifyBurnerEligibility_RevertNotBurner()`

- **Non-Burned Set Handling**: Tests fusion attempt for non-burned sets
  - Test: `test_VerifyBurnerEligibility_RevertSetNotBurned()`

- **Fusion Process**: Verifies successful fusion from burned sets
  - Test: `test_FuseFragmentSet_NotBurner()`

- **Double-Fusion Prevention**: Tests prevention of fusing the same set twice
  - Test: `test_FuseFragmentSet_AlreadyFused()`

#### 7.2.6 Deployment and Integration

- **Contract Connections**: Tests correct linking between contracts
  - Test: `test_Constructor_Setup()`

- **Initialization**: Verifies proper initialization of contracts
  - Test: `test_DeployScript()`

- **Gas Usage**: Measures deployment gas costs
  - Test: `test_DeployScript_GasUsage()`

### 7.3 Edge Cases Tested

- **Multiple Burners**: Tests correct tracking when multiple users burn different sets
  - Test: `test_GetFragmentSetBurner_MultipleBurners()`

- **Transfer Patterns**: Verifies ownership tracking after transfers between users
  - Test: `test_GetFragmentSetBurner_PersistsAfterTransfer()`

- **Maximum Fusion Limit**: Tests behavior when fusion limit is reached
  - Test: `test_VerifyFragmentFusionMax()`

### 7.4 Running Tests

Tests can be executed using the Foundry testing framework:

```bash
# Run all tests
forge test

# Run tests with verbose output
forge test -vvv

# Run a specific test
forge test --mt test_BurnFragmentSet_Success
```

## 8. Reference Implementation

The reference implementation is available in the repository under the `/src` directory:

- [FragmentNFTs.sol](https://github.com/ATrnd/sip-1-shape-fragments/blob/main/src/FragmentNFTs.sol)
- [FragmentFusion.sol](https://github.com/ATrnd/sip-1-shape-fragments/blob/main/src/FragmentFusion.sol)
- [FragmentRandomness.sol](https://github.com/ATrnd/sip-1-shape-fragments/blob/main/src/FragmentRandomness.sol)

The implementation adheres to the interfaces defined in this specification.

## Limitations

This MVP implementation has the following limitations:

- The randomness implementation is not suitable for production use
- No metadata implementation is provided
- The system has not been audited for production use
