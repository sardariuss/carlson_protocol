#!/bin/bash
set -ex

dfx canister create --all

# Fetch canister IDs dynamically
for canister in ck_btc presence_ledger resonance_ledger protocol minter; do
  export $(echo ${canister^^}_PRINCIPAL)=$(dfx canister id $canister)
done

# Parallel deployment for independent canisters
dfx deploy ck_btc --argument '(opt record {
  icrc1 = opt record {
    name              = opt "ckBTC";
    symbol            = opt "ckBTC";
    decimals          = 8;
    fee               = opt variant { Fixed = 10 };
    max_supply        = opt 2_100_000_000_000_000;
    min_burn_amount   = opt 1_000;
    initial_balances  = vec {};
    minting_account   = opt record { 
      owner = principal "'${MINTER_PRINCIPAL}'";
      subaccount = null; 
    };
    advanced_settings = null;
  };
  icrc2 = null;
  icrc3 = null;
  icrc4 = null;
})' &
dfx deploy presence_ledger --argument '(opt record {
  icrc1 = opt record {
    name              = opt "Carlson Presence Token";
    symbol            = opt "CPT";
    decimals          = 8;
    fee               = opt variant { Fixed = 10 };
    max_supply        = opt 2_100_000_000_000_000;
    min_burn_amount   = opt 1_000;
    initial_balances  = vec {};
    minting_account   = opt record { 
      owner = principal "'${PROTOCOL_PRINCIPAL}'";
      subaccount = null; 
    };
    advanced_settings = null;
  };
  icrc2 = null;
  icrc3 = null;
  icrc4 = null;
})' &
dfx deploy resonance_ledger --argument '(opt record {
  icrc1 = opt record {
    name              = opt "Carlson Resonance Token";
    symbol            = opt "CRT";
    decimals          = 8;
    fee               = opt variant { Fixed = 10 };
    max_supply        = opt 2_100_000_000_000_000;
    min_burn_amount   = opt 1_000;
    initial_balances  = vec {};
    minting_account   = opt record { 
      owner = principal "'${PROTOCOL_PRINCIPAL}'";
      subaccount = null; 
    };
    advanced_settings = null;
  };
  icrc2 = null;
  icrc3 = null;
  icrc4 = null;
})' &
wait

# Deploy protocol with dependencies
dfx deploy protocol --argument '( variant { 
  init = record {
    simulated = true;
    deposit = record {
      ledger = principal "'${CK_BTC_PRINCIPAL}'";
      fee = 10;
    };
    presence =  record {
      ledger  = principal "'${PRESENCE_LEDGER_PRINCIPAL}'";
      fee = 10;
      mint_per_day = 100_000_000_000;
    };
    resonance = record {
      ledger  = principal "'${RESONANCE_LEDGER_PRINCIPAL}'";
      fee = 10;
    };
    parameters = record {
        ballot_half_life = variant { YEARS = 1 };
        nominal_lock_duration = variant { DAYS = 3 };
    };
  }
})'

# Deploy other canisters
dfx deploy backend &
dfx deploy minter &
wait

# Internet Identity
dfx deps pull
dfx deps init
dfx deps deploy internet_identity

# Protocol initialization and frontend generation
dfx canister call protocol init_facade
dfx generate
dfx deploy frontend
