import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';

export interface Listing { 'itemOwner' : Principal, 'itemPrice' : bigint }
export interface _SERVICE {
  'check' : ActorMethod<[], Principal>,
  'getListedPrice' : ActorMethod<[Principal], bigint>,
  'getListedTokens' : ActorMethod<[], Array<Listing>>,
  'getMainCanisterId' : ActorMethod<[], Principal>,
  'getOwnedTokens' : ActorMethod<[Principal], Array<Principal>>,
  'getTokens' : ActorMethod<[], Array<Principal>>,
  'mint' : ActorMethod<
    [string, bigint, bigint, string, string, bigint, string],
    Principal
  >,
  'purchase' : ActorMethod<[bigint], string>,
  'tokenPriceUpdate' : ActorMethod<[bigint, Principal], string>,
}
