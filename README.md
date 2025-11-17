# Trixxy Marketplace Smart Contracts

This directory contains the Sui Move smart contracts for the Trixxy marketplace platform.

## Contracts Overview

### 1. KYC NFT (`kyc_nft.move`)
- **Purpose**: User identity verification
- **Functions**:
  - `mint_kyc_nft`: Creates a KYC verification NFT with user's basic information
- **Features**:
  - Stores name, email, and Walrus ID for extended profile data
  - One KYC NFT per user
  - Emits events for tracking

### 2. Art Marketplace (`art_marketplace.move`)
- **Purpose**: Digital art/content NFT creation and management
- **Functions**:
  - `create_art`: Creates an art NFT with metadata
  - `purchase_art`: Handles premium content purchases
  - `increment_views`: Tracks art popularity
- **Features**:
  - Supports multiple media types (music, picture, video, PDF)
  - Free and premium content models
  - Price management for premium content
  - View tracking for popularity sorting
  - Tags for categorization

### 3. Membership (`membership.move`)
- **Purpose**: Premium access management
- **Functions**:
  - `purchase_membership`: Creates a lifetime membership NFT
  - `purchase_timed_membership`: Creates a time-limited membership NFT
  - `is_active`: Checks if membership is still valid
- **Features**:
  - Two tiers: Standard (1 SUI) and Pro (5 SUI)
  - Lifetime or time-limited memberships
  - Automatic expiration checking

## Project Structure

```
contracts/
├── Move.toml              # Package configuration
├── sources/               # Move source files
│   ├── kyc_nft.move
│   ├── art_marketplace.move
│   └── membership.move
└── README.md             # This file
```

## Setup and Deployment

### Prerequisites
- Sui CLI installed ([Installation Guide](https://docs.sui.io/build/install))
- Sui testnet account with test SUI

### Build Contracts

```bash
cd contracts
sui move build
```

### Deploy to Testnet

1. **Set up your Sui environment**:
```bash
sui client active-address
sui client active-env
```

2. **Deploy the package**:
```bash
sui client publish --gas-budget 100000000
```

3. **Update frontend package IDs**:
After deployment, update the package IDs in the frontend:
- `src/utils/nft.ts`: Update `KYC_NFT_PACKAGE_ID`
- `src/utils/art.ts`: Update `ART_PACKAGE_ID`
- `src/utils/membership.ts`: Update `MEMBERSHIP_PACKAGE_ID`

### Testing

Run unit tests:
```bash
sui move test
```

## Contract Addresses

After deployment, you'll receive package IDs. Update these in your frontend:

- **KYC NFT Package**: `0x...` (update in `src/utils/nft.ts`)
- **Art Marketplace Package**: `0x...` (update in `src/utils/art.ts`)
- **Membership Package**: `0x...` (update in `src/utils/membership.ts`)

## Important Notes

1. **Treasury Address**: Update the treasury address (`@0x0`) in both `art_marketplace.move` and `membership.move` to your actual treasury address.

2. **Network Configuration**: These contracts are configured for Sui testnet. For mainnet deployment, ensure all addresses and configurations are updated.

3. **Gas Budget**: Adjust gas budgets based on network conditions and transaction complexity.

4. **Security**: Review and audit contracts before mainnet deployment.

## Function Signatures

### KYC NFT
```move
public entry fun mint_kyc_nft(
    name: vector<u8>,
    email: vector<u8>,
    walrus_id: vector<u8>,
    ctx: &mut TxContext
)
```

### Art Marketplace
```move
public entry fun create_art(
    title: vector<u8>,
    description: vector<u8>,
    media_type: u8,
    purchase_type: u8,
    walrus_blob_id: vector<u8>,
    thumbnail_blob_id: Option<vector<u8>>,
    price: Option<u64>,
    tags: vector<vector<u8>>,
    ctx: &mut TxContext
)
```

### Membership
```move
public entry fun purchase_membership(
    tier: u8,
    payment: Coin<SUI>,
    ctx: &mut TxContext
)
```

## License

This project is part of the Trixxy marketplace platform.

