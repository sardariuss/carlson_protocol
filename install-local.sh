dfx stop
dfx start --background --clean

dfx canister create --all

export DEPLOYER_PRINCIPAL=$(dfx identity get-principal)
export CKBTC_PRINCIPAL=$(dfx canister id ckBTC)
export LEDGER_PRINCIPAL=$(dfx canister id ledger)
export PROTOCOL_PRINCIPAL=$(dfx canister id protocol)

dfx deploy ckBTC --argument '( opt record {
  icrc1 = opt record {
    name              = opt "ckBTC";
    symbol            = opt "ckBTC";
    decimals          = 8;
    fee               = opt variant { Fixed = 10 };
    max_supply        = opt 2_100_000_000_000_000;
    min_burn_amount   = opt 1_000;
    initial_balances  = vec {};
    minting_account   = opt record { 
      owner = principal "'${DEPLOYER_PRINCIPAL}'";
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

dfx deploy protocol --argument '( record {
    deposit_ledger = principal "'${CKBTC_PRINCIPAL}'";
    reward_ledger = principal "'${LEDGER_PRINCIPAL}'";
    parameters = record {
        ballot_half_life = variant { YEARS = 1 };
        nominal_lock_duration = variant { DAYS = 3 };
    };
})'

dfx deploy backend

dfx deploy frontend

# Internet identity
dfx deps pull
dfx deps init
dfx deps deploy internet_identity

dfx generate

dfx canister call protocol init_facade
