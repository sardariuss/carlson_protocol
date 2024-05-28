import CarlsonProtocol    "../src/main";
import Account            "../src/Account";
import Types              "../src/Types";
import Duration           "../src/Duration";

import Token              "mo:icrc2-mo/ICRC2/Canisters/Token";
import ICRC1              "mo:icrc1-mo/ICRC1";

import Principal          "mo:base/Principal";
import Debug              "mo:base/Debug";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Int                "mo:base/Int";
import Time               "mo:base/Time";
import Nat64              "mo:base/Nat64";
import Float              "mo:base/Float";

shared actor class Main() = this {

    let NOMINAL_DURATION_PER_SAT = #NS(100);

    // Utility function to convert seconds to satoshis
    func duration_to_sat(duration : Types.Duration) : Nat {
        return Int.abs(Float.toInt(Float.fromInt(Duration.toTime(duration)) / Float.fromInt(Duration.toTime(NOMINAL_DURATION_PER_SAT))));
    };

    public shared func run() : async () {

        let owner = Principal.fromActor(this);

        // Fee to create token canister
        ExperimentalCycles.add<system>(50_000_000_000);

        let deposit_ledger = await Token.Token((
            {
                name : ?Text = ?"deposit_ledger";
                symbol : ?Text = ?"deposit_ledger_symbol";
                logo : ?Text = ?"deposit_ledger_logo";
                decimals : Nat8 = 8;
                fee : ?ICRC1.Fee = ?#Fixed(10);
                minting_account : ?ICRC1.Account = ?{ owner; subaccount = null; };
                max_supply : ?ICRC1.Balance = ?2_100_000_000_000_000;
                min_burn_amount : ?ICRC1.Balance = ?1;
                max_memo : ?Nat = ?1000;
                /// optional settings for the icrc1 canister
                advanced_settings = null;
                metadata = null;
                fee_collector = null;
                transaction_window = null;
                permitted_drift = null;
                max_accounts = null;
                settle_to_accounts = null;
            },
            {
                max_approvals_per_account = ?1_000;
                max_allowance = ?#TotalSupply;
                fee = ?#Fixed(10);
                /// optional settings for the icrc2 canister
                advanced_settings= null;
                max_approvals= null;
                settle_to_approvals= null;
            }
        ));
        
        // Fee to create token canister
        ExperimentalCycles.add<system>(50_000_000_000);

        let reward_ledger = await Token.Token((
            {
                name : ?Text = ?"reward_ledger";
                symbol : ?Text = ?"reward_ledger_symbol";
                logo : ?Text = ?"reward_ledger_logo";
                decimals : Nat8 = 8;
                fee : ?ICRC1.Fee = ?#Fixed(10);
                minting_account : ?ICRC1.Account = ?{ owner; subaccount = null; };
                max_supply : ?ICRC1.Balance = ?2_100_000_000_000_000;
                min_burn_amount : ?ICRC1.Balance = ?1;
                max_memo : ?Nat = ?1000;
                /// optional settings for the icrc1 canister
                advanced_settings = null;
                metadata = null;
                fee_collector = null;
                transaction_window = null;
                permitted_drift = null;
                max_accounts = null;
                settle_to_accounts = null;
            },
            {
                max_approvals_per_account = ?1_000;
                max_allowance = ?#TotalSupply;
                fee = ?#Fixed(10);
                /// optional settings for the icrc2 canister
                advanced_settings= null;
                max_approvals= null;
                settle_to_approvals= null;
            }
        ));

        // Fee to create protocol canister
        ExperimentalCycles.add<system>(50_000_000_000);

        let protocol = await CarlsonProtocol.CarlsonProtocol({
            deposit_ledger = Principal.fromActor(deposit_ledger);
            reward_ledger = Principal.fromActor(reward_ledger);
            parameters = {
                hotness_half_life = #DAYS(15);
                nominal_lock_duration = #DAYS(3);
                add_ballot_min_amount = 50;
                new_vote_min_amount = 100;
            };
        });

        // Mint all reward tokens for the procol to reward users
        switch(await reward_ledger.mint({
            to = { owner = Principal.fromActor(protocol); subaccount = null; };
            amount = 2_100_000_000_000_000;
            memo = null;
            created_at_time = ?Nat64.fromNat(Int.abs(Time.now()));
        })){
            case(#Err(err)){
                Debug.trap("Fail to mint all reward tokens : " # debug_show(err));
            };
            case(#Ok(_)){
                Debug.print("Minted all reward tokens");
            };
        };

        let account_1 = { owner; subaccount = ?Account.n32Subaccount(1); };

        // Create a new vote
        let vote_id = switch(await protocol.new_vote({
            statement = "ICP rocks!";
            from = account_1;
        })){
            case(#Err(err)) { Debug.trap("Fail to create new vote: " # debug_show(err)); };
            case(#Ok(vote_id)) { vote_id; };
        };

        // Scenario: Mint tokens to account_1, approve protocol to spend 10 tokens, vote with 5 tokens, and then wait untill the lock is over
        let original_balance = duration_to_sat(#SECONDS(12));
        let approved_balance = duration_to_sat(#SECONDS(10));
        let locked_balance = duration_to_sat(#SECONDS(5));
        let fee = await deposit_ledger.icrc1_fee();
       
        // Mint tokens to account_1
        switch(await deposit_ledger.mint({
            to = account_1;
            amount = original_balance;
            memo = null;
            created_at_time = ?Nat64.fromNat(Int.abs(Time.now()));
        })){
            case(#Err(err)){
                Debug.trap("Fail to mint 12 tokens to account_1: " # debug_show(err));
            };
            case(#Ok(_)){
                Debug.print("Minted 12 tokens to account_1");
            };
        };

        // Allow protocol to spend 10 tokens from account_1

        switch(await deposit_ledger.icrc2_approve({
            amount = approved_balance; // 10 tokens
            created_at_time = ?Nat64.fromNat(Int.abs(Time.now()));
            expected_allowance = null;
            expires_at = null;
            fee = ?fee;
            from_subaccount = ?Account.n32Subaccount(1);
            memo = null;
            spender = {
                owner = Principal.fromActor(protocol);
                subaccount = ?Account.pSubaccount(owner);
            };
        })){
            case(#Err(err)){
                Debug.trap("Fail to approve protocol to spend 10 tokens from account_1: " # debug_show(err));
            };
            case(#Ok(_)){
                Debug.print("Approved protocol to spend 10 tokens from account_1");
            };
        };

        // Lock 2 tokens from account_1
        let { tx_id; } = switch(await protocol.add_ballot({
            vote_id;
            from = account_1;
            choice = #YES(locked_balance);
        })){
            case(#Err(err)){
                Debug.trap("Fail to lock 5 tokens from account_1: " # debug_show(err));
            };
            case(#Ok(lock)){
                Debug.print("Locked 5 tokens from account_1");
                lock;
            };
        };

        // Get lock
        let ballot = switch(await protocol.find_ballot({vote_id; tx_id;})){
            case(null){
                Debug.trap("Fail to find lock " # debug_show(tx_id) # " in protocol");
            };
            case(?b){
                b;
            };
        };

        Debug.print("Time now: " # debug_show(Time.now()));

        var balance : Nat = 0;
        var reward : Nat = 0;

        // While locked, the balance of account_1 should be 10 minus the fees
        while ((await protocol.try_unlock()) == 0){

            balance := await deposit_ledger.icrc1_balance_of(account_1);
            Debug.print("Balance of account_1 (during lock): " # debug_show(balance));
            assert(balance + 2 * fee == duration_to_sat(#SECONDS(7)));

            reward := await reward_ledger.icrc1_balance_of(account_1);
            Debug.print("Reward of account_1 (during lock): " # debug_show(reward));
            assert(reward == 0);
        };

        // Once unlocked, the balance of account_1 should be 12 minus the fees
        // The reward shall be equal to 50% of the balance that was locked
        balance := await deposit_ledger.icrc1_balance_of(account_1);
        Debug.print("Balance of account_1 (after lock): " # debug_show(balance));
        assert(balance + 3 * fee == original_balance);

        reward := await reward_ledger.icrc1_balance_of(account_1);
        Debug.print("Reward of account_1 (after lock): " # debug_show(reward));
        assert(reward == Int.abs(Float.toInt(Float.fromInt(locked_balance) * 0.5)));

        assert((await protocol.get_failed_refunds(owner)).size() == 0);
        assert((await protocol.get_failed_rewards(owner)).size() == 0);
    };

    public shared func cycles_balance() : async Nat {
        return ExperimentalCycles.balance();
    };

};