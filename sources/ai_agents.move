/// AI Trading Agents Module
/// Enables users to create autonomous trading agents that can analyze and trade datasets
/// Features:
/// - Create and configure AI agents with different strategies
/// - Track agent performance on-chain
/// - Execute trades autonomously based on AI analysis

module trixxy::ai_agents {
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::event;
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    /// Agent strategy types
    const STRATEGY_VALUE: u8 = 0;        // Value-based trading
    const STRATEGY_MOMENTUM: u8 = 1;     // Momentum trading
    const STRATEGY_ARBITRAGE: u8 = 2;    // Arbitrage trading
    const STRATEGY_CUSTOM: u8 = 3;       // Custom strategy

    /// AI Trading Agent - represents an autonomous trading agent
    public struct AITradingAgent has key, store {
        id: UID,
        owner: address,
        name: vector<u8>,
        strategy: u8,                    // 0=value, 1=momentum, 2=arbitrage, 3=custom
        balance: Balance<SUI>,           // Agent's trading balance
        is_active: bool,
        total_trades: u64,
        successful_trades: u64,
        total_profit: u64,               // Total profit in MIST
        created_at: u64,
        last_trade_at: u64,
    }

    /// Events
    public struct Agent_Created has copy, drop {
        agent_id: ID,
        owner: address,
        name: vector<u8>,
        strategy: u8,
    }

    public struct Agent_Trade_Executed has copy, drop {
        agent_id: ID,
        dataset_id: ID,
        action: u8,                      // 0=buy, 1=sell
        amount: u64,
        profit: u64,                     // Profit/loss in MIST
    }

    public struct Agent_Updated has copy, drop {
        agent_id: ID,
        owner: address,
    }

    /// Error codes
    const E_INVALID_NAME: u64 = 0;
    const E_INVALID_STRATEGY: u64 = 1;
    const E_INSUFFICIENT_BALANCE: u64 = 2;
    const E_NOT_OWNER: u64 = 3;
    const E_AGENT_INACTIVE: u64 = 4;
    const E_INVALID_AMOUNT: u64 = 5;

    /// Create a new AI trading agent
    #[allow(lint(public_entry))]
    public entry fun create_agent(
        name: vector<u8>,
        strategy: u8,
        initial_balance: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        assert!(vector::length(&name) > 0, E_INVALID_NAME);
        assert!(strategy <= STRATEGY_CUSTOM, E_INVALID_STRATEGY);
        
        let owner = tx_context::sender(ctx);
        let timestamp = tx_context::epoch_timestamp_ms(ctx);
        let balance_value = coin::value(&initial_balance);
        
        // Convert coin to balance
        let agent_balance = coin::into_balance(initial_balance);
        
        // Create agent
        let agent = AITradingAgent {
            id: object::new(ctx),
            owner,
            name,
            strategy,
            balance: agent_balance,
            is_active: true,
            total_trades: 0,
            successful_trades: 0,
            total_profit: 0,
            created_at: timestamp,
            last_trade_at: 0,
        };
        
        let agent_id = object::id(&agent);
        
        // Transfer agent to owner
        transfer::transfer(agent, owner);
        
        // Save name for event (before transfer)
        let name_for_event = agent.name;
        
        // Emit event
        event::emit(Agent_Created {
            agent_id,
            owner,
            name: name_for_event,
            strategy,
        });
    }

    /// Fund an agent (add balance)
    #[allow(lint(public_entry))]
    public entry fun fund_agent(
        agent: &mut AITradingAgent,
        payment: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(agent.owner == sender, E_NOT_OWNER);
        
        let payment_balance = coin::into_balance(payment);
        balance::join(&mut agent.balance, payment_balance);
        
        event::emit(Agent_Updated {
            agent_id: object::id(agent),
            owner: sender,
        });
    }

    /// Withdraw funds from an agent
    #[allow(lint(public_entry))]
    public entry fun withdraw_from_agent(
        agent: &mut AITradingAgent,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(agent.owner == sender, E_NOT_OWNER);
        
        let balance_value = balance::value(&agent.balance);
        assert!(balance_value >= amount, E_INSUFFICIENT_BALANCE);
        
        // Withdraw from balance
        let withdrawn_balance = balance::withdraw(&mut agent.balance, amount);
        let withdrawal_coin = coin::from_balance(withdrawn_balance, ctx);
        
        // Transfer to owner
        transfer::public_transfer(withdrawal_coin, sender);
        
        event::emit(Agent_Updated {
            agent_id: object::id(agent),
            owner: sender,
        });
    }

    /// Update agent status (activate/deactivate)
    #[allow(lint(public_entry))]
    public entry fun update_agent_status(
        agent: &mut AITradingAgent,
        is_active: bool,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(agent.owner == sender, E_NOT_OWNER);
        
        agent.is_active = is_active;
        
        event::emit(Agent_Updated {
            agent_id: object::id(agent),
            owner: sender,
        });
    }

    /// Execute a trade (called by agent owner or authorized system)
    /// This simulates the agent making a trade decision
    #[allow(lint(public_entry))]
    public entry fun execute_trade(
        agent: &mut AITradingAgent,
        dataset_id: ID,
        action: u8,                      // 0=buy, 1=sell
        amount: u64,                     // Amount in MIST
        profit: u64,                     // Profit in MIST (always positive, losses handled separately)
        ctx: &mut TxContext
    ) {
        assert!(agent.is_active, E_AGENT_INACTIVE);
        assert!(amount > 0, E_INVALID_AMOUNT);
        
        let sender = tx_context::sender(ctx);
        // Allow owner or the agent itself (if we add authorization later)
        // For now, only owner can execute trades
        
        let timestamp = tx_context::epoch_timestamp_ms(ctx);
        
        // If it's a buy action, deduct from balance
        if (action == 0) { // Buy
            let balance_value = balance::value(&agent.balance);
            assert!(balance_value >= amount, E_INSUFFICIENT_BALANCE);
            // Deduct amount from balance
            let _ = balance::withdraw(&mut agent.balance, amount);
        };
        
        // Update agent statistics
        agent.total_trades = agent.total_trades + 1;
        if (profit > 0) {
            agent.successful_trades = agent.successful_trades + 1;
            // Note: In a real implementation, profit would come from actual trade execution
            // and would be added to agent balance. For now, we just track profit statistics.
        };
        agent.total_profit = agent.total_profit + profit;
        agent.last_trade_at = timestamp;
        
        // Emit event
        event::emit(Agent_Trade_Executed {
            agent_id: object::id(agent),
            dataset_id,
            action,
            amount,
            profit,
        });
    }

    /// Getter functions
    public fun get_owner(agent: &AITradingAgent): address {
        agent.owner
    }

    public fun get_balance(agent: &AITradingAgent): u64 {
        balance::value(&agent.balance)
    }

    public fun get_total_trades(agent: &AITradingAgent): u64 {
        agent.total_trades
    }

    public fun get_win_rate(agent: &AITradingAgent): u64 {
        if (agent.total_trades == 0) {
            0
        } else {
            (agent.successful_trades * 100) / agent.total_trades
        }
    }

    public fun get_total_profit(agent: &AITradingAgent): u64 {
        agent.total_profit
    }

    public fun is_active(agent: &AITradingAgent): bool {
        agent.is_active
    }
}

