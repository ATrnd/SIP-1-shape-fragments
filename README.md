# SIP-1: Shape Fragments

### Status: Draft

## SIP Purpose
SIP stands for Shape ([shape.network](https://shape.network/)) Improvement Proposal.
This proposal follows a format inspired by [Ethereum Improvement Proposals (EIP-1)](https://eips.ethereum.org/EIPS/eip-1), adapting the standardized approach to technical documentation for the Shape Network ecosystem. Like EIPs, this SIP aims to document technical specifications and standards in a clear, concise format that facilitates implementation and integration by developers.

## Summary
SIP-1 defines a standardized implementation for NFT fragmentation and fusion. The system divides each NFT into four collectible fragments (ERC721 tokens) that can be individually owned and traded. When all fragments of a set are collected, verified, and burned, they can be fused into a new NFT. This technical standard implements fragment-specific functionality including random distribution, set verification, burn tracking, and fusion eligibility, enabling developers to build collection-based mechanics without reimplementing core fragment logic.

## Abstract
The Shape Fragments system implements a collection mechanism where each NFT is divided into exactly four fragments distributed randomly through minting. These fragments function as standard ERC721 tokens with the following properties:

- Full transferability between wallets
- Standard ownership verification
- Compatibility with existing marketplaces
- Trackable relationship to their parent NFT

When a user collects all four fragments of the same NFT, they can:

- Verify ownership of the complete set
- Burn the set (destroying the fragments)
- Create a new fusion NFT representing the completed collection

The system consists of three core contracts:

- **FragmentNFTs**: Manages fragment lifecycle (minting, verification, burning)
- **FragmentFusion**: Handles creation of new NFTs from burned sets
- **FragmentRandomness**: Controls fragment distribution

⚠️ **DEVELOPER NOTICE**: The current randomness implementation uses block.timestamp and is NOT secure for production. This is for testing purposes only and should be replaced with a verifiable random function (VRF) service in production.

## Motivation
The Shape Fragments system addresses several key technical and practical challenges in the NFT space:

**Extended NFT Utility**: Standard NFT implementations are technically limited to basic ownership patterns. The fragmentation approach extends this functionality, enabling more complex ownership and collection mechanics.

**Development Standardization**: Building fragment-based NFT systems requires significant engineering resources and introduces potential security vulnerabilities. This standardized implementation reduces duplicate development effort while providing a tested, secure foundation.

**Technical Enablement**: NFT fragmentation enables:
- Collection mechanics through fragment set verification
- Trading incentives via fragment scarcity and set completion
- Gamification through the burn-to-fuse mechanism
- Multi-phase NFT ownership patterns

**Implementation Efficiency**: By standardizing the fragmentation logic at the contract level, developers can focus on application-specific features rather than reimplementing core mechanics.

This proposal offers a technical building block that simplifies the implementation of fragment-based NFT systems while maintaining compatibility with existing NFT standards and infrastructure.

## Core Components
The Shape Fragments system comprises three specialized smart contracts that establish a complete NFT fragmentation framework:

1. **FragmentNFTs Contract**

- ERC721Enumerable implementation for fragment tokens
- Manages fragment minting, verification, and burning
- Tracks fragment ownership and relationship to parent NFTs
- Maintains state of available and completed fragment sets


2. **FragmentFusion Contract**

- ERC721Enumerable implementation for fusion tokens
- Verifies eligibility for fusion based on burn records
- Creates new NFTs representing completed collections
- Prevents duplicate fusion of already-processed sets


3. **FragmentRandomness Contract**

- Provides pseudo-random number generation
- Enables fair distribution of fragments during minting
- ⚠️ Uses block.timestamp for testing purposes only

These components form a sequential process flow:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ FragmentNFTs    │     │ FragmentNFTs    │     │ FragmentFusion  │
│                 │     │                 │     │                 │
│ Mint Fragment   │ ──▶ │ Burn Complete   │ ──▶ │ Create Fusion   │
│ Tokens          │     │ Fragment Sets   │     │ NFT             │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        ▲                       │                       │
        │                       │                       │
        │                       ▼                       ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ FragmentRandom- │     │ Verification    │     │ Eligibility     │
│ ness            │     │ (Check fragment │     │ (Check burner   │
│                 │     │  set ownership) │     │  address)       │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

## Primary Use Cases
The Shape Fragments system enables several technical implementations:

## Collection Mechanics

- Fragment set completion as a core objective
- Verifiable on-chain progress tracking
- Automatic validation of complete sets
- Programmatic reward for set completion via fusion

## Ownership Distribution Models

- Random fragment allocation creates natural scarcity
- Fragments function as partial ownership claims
- Trading requirements emerge from distribution variance
- Set completion drives secondary market interactions

## Progressive NFT Applications

- Two-phase ownership model (fragments → fusion)
- Deferred value realization through fusion mechanism
- Verifiable burning of fragments for provable scarcity
- Tracked relationship between fragments and fusion NFTs

## Technical Integration Patterns

- Smart contract hooks for external reward systems
- Compatible with existing NFT marketplaces and wallets
- Extensible for custom economic implementations
- Supports building complex on-chain games using fragment collection logic

These use cases provide implementations for various fragment-based interactions while maintaining compatibility with the ERC721 standard and existing NFT infrastructure.

## Quick Start
To evaluate the Fragment-Fusion system:
```bash
# Clone the repository
git clone git@github.com:ATrnd/sip-1-shape-fragments.git

# Change to project directory
cd sip-001-fragment-fusion

# Install Foundry dependencies
forge install

# Run the test suite
forge test
```

The test suite demonstrates all core functionality including:
- Fragment minting and distribution
- Set verification and burning
- Fusion eligibility and execution
- Error handling and edge cases

For implementation details, review the contracts in the `/src` directory and test scenarios in `/test`.
This system is designed as a utility framework for developers to extend and integrate into their own applications rather than for direct deployment.

## Maintainers

- **Author:** [ATrnd]
- **Contact:** [https://t.me/at_rnd]
