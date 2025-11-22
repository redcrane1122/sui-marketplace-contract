/// Art Marketplace Module
/// This module handles creation and management of digital art NFTs
/// Supports multiple media types: music, picture, video, PDF
/// Supports free and premium (paid) content

module trixxy::art_marketplace {
    // UID, ID, tx_context, transfer, option, and vector are auto-imported in Move 2024
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;

    /// Media type enum
    const MEDIA_TYPE_OTHER: u8 = 4;

    /// Purchase type enum
    const PURCHASE_TYPE_PREMIUM: u8 = 1;

    /// Art NFT struct containing art metadata and media reference
    public struct ArtNFT has key, store {
        id: UID,
        title: vector<u8>,
        description: vector<u8>,
        artist: address,              // Creator's address
        media_type: u8,               // 0=music, 1=picture, 2=video, 3=pdf, 4=other
        purchase_type: u8,            // 0=free, 1=premium
        walrus_blob_id: vector<u8>,   // Walrus storage blob ID for media file
        thumbnail_blob_id: option::Option<vector<u8>>, // Optional thumbnail for videos/pictures
        price: option::Option<u64>,            // Price in SUI (if premium, in MIST)
        tags: vector<vector<u8>>,     // Tags for categorization
        created_at: u64,              // Timestamp when NFT was created
        views: u64,                   // View count for popularity
    }

    /// Event emitted when an Art NFT is created
    public struct ArtNFT_Created has copy, drop {
        art_id: ID,
        artist: address,
        title: vector<u8>,
        media_type: u8,
        purchase_type: u8,
    }

    /// Event emitted when premium art is purchased
    public struct Art_Purchased has copy, drop {
        art_id: ID,
        buyer: address,
        price: u64,
    }

    /// Error codes
    const E_INVALID_TITLE: u64 = 0;
    const E_INVALID_MEDIA_TYPE: u64 = 1;
    const E_INVALID_PURCHASE_TYPE: u64 = 2;
    const E_MISSING_PRICE: u64 = 3;
    const E_INVALID_PRICE: u64 = 4;

    /// Create a new Art NFT
    /// This function creates an art NFT with metadata and references to media stored in Walrus
    /// Note: media_type should be: 0=music, 1=picture, 2=video, 3=pdf, 4=other
    /// Note: purchase_type should be: 0=free, 1=premium
    /// Note: thumbnail_blob_id can be empty vector for None
    /// Note: price should be 0 for free content, actual price in MIST for premium
    #[allow(lint(public_entry))]
    public entry fun create_art(
        title: vector<u8>,
        description: vector<u8>,
        media_type: u8,
        purchase_type: u8,
        walrus_blob_id: vector<u8>,
        thumbnail_blob_id: vector<u8>,  // Empty vector means None
        price: u64,                     // 0 means None for free content
        tags: vector<vector<u8>>,
        ctx: &mut TxContext
    ) {
        // Validation
        assert!(vector::length(&title) > 0, E_INVALID_TITLE);
        assert!(media_type <= MEDIA_TYPE_OTHER, E_INVALID_MEDIA_TYPE);
        assert!(purchase_type <= PURCHASE_TYPE_PREMIUM, E_INVALID_PURCHASE_TYPE);
        
        // Premium content must have a price
        if (purchase_type == PURCHASE_TYPE_PREMIUM) {
            assert!(price > 0, E_INVALID_PRICE);
        };

        let artist = tx_context::sender(ctx);
        let timestamp = tx_context::epoch_timestamp_ms(ctx);

        // Save title for event before creating art
        let title_for_event = title;

        // Convert thumbnail_blob_id to Option
        let thumbnail_option = if (vector::length(&thumbnail_blob_id) == 0) {
            option::none<vector<u8>>()
        } else {
            option::some(thumbnail_blob_id)
        };

        // Convert price to Option (0 means free/no price)
        let price_option = if (purchase_type == PURCHASE_TYPE_PREMIUM && price > 0) {
            option::some(price)
        } else {
            option::none<u64>()
        };

        // Create the Art NFT
        let art = ArtNFT {
            id: sui::object::new(ctx),
            title,
            description,
            artist,
            media_type,
            purchase_type,
            walrus_blob_id,
            thumbnail_blob_id: thumbnail_option,
            price: price_option,
            tags,
            created_at: timestamp,
            views: 0,
        };

        let art_id = sui::object::id(&art);
        
        // Share the art so anyone can purchase it
        transfer::share_object(art);

        // Emit event
        sui::event::emit(ArtNFT_Created {
            art_id,
            artist,
            title: title_for_event,
            media_type,
            purchase_type,
        });
    }

    /// Purchase premium art (if not free)
    /// This function handles the purchase of premium content
    /// Note: In a full implementation, this would transfer SUI to the artist
    #[allow(lint(public_entry))]
    public entry fun purchase_art(
        art: &mut ArtNFT,
        mut payment: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        assert!(art.purchase_type == PURCHASE_TYPE_PREMIUM, E_INVALID_PURCHASE_TYPE);
        assert!(option::is_some(&art.price), E_MISSING_PRICE);
        
        let price = *option::borrow(&art.price);
        let buyer = tx_context::sender(ctx);
        
        // Verify payment amount
        let payment_amount = coin::value(&payment);
        assert!(payment_amount >= price, E_INVALID_PRICE);

        // Transfer payment to artist
        let artist = art.artist;
        
        // If payment is exactly the price, transfer the whole coin
        // Otherwise, split and transfer both parts
        if (payment_amount == price) {
            transfer::public_transfer(payment, artist);
        } else {
            // Split the required amount from payment
            let payment_to_send = coin::split(&mut payment, price, ctx);
            transfer::public_transfer(payment_to_send, artist);
            // Return remaining payment to sender
            transfer::public_transfer(payment, buyer);
        };

        // Emit purchase event
        sui::event::emit(Art_Purchased {
            art_id: sui::object::id(art),
            buyer,
            price,
        });
    }

    /// Increment view count for an art piece
    public fun increment_views(art: &mut ArtNFT) {
        art.views = art.views + 1;
    }

    /// Get art metadata
    public fun get_title(art: &ArtNFT): vector<u8> {
        art.title
    }

    public fun get_artist(art: &ArtNFT): address {
        art.artist
    }

    public fun get_views(art: &ArtNFT): u64 {
        art.views
    }

    public fun get_price(art: &ArtNFT): Option<u64> {
        art.price
    }
}

