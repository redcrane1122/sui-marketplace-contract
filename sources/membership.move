/// Membership Module
/// This module handles membership NFTs for premium content access
/// Users can purchase membership to access all premium content

module trixxy::membership {
    use sui::object::{UID, ID};
    use sui::tx_context;
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use std::option;

    /// Membership tier types
    const MEMBERSHIP_TIER_STANDARD: u8 = 0;
    const MEMBERSHIP_TIER_PRO: u8 = 1;

    /// Membership NFT struct
    public struct MembershipNFT has key, store {
        id: UID,
        owner: address,
        tier: u8,                    // 0=standard, 1=pro
        purchased_at: u64,           // Timestamp when membership was purchased
        expires_at: option::Option<u64>,     // Optional expiration timestamp (None = lifetime)
    }

    /// Event emitted when membership is purchased
    public struct Membership_Purchased has copy, drop {
        owner: address,
        membership_id: ID,
        tier: u8,
    }

    /// Error codes
    const E_INVALID_TIER: u64 = 0;
    const E_INSUFFICIENT_PAYMENT: u64 = 1;

    /// Membership prices in MIST (1 SUI = 1,000,000,000 MIST)
    const PRICE_STANDARD: u64 = 1000000000; // 1 SUI
    const PRICE_PRO: u64 = 5000000000;      // 5 SUI

    /// Purchase a membership NFT
    /// This function creates a membership NFT after payment
    /// tier: 0 = standard, 1 = pro
    /// Note: Frontend should pass tier as u8 (0 or 1)
    public entry fun purchase_membership(
        tier: u8,
        mut payment: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        assert!(tier <= MEMBERSHIP_TIER_PRO, E_INVALID_TIER);

        let owner = tx_context::sender(ctx);
        let timestamp = tx_context::epoch_timestamp_ms(ctx);
        
        // Determine price based on tier
        let required_price = if (tier == MEMBERSHIP_TIER_STANDARD) {
            PRICE_STANDARD
        } else {
            PRICE_PRO
        };

        // Verify payment
        let payment_amount = coin::value(&payment);
        assert!(payment_amount >= required_price, E_INSUFFICIENT_PAYMENT);

        // Transfer to treasury (replace with actual treasury address)
        let treasury = @0x0;
        
        // If payment is exactly the required price, transfer the whole coin
        // Otherwise, split and transfer both parts
        if (payment_amount == required_price) {
            transfer::public_transfer(payment, treasury);
        } else {
            // Split the required amount from payment
            let payment_to_send = coin::split(&mut payment, required_price, ctx);
            transfer::public_transfer(payment_to_send, treasury);
            // Return remaining payment to sender
            transfer::public_transfer(payment, owner);
        };

        // Create membership NFT (lifetime membership, no expiration)
        let membership = MembershipNFT {
            id: sui::object::new(ctx),
            owner,
            tier,
            purchased_at: timestamp,
            expires_at: option::none<u64>(),
        };

        let membership_id = sui::object::id(&membership);
        
        // Transfer to owner
        transfer::transfer(membership, owner);

        // Emit event
        sui::event::emit(Membership_Purchased {
            owner,
            membership_id,
            tier,
        });
    }

    /// Purchase a time-limited membership NFT
    /// This function creates a membership NFT with expiration
    public entry fun purchase_timed_membership(
        tier: u8,
        duration_ms: u64,  // Duration in milliseconds
        mut payment: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        assert!(tier <= MEMBERSHIP_TIER_PRO, E_INVALID_TIER);

        let owner = tx_context::sender(ctx);
        let timestamp = tx_context::epoch_timestamp_ms(ctx);
        
        // Determine price based on tier
        let required_price = if (tier == MEMBERSHIP_TIER_STANDARD) {
            PRICE_STANDARD
        } else {
            PRICE_PRO
        };

        // Verify payment
        let payment_amount = coin::value(&payment);
        assert!(payment_amount >= required_price, E_INSUFFICIENT_PAYMENT);

        // Transfer to treasury
        let treasury = @0x0;
        
        // If payment is exactly the required price, transfer the whole coin
        // Otherwise, split and transfer both parts
        if (payment_amount == required_price) {
            transfer::public_transfer(payment, treasury);
        } else {
            // Split the required amount from payment
            let payment_to_send = coin::split(&mut payment, required_price, ctx);
            transfer::public_transfer(payment_to_send, treasury);
            // Return remaining payment to sender
            transfer::public_transfer(payment, owner);
        };

        // Calculate expiration
        let expires_at = timestamp + duration_ms;

        // Create membership NFT with expiration
        let membership = MembershipNFT {
            id: sui::object::new(ctx),
            owner,
            tier,
            purchased_at: timestamp,
            expires_at: option::some(expires_at),
        };

        let membership_id = sui::object::id(&membership);
        
        // Transfer to owner
        transfer::transfer(membership, owner);

        // Emit event
        sui::event::emit(Membership_Purchased {
            owner,
            membership_id,
            tier,
        });
    }

    /// Check if membership is active (not expired)
    public fun is_active(membership: &MembershipNFT, current_time: u64): bool {
        if (option::is_none(&membership.expires_at)) {
            true // Lifetime membership
        } else {
            let expires_at = *option::borrow(&membership.expires_at);
            current_time < expires_at
        }
    }

    /// Get membership tier
    public fun get_tier(membership: &MembershipNFT): u8 {
        membership.tier
    }

    /// Get membership owner
    public fun get_owner(membership: &MembershipNFT): address {
        membership.owner
    }
}

