/// KYC NFT Module
/// This module handles KYC (Know Your Customer) verification NFTs
/// Each user can mint one KYC NFT with their basic information

module trixxy::kyc_nft {
    use sui::object::{UID, ID};
    use sui::tx_context;
    use sui::transfer;
    use std::vector;

    /// KYC NFT struct containing user verification information
    public struct KYC_NFT has key, store {
        id: UID,
        name: vector<u8>,        // User's full name
        email: vector<u8>,       // User's email address
        walrus_id: vector<u8>,  // Walrus storage ID for extended profile data
        created_at: u64,         // Timestamp when NFT was created
    }

    /// Event emitted when a KYC NFT is minted
    public struct KYC_NFT_Minted has copy, drop {
        owner: address,
        nft_id: ID,
        name: vector<u8>,
        email: vector<u8>,
    }

    /// Error codes
    const E_INVALID_NAME: u64 = 1;
    const E_INVALID_EMAIL: u64 = 2;

    /// Mint a new KYC NFT for the caller
    /// This function creates a KYC verification NFT with user's basic information
    /// The extended profile data is stored in Walrus and referenced by walrus_id
    public entry fun mint_kyc_nft(
        name: vector<u8>,
        email: vector<u8>,
        walrus_id: vector<u8>,
        ctx: &mut TxContext
    ) {
        // Basic validation
        assert!(vector::length(&name) > 0, E_INVALID_NAME);
        assert!(vector::length(&email) > 0, E_INVALID_EMAIL);

        let sender = tx_context::sender(ctx);
        let timestamp = tx_context::epoch_timestamp_ms(ctx);

        // Create the KYC NFT
        let nft = KYC_NFT {
            id: sui::object::new(ctx),
            name,
            email,
            walrus_id,
            created_at: timestamp,
        };

        let nft_id = sui::object::id(&nft);
        
        // Transfer to the sender
        transfer::transfer(nft, sender);

        // Emit event
        sui::event::emit(KYC_NFT_Minted {
            owner: sender,
            nft_id,
            name,
            email,
        });
    }

    /// Get the name from a KYC NFT
    public fun get_name(nft: &KYC_NFT): vector<u8> {
        nft.name
    }

    /// Get the email from a KYC NFT
    public fun get_email(nft: &KYC_NFT): vector<u8> {
        nft.email
    }

    /// Get the Walrus ID from a KYC NFT
    public fun get_walrus_id(nft: &KYC_NFT): vector<u8> {
        nft.walrus_id
    }

    /// Get the creation timestamp from a KYC NFT
    public fun get_created_at(nft: &KYC_NFT): u64 {
        nft.created_at
    }
}

