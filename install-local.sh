set -ex

dfx canister create --all

export CKBTC_PRINCIPAL=$(dfx canister id ck_btc)
export LEDGER_PRINCIPAL=$(dfx canister id ledger)
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

dfx deploy ledger --argument '( opt record {
  icrc1 = opt record {
    name              = opt "Carlson";
    symbol            = opt "CRLS";
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

dfx deploy protocol --argument '( variant { 
  init = record {
    simulated = true;
    deposit = record {
      ledger = principal "'${CKBTC_PRINCIPAL}'";
      fee = 10;
    };
    reward =  record {
      ledger  = principal "'${LEDGER_PRINCIPAL}'";
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
dfx generate backend
dfx generate ledger
dfx deploy frontend