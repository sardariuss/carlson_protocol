dfx stop
dfx start --background --clean

dfx canister create --all

dfx build

export DEPLOYER_PRINCIPAL=$(dfx identity get-principal)
export CKBTC_PRINCIPAL=$(dfx canister id ckBTC)
export LEDGER_PRINCIPAL=$(dfx canister id ledger)

dfx canister install ckBTC --argument '( opt record {
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

dfx canister install ledger --argument '( opt record {
  icrc1 = opt record {
    name              = opt "Carlson";
    symbol            = opt "CRLS";
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

dfx canister install protocol --argument '( record {
    deposit_ledger = principal "'${CKBTC_PRINCIPAL}'";
    reward_ledger = principal "'${LEDGER_PRINCIPAL}'";
    parameters = record {
        ballot_half_life = variant { YEARS = 1 };
        nominal_lock_duration = variant { DAYS = 3 };
        new_vote_price = 100;
    };
})'