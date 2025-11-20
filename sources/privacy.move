/// Privacy Module - Data Protection and Compliance
/// Utilizes Walrus, Seal, and Sui Stack for privacy, fraud detection, and compliance

module trixxy::privacy {
    use sui::event;

    /// Privacy Settings
    public struct PrivacySettings has key, store {
        id: UID,
        owner: address,
        data_encryption: bool,
        zero_knowledge_proofs: bool,
        data_retention_days: u64,
        share_with_third_parties: bool,
        analytics_opt_in: bool,
        marketing_opt_in: bool,
        compliance_mode: u8, // 0=GDPR, 1=CCPA, 2=None
        updated_at: u64,
    }

    /// Verifiable Storage Record
    public struct VerifiableStorage has key, store {
        id: UID,
        data_hash: vector<u8>,
        storage_proof: vector<u8>,
        walrus_blob_id: vector<u8>,
        owner: address,
        created_at: u64,
        verified: bool,
    }

    /// Zero-Knowledge Proof
    public struct ZKProof has key, store {
        id: UID,
        statement: vector<u8>,
        proof: vector<u8>,
        public_inputs: vector<vector<u8>>,
        verified: bool,
        creator: address,
        created_at: u64,
    }

    /// Fraud Detection Record
    public struct FraudRecord has key, store {
        id: UID,
        user_id: address,
        risk_score: u8, // 0-100
        flags: vector<u8>, // Flag types
        timestamp: u64,
        resolved: bool,
    }

    /// Data Deletion Request (GDPR/CCPA)
    public struct DataDeletionRequest has key, store {
        id: UID,
        user_id: address,
        data_types: vector<vector<u8>>,
        requested_at: u64,
        status: u8, // 0=pending, 1=processing, 2=completed, 3=rejected
        completed_at: Option<u64>,
    }

    /// Data Access Log
    public struct DataAccessLog has key, store {
        id: UID,
        user_id: address,
        data_type: vector<u8>,
        access_type: u8, // 0=read, 1=write, 2=delete
        authorized: bool,
        timestamp: u64,
    }

    /// Events
    public struct Privacy_Settings_Updated has copy, drop {
        owner: address,
        compliance_mode: u8,
    }

    public struct Storage_Verified has copy, drop {
        storage_id: ID,
        data_hash: vector<u8>,
        verified: bool,
    }

    public struct ZK_Proof_Created has copy, drop {
        proof_id: ID,
        creator: address,
        statement: vector<u8>,
    }

    public struct Fraud_Detected has copy, drop {
        user_id: address,
        risk_score: u8,
        flags: vector<u8>,
    }

    public struct Data_Deletion_Requested has copy, drop {
        request_id: ID,
        user_id: address,
        data_types: vector<vector<u8>>,
    }

    public struct Data_Access_Logged has copy, drop {
        user_id: address,
        data_type: vector<u8>,
        access_type: u8,
        authorized: bool,
    }

    /// Error codes
    const E_UNAUTHORIZED: u64 = 0;
    const E_INVALID_COMPLIANCE_MODE: u64 = 1;
    const E_INVALID_RISK_SCORE: u64 = 2;
    const E_PROOF_VERIFICATION_FAILED: u64 = 3;

    /// Create or update privacy settings
    #[allow(lint(public_entry))]
    public entry fun update_privacy_settings(
        settings: &mut PrivacySettings,
        data_encryption: bool,
        zero_knowledge_proofs: bool,
        data_retention_days: u64,
        share_with_third_parties: bool,
        analytics_opt_in: bool,
        marketing_opt_in: bool,
        compliance_mode: u8,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(settings.owner == sender, E_UNAUTHORIZED);
        assert!(compliance_mode <= 2, E_INVALID_COMPLIANCE_MODE);

        settings.data_encryption = data_encryption;
        settings.zero_knowledge_proofs = zero_knowledge_proofs;
        settings.data_retention_days = data_retention_days;
        settings.share_with_third_parties = share_with_third_parties;
        settings.analytics_opt_in = analytics_opt_in;
        settings.marketing_opt_in = marketing_opt_in;
        settings.compliance_mode = compliance_mode;
        settings.updated_at = tx_context::epoch_timestamp_ms(ctx);

        event::emit(Privacy_Settings_Updated {
            owner: sender,
            compliance_mode,
        });
    }

    /// Create privacy settings
    #[allow(lint(public_entry))]
    public entry fun create_privacy_settings(
        data_encryption: bool,
        zero_knowledge_proofs: bool,
        data_retention_days: u64,
        share_with_third_parties: bool,
        analytics_opt_in: bool,
        marketing_opt_in: bool,
        compliance_mode: u8,
        ctx: &mut TxContext
    ) {
        assert!(compliance_mode <= 2, E_INVALID_COMPLIANCE_MODE);

        let sender = tx_context::sender(ctx);
        let timestamp = tx_context::epoch_timestamp_ms(ctx);

        let settings = PrivacySettings {
            id: sui::object::new(ctx),
            owner: sender,
            data_encryption,
            zero_knowledge_proofs,
            data_retention_days,
            share_with_third_parties,
            analytics_opt_in,
            marketing_opt_in,
            compliance_mode,
            updated_at: timestamp,
        };

        transfer::transfer(settings, sender);

        event::emit(Privacy_Settings_Updated {
            owner: sender,
            compliance_mode,
        });
    }

    /// Create verifiable storage record
    #[allow(lint(public_entry))]
    public entry fun create_verifiable_storage(
        data_hash: vector<u8>,
        storage_proof: vector<u8>,
        walrus_blob_id: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let timestamp = tx_context::epoch_timestamp_ms(ctx);

        let storage = VerifiableStorage {
            id: sui::object::new(ctx),
            data_hash,
            storage_proof,
            walrus_blob_id,
            owner: sender,
            created_at: timestamp,
            verified: true, // Would be verified off-chain
        };

        let storage_id = sui::object::id(&storage);
        transfer::transfer(storage, sender);

        event::emit(Storage_Verified {
            storage_id,
            data_hash,
            verified: true,
        });
    }

    /// Create zero-knowledge proof
    #[allow(lint(public_entry))]
    public entry fun create_zk_proof(
        statement: vector<u8>,
        proof: vector<u8>,
        public_inputs: vector<vector<u8>>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let timestamp = tx_context::epoch_timestamp_ms(ctx);

        // In a real implementation, verify the proof here
        let verified = true; // Placeholder

        let zk_proof = ZKProof {
            id: sui::object::new(ctx),
            statement,
            proof,
            public_inputs,
            verified,
            creator: sender,
            created_at: timestamp,
        };

        let proof_id = sui::object::id(&zk_proof);
        transfer::transfer(zk_proof, sender);

        event::emit(ZK_Proof_Created {
            proof_id,
            creator: sender,
            statement,
        });
    }

    /// Record fraud detection
    #[allow(lint(public_entry))]
    public entry fun record_fraud_detection(
        user_id: address,
        risk_score: u8,
        flags: vector<u8>,
        ctx: &mut TxContext
    ) {
        assert!(risk_score <= 100, E_INVALID_RISK_SCORE);

        let timestamp = tx_context::epoch_timestamp_ms(ctx);

        let fraud_record = FraudRecord {
            id: sui::object::new(ctx),
            user_id,
            risk_score,
            flags,
            timestamp,
            resolved: false,
        };

        transfer::transfer(fraud_record, user_id);

        event::emit(Fraud_Detected {
            user_id,
            risk_score,
            flags,
        });
    }

    /// Request data deletion (GDPR/CCPA)
    #[allow(lint(public_entry))]
    public entry fun request_data_deletion(
        user_id: address,
        data_types: vector<vector<u8>>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(sender == user_id, E_UNAUTHORIZED);

        let timestamp = tx_context::epoch_timestamp_ms(ctx);

        let request = DataDeletionRequest {
            id: sui::object::new(ctx),
            user_id,
            data_types,
            requested_at: timestamp,
            status: 0, // Pending
            completed_at: option::none<u64>(),
        };

        let request_id = sui::object::id(&request);
        transfer::transfer(request, sender);

        event::emit(Data_Deletion_Requested {
            request_id,
            user_id,
            data_types,
        });
    }

    /// Log data access
    #[allow(lint(public_entry))]
    public entry fun log_data_access(
        user_id: address,
        data_type: vector<u8>,
        access_type: u8,
        authorized: bool,
        ctx: &mut TxContext
    ) {
        let timestamp = tx_context::epoch_timestamp_ms(ctx);

        let log = DataAccessLog {
            id: sui::object::new(ctx),
            user_id,
            data_type,
            access_type,
            authorized,
            timestamp,
        };

        transfer::transfer(log, user_id);

        event::emit(Data_Access_Logged {
            user_id,
            data_type,
            access_type,
            authorized,
        });
    }

    /// Getter functions
    public fun get_risk_score(record: &FraudRecord): u8 {
        record.risk_score
    }

    public fun is_verified(storage: &VerifiableStorage): bool {
        storage.verified
    }

    public fun is_proof_verified(proof: &ZKProof): bool {
        proof.verified
    }
}

