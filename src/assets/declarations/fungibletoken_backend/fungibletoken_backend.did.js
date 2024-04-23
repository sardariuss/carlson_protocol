export const idlFactory = ({ IDL }) => {
  const Listing = IDL.Record({
    'itemOwner' : IDL.Principal,
    'itemPrice' : IDL.Nat,
  });
  return IDL.Service({
    'check' : IDL.Func([], [IDL.Principal], []),
    'getListedPrice' : IDL.Func([IDL.Principal], [IDL.Nat], ['query']),
    'getListedTokens' : IDL.Func([], [IDL.Vec(Listing)], []),
    'getMainCanisterId' : IDL.Func([], [IDL.Principal], ['query']),
    'getOwnedTokens' : IDL.Func(
        [IDL.Principal],
        [IDL.Vec(IDL.Principal)],
        ['query'],
      ),
    'getTokens' : IDL.Func([], [IDL.Vec(IDL.Principal)], []),
    'mint' : IDL.Func(
        [IDL.Text, IDL.Nat, IDL.Nat, IDL.Text, IDL.Text, IDL.Nat, IDL.Text],
        [IDL.Principal],
        [],
      ),
    'purchase' : IDL.Func([IDL.Nat], [IDL.Text], []),
    'tokenPriceUpdate' : IDL.Func([IDL.Nat, IDL.Principal], [IDL.Text], []),
  });
};
export const init = ({ IDL }) => { return []; };
