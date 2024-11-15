set -ex

dfx canister create --all

export CKBTC_PRINCIPAL=$(dfx canister id ck_btc)
export PRESENCE_PRINCIPAL=$(dfx canister id presence_ledger)
export RESONANCE_PRINCIPAL=$(dfx canister id resonance_ledger)
export PROTOCOL_PRINCIPAL=$(dfx canister id protocol)
export MINTER_PRINCIPAL=$(dfx canister id minter)

dfx deploy ck_btc --argument '( opt record {
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
})'

# TODO: review supply etc.
dfx deploy presence_ledger --argument '( opt record {
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
})'

dfx deploy resonance_ledger --argument '( opt record {
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
})'

# TODO: check why ledgers are required as arguments
dfx deploy protocol --argument '( variant { 
  init = record {
    simulated = true;
    deposit = record {
      ledger = principal "'${CKBTC_PRINCIPAL}'";
      fee = 10;
    };
    presence =  record {
      ledger  = principal "'${PRESENCE_PRINCIPAL}'";
      fee = 10;
      mint_per_day = 100_000_000_000;
    };
    resonance = record {
      ledger  = principal "'${RESONANCE_PRINCIPAL}'";
      fee = 10;
    };
    parameters = record {
        ballot_half_life = variant { YEARS = 1 };
        nominal_lock_duration = variant { DAYS = 3 };
    };
  }
})'

dfx deploy backend

# Internet identity
dfx deps pull
dfx deps init
dfx deps deploy internet_identity

# Minter
dfx deploy minter

# Initialize the protocol
dfx canister call protocol init_facade

# Frontend
dfx generate presence_ledger
dfx generate resonance_ledger
dfx generate protocol
dfx generate backend
dfx deploy frontend