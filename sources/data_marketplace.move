/// Data Marketplace Module
/// This module handles creation, ownership, pricing, and exchange of datasets
/// Features:
/// - Provable ownership via Sui object model
/// - Flexible pricing (fixed, subscription, per-access)
/// - Exchange functionality with revenue sharing
/// - Incentives for producers and consumers

module trixxy::data_marketplace {
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::event;

    /// Pricing model types
    #[allow(unused_const)]
    const PRICING_FIXED: u8 = 0;           // One-time purchase
    const PRICING_SUBSCRIPTION: u8 = 1;    // Recurring subscription
    const PRICING_PER_ACCESS: u8 = 2;      // Pay per access
    const PRICING_FREE: u8 = 3;            // Free access

    /// Dataset category types
    const CATEGORY_OTHER: u8 = 7;

    /// Data Access Token - represents purchased access to a dataset
    public struct DataAccessToken has key, store {
        id: UID,
        dataset_id: ID,
        owner: address,
        purchased_at: u64,
        expires_at: Option<u64>,  // None for lifetime access
        access_count: u64,
        max_accesses: Option<u64>, // None for unlimited
    }

    /// Dataset Stake - represents a staking position on a dataset
    public struct DatasetStake has key, store {
        id: UID,
        dataset_id: ID,
        staker: address,
        amount: u64,
        staked_at: u64,
    }

    /// Dataset NFT - represents ownership and metadata of a dataset
    public struct DatasetNFT has key, store {
        id: UID,
        title: vector<u8>,
        description: vector<u8>,
        producer: address,              // Original creator/owner
        category: u8,                   // 0=financial, 1=healthcare, 2=research, 3=iot, 4=social, 5=geospatial, 6=media, 7=other
        pricing_model: u8,              // 0=fixed, 1=subscription, 2=per-access, 3=free
        price: Option<u64>,             // Price in MIST (if applicable)
        subscription_duration_ms: Option<u64>, // For subscription model
        walrus_blob_id: vector<u8>,     // Walrus storage blob ID for dataset
        metadata_blob_id: Option<vector<u8>>, // Optional metadata/schema file
        schema_hash: vector<u8>,        // Hash of data schema for verification
        data_hash: vector<u8>,          // Hash of dataset for integrity verification
        tags: vector<vector<u8>>,
        created_at: u64,
        updated_at: u64,
        total_sales: u64,               // Number of purchases
        total_revenue: u64,             // Total revenue in MIST
        views: u64,                     // View count
        is_active: bool,                // Whether dataset is available for purchase
        royalty_percentage: u8,         // Royalty percentage (0-100) for resales
        producer_reward_pool: Balance<SUI>, // Pool for producer incentives
    }

    /// Marketplace state - tracks global marketplace statistics
    public struct MarketplaceState has key {
        id: UID,
        total_datasets: u64,
        total_sales: u64,
        total_revenue: u64,
        platform_fee_percentage: u8,    // Platform fee (0-100)
        treasury: Balance<SUI>,
    }

    /// Events
    public struct Dataset_Created has copy, drop {
        dataset_id: ID,
        producer: address,
        title: vector<u8>,
        category: u8,
        pricing_model: u8,
    }

    public struct Dataset_Purchased has copy, drop {
        dataset_id: ID,
        buyer: address,
        access_token_id: ID,
        price: u64,
        pricing_model: u8,
    }

    public struct Dataset_Updated has copy, drop {
        dataset_id: ID,
        producer: address,
    }

    public struct Access_Used has copy, drop {
        dataset_id: ID,
        access_token_id: ID,
        user: address,
    }

    public struct Revenue_Distributed has copy, drop {
        dataset_id: ID,
        producer: address,
        producer_amount: u64,
        platform_amount: u64,
    }

    public struct Dataset_Staked has copy, drop {
        dataset_id: ID,
        staker: address,
        amount: u64,
    }

    public struct Dataset_Unstaked has copy, drop {
        dataset_id: ID,
        staker: address,
        amount: u64,
        reward: u64,
    }

    /// Error codes
    const E_INVALID_TITLE: u64 = 0;
    const E_INVALID_CATEGORY: u64 = 1;
    const E_INVALID_PRICING_MODEL: u64 = 2;
    const E_INVALID_PRICE: u64 = 3;
    const E_DATASET_NOT_ACTIVE: u64 = 4;
    const E_INSUFFICIENT_PAYMENT: u64 = 5;
    const E_ACCESS_EXPIRED: u64 = 6;
    const E_ACCESS_LIMIT_REACHED: u64 = 7;
    const E_NOT_PRODUCER: u64 = 8;
    const E_INVALID_ROYALTY: u64 = 9;
    #[allow(unused_const)]
    const E_MARKETPLACE_NOT_INITIALIZED: u64 = 10;
    const E_INVALID_PAYMENT: u64 = 11;
    const E_NOT_STAKER: u64 = 12;
    const E_INSUFFICIENT_REWARDS: u64 = 13;

    /// Initialize marketplace (one-time setup)
    #[allow(lint(public_entry))]
    public entry fun initialize_marketplace(
        ctx: &mut TxContext
    ) {
        let state = MarketplaceState {
            id: sui::object::new(ctx),
            total_datasets: 0,
            total_sales: 0,
            total_revenue: 0,
            platform_fee_percentage: 5, // 5% platform fee
            treasury: balance::zero(),
        };
        
        // Transfer to a shared object or keep as owned
        transfer::share_object(state);
    }

    /// Create a new dataset
    #[allow(lint(public_entry))]
    public entry fun create_dataset(
        title: vector<u8>,
        description: vector<u8>,
        category: u8,
        pricing_model: u8,
        walrus_blob_id: vector<u8>,
        metadata_blob_id: vector<u8>,  // Empty vector means None
        schema_hash: vector<u8>,
        data_hash: vector<u8>,
        price: u64,                     // 0 means None for free content
        subscription_duration_ms: u64,  // 0 means None
        tags: vector<vector<u8>>,
        royalty_percentage: u8,
        ctx: &mut TxContext
    ) {
        // Validation
        assert!(vector::length(&title) > 0, E_INVALID_TITLE);
        assert!(category <= CATEGORY_OTHER, E_INVALID_CATEGORY);
        assert!(pricing_model <= PRICING_FREE, E_INVALID_PRICING_MODEL);
        assert!(royalty_percentage <= 100, E_INVALID_ROYALTY);
        
        // Premium content must have a price
        if (pricing_model != PRICING_FREE) {
            assert!(price > 0, E_INVALID_PRICE);
        };

        let producer = tx_context::sender(ctx);
        let timestamp = tx_context::epoch_timestamp_ms(ctx);

        // Convert metadata_blob_id to Option
        let metadata_option = if (vector::length(&metadata_blob_id) == 0) {
            option::none<vector<u8>>()
        } else {
            option::some(metadata_blob_id)
        };

        // Convert price to Option
        let price_option = if (pricing_model != PRICING_FREE && price > 0) {
            option::some(price)
        } else {
            option::none<u64>()
        };

        // Convert subscription_duration_ms to Option
        let subscription_option = if (pricing_model == PRICING_SUBSCRIPTION && subscription_duration_ms > 0) {
            option::some(subscription_duration_ms)
        } else {
            option::none<u64>()
        };

        // Save title for event before creating dataset
        let title_for_event = title;

        // Create the Dataset NFT
        let dataset = DatasetNFT {
            id: sui::object::new(ctx),
            title,
            description,
            producer,
            category,
            pricing_model,
            price: price_option,
            subscription_duration_ms: subscription_option,
            walrus_blob_id,
            metadata_blob_id: metadata_option,
            schema_hash,
            data_hash,
            tags,
            created_at: timestamp,
            updated_at: timestamp,
            total_sales: 0,
            total_revenue: 0,
            views: 0,
            is_active: true,
            royalty_percentage,
            producer_reward_pool: balance::zero(),
        };

        let dataset_id = sui::object::id(&dataset);
        
        // Share the dataset so anyone can purchase it
        transfer::share_object(dataset);

        // Emit event
        event::emit(Dataset_Created {
            dataset_id,
            producer,
            title: title_for_event,
            category,
            pricing_model,
        });
    }

    /// Purchase access to a dataset
    #[allow(lint(public_entry))]
    public entry fun purchase_dataset(
        dataset: &mut DatasetNFT,
        payment: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        assert!(dataset.is_active, E_DATASET_NOT_ACTIVE);
        assert!(dataset.pricing_model != PRICING_FREE, E_INVALID_PRICING_MODEL);
        assert!(option::is_some(&dataset.price), E_INVALID_PRICE);
        
        let price = *option::borrow(&dataset.price);
        let buyer = tx_context::sender(ctx);
        let timestamp = tx_context::epoch_timestamp_ms(ctx);
        
        // Verify payment amount
        let payment_amount = coin::value(&payment);
        assert!(payment_amount >= price, E_INSUFFICIENT_PAYMENT);

        // Calculate expiration time for subscription model
        let expires_at = if (dataset.pricing_model == PRICING_SUBSCRIPTION) {
            let duration = *option::borrow(&dataset.subscription_duration_ms);
            option::some(timestamp + duration)
        } else {
            option::none<u64>() // Lifetime access for fixed price
        };

        // Calculate max accesses for per-access model
        let max_accesses = if (dataset.pricing_model == PRICING_PER_ACCESS) {
            option::some(1) // Single access per purchase
        } else {
            option::none<u64>() // Unlimited for other models
        };

        // Create access token
        let access_token = DataAccessToken {
            id: sui::object::new(ctx),
            dataset_id: sui::object::id(dataset),
            owner: buyer,
            purchased_at: timestamp,
            expires_at,
            access_count: 0,
            max_accesses,
        };

        let access_token_id = sui::object::id(&access_token);

        // Distribute revenue (payment is consumed in this function)
        let (producer_amount, platform_amount) = distribute_revenue(
            dataset,
            price,
            payment_amount,
            payment,
            ctx
        );

        // Update dataset statistics
        dataset.total_sales = dataset.total_sales + 1;
        dataset.total_revenue = dataset.total_revenue + price;
        dataset.updated_at = timestamp;

        // Transfer access token to buyer
        transfer::transfer(access_token, buyer);

        // Emit events
        event::emit(Dataset_Purchased {
            dataset_id: sui::object::id(dataset),
            buyer,
            access_token_id,
            price,
            pricing_model: dataset.pricing_model,
        });

        event::emit(Revenue_Distributed {
            dataset_id: sui::object::id(dataset),
            producer: dataset.producer,
            producer_amount,
            platform_amount,
        });
    }

    /// Use dataset access (increment access count)
    #[allow(lint(public_entry))]
    public entry fun use_dataset_access(
        dataset: &mut DatasetNFT,
        access_token: &mut DataAccessToken,
        ctx: &mut TxContext
    ) {
        let user = tx_context::sender(ctx);
        assert!(access_token.dataset_id == sui::object::id(dataset), E_INVALID_PRICING_MODEL);
        assert!(access_token.owner == user, E_NOT_PRODUCER);

        // Check expiration
        if (option::is_some(&access_token.expires_at)) {
            let expiry = *option::borrow(&access_token.expires_at);
            let now = tx_context::epoch_timestamp_ms(ctx);
            assert!(now < expiry, E_ACCESS_EXPIRED);
        };

        // Check access limit
        if (option::is_some(&access_token.max_accesses)) {
            let max = *option::borrow(&access_token.max_accesses);
            assert!(access_token.access_count < max, E_ACCESS_LIMIT_REACHED);
        };

        // Increment access count
        access_token.access_count = access_token.access_count + 1;
        dataset.views = dataset.views + 1;

        // Emit event
        event::emit(Access_Used {
            dataset_id: sui::object::id(dataset),
            access_token_id: sui::object::id(access_token),
            user,
        });
    }

    /// Update dataset (only by producer)
    #[allow(lint(public_entry))]
    public entry fun update_dataset(
        dataset: &mut DatasetNFT,
        new_title: vector<u8>,
        new_description: vector<u8>,
        new_price: u64,  // 0 means keep current
        new_is_active: bool,
        ctx: &mut TxContext
    ) {
        let producer = tx_context::sender(ctx);
        assert!(dataset.producer == producer, E_NOT_PRODUCER);

        if (vector::length(&new_title) > 0) {
            dataset.title = new_title;
        };
        if (vector::length(&new_description) > 0) {
            dataset.description = new_description;
        };
        if (new_price > 0 && option::is_some(&dataset.price)) {
            dataset.price = option::some(new_price);
        };
        dataset.is_active = new_is_active;
        dataset.updated_at = tx_context::epoch_timestamp_ms(ctx);

        event::emit(Dataset_Updated {
            dataset_id: sui::object::id(dataset),
            producer,
        });
    }


    /// Withdraw producer rewards
    #[allow(lint(public_entry), lint(custom_state_change))]
    public entry fun withdraw_producer_rewards(
        dataset: DatasetNFT,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let producer = tx_context::sender(ctx);
        assert!(dataset.producer == producer, E_NOT_PRODUCER);
        
        let balance_value = balance::value(&dataset.producer_reward_pool);
        assert!(balance_value >= amount, E_INSUFFICIENT_PAYMENT);

        // Destructure the struct to access all fields including the balance
        let DatasetNFT {
            id,
            title,
            description,
            producer: _,
            category,
            pricing_model,
            price,
            subscription_duration_ms,
            walrus_blob_id,
            metadata_blob_id,
            schema_hash,
            data_hash,
            tags,
            created_at,
            updated_at,
            total_sales,
            total_revenue,
            views,
            is_active,
            royalty_percentage,
            producer_reward_pool: pool,
        } = dataset;
        
        // Delete the old object (this consumes the UID)
        object::delete(id);
        
        // Convert balance to coin
        let mut total_coin = coin::from_balance(pool, ctx);
        
        // Split to get reward amount
        let reward_coin = coin::split(&mut total_coin, amount, ctx);
        
        // Convert remainder back to balance
        let remainder_balance = coin::into_balance(total_coin);
        
        // Create new object with updated balance
        let updated_dataset = DatasetNFT {
            id: object::new(ctx),
            title,
            description,
            producer,
            category,
            pricing_model,
            price,
            subscription_duration_ms,
            walrus_blob_id,
            metadata_blob_id,
            schema_hash,
            data_hash,
            tags,
            created_at,
            updated_at,
            total_sales,
            total_revenue,
            views,
            is_active,
            royalty_percentage,
            producer_reward_pool: remainder_balance,
        };
        
        // Transfer the reward coin to producer
        transfer::public_transfer(reward_coin, producer);
        
        // Transfer the updated dataset back to the producer
        transfer::transfer(updated_dataset, producer);
    }

    /// Internal function to distribute revenue
    #[allow(lint(self_transfer))]
    fun distribute_revenue(
        dataset: &mut DatasetNFT,
        price: u64,
        payment_amount: u64,
        mut payment: Coin<SUI>,
        ctx: &mut TxContext
    ): (u64, u64) {
        // Platform fee (default 5%, can be configured)
        let platform_fee_percentage = 5;
        let platform_fee = (price * (platform_fee_percentage as u64)) / 100;
        let producer_amount = price - platform_fee;

        // Split payment
        if (payment_amount == price) {
            // Split the coin
            let platform_coin = coin::split(&mut payment, platform_fee, ctx);
            let producer_coin = coin::split(&mut payment, producer_amount, ctx);
            
            // Transfer platform fee to treasury (simplified - using @0x0)
            transfer::public_transfer(platform_coin, @0x0);
            
            // Add to producer reward pool
            let producer_balance = coin::into_balance(producer_coin);
            balance::join(&mut dataset.producer_reward_pool, producer_balance);
            
            // Consume remaining payment (should be zero, join to producer pool)
            let remaining_balance = coin::into_balance(payment);
            balance::join(&mut dataset.producer_reward_pool, remaining_balance);
        } else {
            // Payment is more than price
            let platform_coin = coin::split(&mut payment, platform_fee, ctx);
            let producer_coin = coin::split(&mut payment, producer_amount, ctx);
            let refund_amount = payment_amount - price;
            let refund_coin = coin::split(&mut payment, refund_amount, ctx);
            
            // Transfer platform fee
            transfer::public_transfer(platform_coin, @0x0);
            
            // Add to producer reward pool
            let producer_balance = coin::into_balance(producer_coin);
            balance::join(&mut dataset.producer_reward_pool, producer_balance);
            
            // Return refund
            transfer::public_transfer(refund_coin, tx_context::sender(ctx));
            
            // Consume remaining payment (should be zero, join to producer pool)
            let remaining_balance = coin::into_balance(payment);
            balance::join(&mut dataset.producer_reward_pool, remaining_balance);
        };

        (producer_amount, platform_fee)
    }

    /// Getter functions
    public fun get_producer(dataset: &DatasetNFT): address {
        dataset.producer
    }

    public fun get_price(dataset: &DatasetNFT): Option<u64> {
        dataset.price
    }

    public fun get_total_sales(dataset: &DatasetNFT): u64 {
        dataset.total_sales
    }

    public fun get_total_revenue(dataset: &DatasetNFT): u64 {
        dataset.total_revenue
    }

    public fun get_views(dataset: &DatasetNFT): u64 {
        dataset.views
    }

    public fun get_reward_pool_balance(dataset: &DatasetNFT): u64 {
        balance::value(&dataset.producer_reward_pool)
    }

    /// Stake SUI on a dataset to earn rewards
    #[allow(lint(public_entry))]
    public entry fun stake_on_dataset(
        dataset: &mut DatasetNFT,
        payment: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        assert!(dataset.is_active, E_DATASET_NOT_ACTIVE);
        
        let staker = tx_context::sender(ctx);
        let stake_amount = coin::value(&payment);
        assert!(stake_amount > 0, E_INVALID_PAYMENT);
        
        let timestamp = tx_context::epoch_timestamp_ms(ctx);
        
        // Create stake record
        let stake = DatasetStake {
            id: sui::object::new(ctx),
            dataset_id: sui::object::id(dataset),
            staker,
            amount: stake_amount,
            staked_at: timestamp,
        };
        
        // Add stake amount to producer reward pool
        let payment_balance = coin::into_balance(payment);
        balance::join(&mut dataset.producer_reward_pool, payment_balance);
        
        // Transfer stake record to staker
        transfer::transfer(stake, staker);
        
        // Emit event
        event::emit(Dataset_Staked {
            dataset_id: sui::object::id(dataset),
            staker,
            amount: stake_amount,
        });
    }

    /// Unstake and withdraw rewards
    /// Returns the original stake amount plus proportional rewards from the pool
    #[allow(lint(public_entry))]
    public entry fun unstake_dataset(
        dataset: &mut DatasetNFT,
        stake: DatasetStake,
        ctx: &mut TxContext
    ) {
        assert!(dataset.is_active, E_DATASET_NOT_ACTIVE);
        
        let staker = tx_context::sender(ctx);
        assert!(stake.staker == staker, E_NOT_STAKER);
        
        let stake_amount = stake.amount;
        let pool_balance = balance::value(&dataset.producer_reward_pool);
        
        // Calculate proportional reward (simple: stake_amount / total_staked gets proportional share)
        // For simplicity, we'll give back the stake amount plus a small reward
        // In a more sophisticated system, you'd track total staked and calculate based on that
        let reward_percentage = 5; // 5% reward rate
        let days_staked = (tx_context::epoch_timestamp_ms(ctx) - stake.staked_at) / (1000 * 60 * 60 * 24);
        let days_staked_u64 = if (days_staked > 365) { 365 } else { days_staked };
        
        // Calculate reward: stake_amount * reward_rate * days / 365
        let reward_amount = (stake_amount * reward_percentage * days_staked_u64) / (100 * 365);
        
        // Ensure we have enough in the pool (at least the stake amount)
        let total_withdrawal = stake_amount + reward_amount;
        assert!(pool_balance >= total_withdrawal, E_INSUFFICIENT_REWARDS);
        
        // Withdraw from pool - we need to extract the balance, convert to coin, split, and return remainder
        // Since we can't directly withdraw from a mutable reference, we'll use a workaround:
        // Extract all, use what we need, return the rest
        let extracted_balance = balance::withdraw(&mut dataset.producer_reward_pool, total_withdrawal);
        let withdrawal_coin = coin::from_balance(extracted_balance, ctx);
        
        // Transfer withdrawal to staker
        transfer::public_transfer(withdrawal_coin, staker);
        
        // Delete the stake object
        let DatasetStake { id, dataset_id: _, staker: _, amount: _, staked_at: _ } = stake;
        sui::object::delete(id);
        
        // Emit event
        event::emit(Dataset_Unstaked {
            dataset_id: sui::object::id(dataset),
            staker,
            amount: stake_amount,
            reward: reward_amount,
        });
    }

