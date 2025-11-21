/// Nautilus Module - On-Chain Authenticity & Trust
/// Verifies media provenance, creates trust oracles, and enables prediction markets

module trixxy::nautilus {
    use sui::event;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;

    /// Provenance Record for media/datasets
    public struct ProvenanceRecord has key, store {
        id: UID,
        media_id: vector<u8>,
        creator: address,
        timestamp: u64,
        hash: vector<u8>,              // Hash of the media/dataset
        original_source: vector<u8>,
        creation_method: vector<u8>,
        tools: vector<vector<u8>>,
        license: vector<u8>,
        verification_status: u8,      // 0=pending, 1=verified, 2=rejected
        trust_score: u8,              // 0-100
        verifier: Option<address>,    // Address that verified (if verified)
    }

    /// AI Trust Oracle
    public struct AITrustOracle has key, store {
        id: UID,
        name: vector<u8>,
        model_id: vector<u8>,
        source: vector<u8>,
        source_hash: vector<u8>,
        source_verified: bool,
        training_data_ids: vector<vector<u8>>,
        training_data_hashes: vector<vector<u8>>,
        training_data_verified: bool,
        accuracy: u64,                // Scaled by 10000 (e.g., 9500 = 0.95)
        precision: u64,
        recall: u64,
        f1_score: u64,
        reliability_score: u64,       // Calculated average
        trust_score: u8,              // 0-100
        verification_count: u64,
        last_verified: u64,
        created_at: u64,
    }

    /// Prediction Market
    public struct PredictionMarket has key, store {
        id: UID,
        question: vector<u8>,
        description: vector<u8>,
        creator: address,
        outcomes: vector<vector<u8>>,
        end_time: u64,
        oracle_id: ID,                // Reference to trust oracle
        total_staked: u64,
        outcome_stakes: vector<u64>,   // Stakes per outcome
        status: u8,                   // 0=active, 1=resolved, 2=cancelled
        resolved_outcome: Option<u8>, // Index of winning outcome
        created_at: u64,
    }

    /// Market Stake
    public struct MarketStake has key, store {
        id: UID,
        market_id: ID,
        staker: address,
        outcome_index: u8,
        amount: u64,
        staked_at: u64,
    }

    /// Events
    public struct Provenance_Created has copy, drop {
        record_id: ID,
        media_id: vector<u8>,
        creator: address,
        hash: vector<u8>,
    }

    public struct Provenance_Verified has copy, drop {
        record_id: ID,
        verifier: address,
        trust_score: u8,
    }

    public struct AI_Oracle_Created has copy, drop {
        oracle_id: ID,
        model_id: vector<u8>,
        name: vector<u8>,
        trust_score: u8,
    }

    public struct Prediction_Market_Created has copy, drop {
        market_id: ID,
        creator: address,
        question: vector<u8>,
        oracle_id: ID,
    }

    public struct Market_Staked has copy, drop {
        market_id: ID,
        staker: address,
        outcome_index: u8,
        amount: u64,
    }

    public struct Market_Resolved has copy, drop {
        market_id: ID,
        winning_outcome: u8,
        total_payout: u64,
    }

    /// Error codes
    const E_INVALID_HASH: u64 = 0;
    #[allow(unused_const)]
    const E_INVALID_STATUS: u64 = 1;
    const E_MARKET_CLOSED: u64 = 2;
    const E_INVALID_OUTCOME: u64 = 3;
    #[allow(unused_const)]
    const E_INSUFFICIENT_STAKE: u64 = 4;
    const E_ALREADY_RESOLVED: u64 = 5;

    /// Create provenance record
    #[allow(lint(public_entry))]
    public entry fun create_provenance_record(
        media_id: vector<u8>,
        _creator: address,
        hash: vector<u8>,
        original_source: vector<u8>,
        creation_method: vector<u8>,
        tools: vector<vector<u8>>,
        license: vector<u8>,
        ctx: &mut TxContext
    ) {
        assert!(vector::length(&hash) > 0, E_INVALID_HASH);

        let timestamp = tx_context::epoch_timestamp_ms(ctx);
        let sender = tx_context::sender(ctx);

        let record = ProvenanceRecord {
            id: sui::object::new(ctx),
            media_id,
            creator: sender,
            timestamp,
            hash,
            original_source,
            creation_method,
            tools,
            license,
            verification_status: 0, // Pending
            trust_score: 0,
            verifier: option::none<address>(),
        };

        let record_id = sui::object::id(&record);
        transfer::transfer(record, sender);

        event::emit(Provenance_Created {
            record_id,
            media_id,
            creator: sender,
            hash,
        });
    }

    /// Verify provenance record
    #[allow(lint(public_entry))]
    public entry fun verify_provenance(
        record: &mut ProvenanceRecord,
        provided_hash: vector<u8>,
        ctx: &mut TxContext
    ) {
        let verifier = tx_context::sender(ctx);
        let timestamp = tx_context::epoch_timestamp_ms(ctx);

        // Verify hash matches
        let mut hash_matches = vector::length(&record.hash) == vector::length(&provided_hash);
        if (hash_matches) {
            let mut i = 0;
            while (i < vector::length(&record.hash)) {
                if (*vector::borrow(&record.hash, i) != *vector::borrow(&provided_hash, i)) {
                    hash_matches = false;
                    break
                };
                i = i + 1;
            };
        };

        // Calculate trust score
        let mut trust_score = 0u8;
        if (hash_matches) {
            trust_score = trust_score + 30;
        };

        // Metadata completeness (up to 20 points)
        if (vector::length(&record.original_source) > 0) {
            trust_score = trust_score + 5;
        };
        if (vector::length(&record.creation_method) > 0) {
            trust_score = trust_score + 5;
        };
        if (vector::length(&record.tools) > 0) {
            trust_score = trust_score + 5;
        };
        if (vector::length(&record.license) > 0) {
            trust_score = trust_score + 5;
        };

        // Age bonus (up to 20 points)
        let age_days = (timestamp - record.timestamp) / (1000 * 60 * 60 * 24);
        if (age_days > 30) {
            trust_score = trust_score + 20;
        } else {
            let age_bonus = (age_days * 20) / 30;
            trust_score = trust_score + (age_bonus as u8);
        };

        // Creator reputation (assume verified = 30 points)
        trust_score = trust_score + 30;

        // Cap at 100
        if (trust_score > 100) {
            trust_score = 100;
        };

        // Update record
        if (hash_matches) {
            record.verification_status = 1; // Verified
        } else {
            record.verification_status = 2; // Rejected
        };
        record.trust_score = trust_score;
        record.verifier = option::some(verifier);

        event::emit(Provenance_Verified {
            record_id: sui::object::id(record),
            verifier,
            trust_score,
        });
    }

    /// Create AI trust oracle
    #[allow(lint(public_entry))]
    public entry fun create_ai_trust_oracle(
        name: vector<u8>,
        model_id: vector<u8>,
        source: vector<u8>,
        source_hash: vector<u8>,
        source_verified: bool,
        training_data_ids: vector<vector<u8>>,
        training_data_hashes: vector<vector<u8>>,
        training_data_verified: bool,
        accuracy: u64,
        precision: u64,
        recall: u64,
        f1_score: u64,
        ctx: &mut TxContext
    ) {
        let timestamp = tx_context::epoch_timestamp_ms(ctx);
        let sender = tx_context::sender(ctx);

        // Calculate reliability score (average of metrics)
        let reliability_score = (accuracy + precision + recall + f1_score) / 4;

        // Calculate trust score
        let mut trust_score = 0u8;
        if (source_verified) {
            trust_score = trust_score + 30;
        };
        if (training_data_verified) {
            trust_score = trust_score + 30;
        };
        // Reliability contributes up to 40 points
        let reliability_points = (reliability_score * 40 / 10000) as u8;
        trust_score = trust_score + reliability_points;

        if (trust_score > 100) {
            trust_score = 100;
        };

        let oracle = AITrustOracle {
            id: sui::object::new(ctx),
            name,
            model_id,
            source,
            source_hash,
            source_verified,
            training_data_ids,
            training_data_hashes,
            training_data_verified,
            accuracy,
            precision,
            recall,
            f1_score,
            reliability_score,
            trust_score,
            verification_count: 0,
            last_verified: timestamp,
            created_at: timestamp,
        };

        let oracle_id = sui::object::id(&oracle);
        transfer::transfer(oracle, sender);

        event::emit(AI_Oracle_Created {
            oracle_id,
            model_id,
            name,
            trust_score,
        });
    }

    /// Create prediction market
    #[allow(lint(public_entry))]
    public entry fun create_prediction_market(
        question: vector<u8>,
        description: vector<u8>,
        outcomes: vector<vector<u8>>,
        end_time: u64,
        oracle_id: ID,
        ctx: &mut TxContext
    ) {
        assert!(vector::length(&outcomes) >= 2, E_INVALID_OUTCOME);

        let timestamp = tx_context::epoch_timestamp_ms(ctx);
        let sender = tx_context::sender(ctx);

        // Initialize outcome stakes
        let outcome_count = vector::length(&outcomes);
        let mut outcome_stakes = vector::empty<u64>();
        let mut i = 0;
        while (i < outcome_count) {
            vector::push_back(&mut outcome_stakes, 0);
            i = i + 1;
        };

        let market = PredictionMarket {
            id: sui::object::new(ctx),
            question,
            description,
            creator: sender,
            outcomes,
            end_time,
            oracle_id,
            total_staked: 0,
            outcome_stakes,
            status: 0, // Active
            resolved_outcome: option::none<u8>(),
            created_at: timestamp,
        };

        let market_id = sui::object::id(&market);
        // Share the market so anyone can stake on it
        transfer::share_object(market);

        event::emit(Prediction_Market_Created {
            market_id,
            creator: sender,
            question,
            oracle_id,
        });
    }

    // Stake on prediction market outcome
    // Note: Market must be shared for this to work with multiple users
    #[allow(lint(public_entry))]
    public entry fun stake_on_market(
        market: &mut PredictionMarket,
        outcome_index: u8,
        payment: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        assert!(market.status == 0, E_MARKET_CLOSED); // Must be active
        assert!(outcome_index < (vector::length(&market.outcomes) as u8), E_INVALID_OUTCOME);

        let timestamp = tx_context::epoch_timestamp_ms(ctx);
        assert!(timestamp < market.end_time, E_MARKET_CLOSED);

        let staker = tx_context::sender(ctx);
        let stake_amount = coin::value(&payment);

        // Update market stakes
        let outcome_stake = *vector::borrow_mut(&mut market.outcome_stakes, (outcome_index as u64));
        *vector::borrow_mut(&mut market.outcome_stakes, (outcome_index as u64)) = outcome_stake + stake_amount;
        market.total_staked = market.total_staked + stake_amount;

        // Create stake record
        let stake = MarketStake {
            id: sui::object::new(ctx),
            market_id: sui::object::id(market),
            staker,
            outcome_index,
            amount: stake_amount,
            staked_at: timestamp,
        };

        transfer::transfer(stake, staker);

        // Transfer payment to market (would need treasury or escrow)
        transfer::public_transfer(payment, @0x0);

        event::emit(Market_Staked {
            market_id: sui::object::id(market),
            staker,
            outcome_index,
            amount: stake_amount,
        });
    }

    // Resolve prediction market
    // Note: Market must be shared for this to work
    #[allow(lint(public_entry))]
    public entry fun resolve_market(
        market: &mut PredictionMarket,
        winning_outcome: u8,
        ctx: &mut TxContext
    ) {
        assert!(market.status == 0, E_ALREADY_RESOLVED);
        assert!(winning_outcome < (vector::length(&market.outcomes) as u8), E_INVALID_OUTCOME);

        let timestamp = tx_context::epoch_timestamp_ms(ctx);
        assert!(timestamp >= market.end_time, E_MARKET_CLOSED);

        market.status = 1; // Resolved
        market.resolved_outcome = option::some(winning_outcome);

        let total_payout = market.total_staked; // All stakes go to winners (proportional)

        event::emit(Market_Resolved {
            market_id: sui::object::id(market),
            winning_outcome,
            total_payout,
        });
    }

    /// Getter functions
    public fun get_trust_score(record: &ProvenanceRecord): u8 {
        record.trust_score
    }

    public fun get_oracle_trust_score(oracle: &AITrustOracle): u8 {
        oracle.trust_score
    }

    public fun get_market_status(market: &PredictionMarket): u8 {
        market.status
    }
}

