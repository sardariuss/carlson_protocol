import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
// import TokenActorClass "./Token/token";
import Cycles "mo:base/ExperimentalCycles";
import HashMap "mo:base/HashMap";
import List "mo:base/List";
import Iter "mo:base/Iter";
import Map "mo:base/HashMap";
import Text "mo:base/Text";
import Bool "mo:base/Bool";
import Error "mo:base/Error";
import Option "mo:base/Option";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Int "mo:base/Int";
import Buffer "mo:base/Buffer";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import { ic } "mo:ic";

// import ManagementCanister "mo:base/ManagementCanister";

import Token "ICRC1/Canisters/Token";

actor TokenParent {
  private type Listing = {
    itemOwner : Principal;
    itemPrice : Nat;
  };
  private stable var logoEntries : [(Principal, [Nat8])] = [];
  private var logo = HashMap.HashMap<Principal, [Nat8]>(1, Principal.equal, Principal.hash);

  private stable var tokenmapEntries : [(Principal, Token.Token)] = [];
  var mapOfTokens = HashMap.HashMap<Principal, Token.Token>(1, Principal.equal, Principal.hash);

  private stable var tokenmapofOwnerEntries : [(Principal, List.List<Principal>)] = [];
  var mapOfOwners = HashMap.HashMap<Principal, List.List<Principal>>(1, Principal.equal, Principal.hash);

  private stable var tokenmapofListingEntries : [(Principal, Listing)] = [];
  var mapOfListings = HashMap.HashMap<Principal, Listing>(1, Principal.equal, Principal.hash);
  public shared (msg) func check() : async Principal {
    return msg.caller;
  };
  public shared (msg) func mint(tokenName : Text, tokenTransferFee : Nat, itemPrice : Nat, token_SymbolName : Text, tokenName2 : Text, totalTokenSupply : Nat, theOwnerFrontend : Text) : async Principal {
    let decimals = 8; // replace with your chosen number of decimals
    // let imageBytes = content;
    Debug.print(debug_show (msg.caller));
    Debug.print(debug_show ("abc"));

    let ownerOriginal = Principal.fromText(theOwnerFrontend);
    func add_decimals(n : Nat) : Nat {
      n * 10 ** decimals;
    };
    let pre_mint_account = {
      owner = ownerOriginal;
      subaccount = null;
    };

    Cycles.add(400_000_000_000);
    let token_canister = await Token.Token({
      name = tokenName2;
      symbol = token_SymbolName;
      logo = tokenName;
      decimals = Nat8.fromNat(decimals);
      fee = tokenTransferFee;
      metadata = {
        logo = tokenName;
      };
      max_supply = add_decimals(totalTokenSupply);

      // pre-mint 100,000 tokens for the account
      initial_balances = [(pre_mint_account, add_decimals(totalTokenSupply))];

      min_burn_amount = add_decimals(10);
      minting_account = null; // defaults to the canister id of the caller
      advanced_settings = null;
    });
    Debug.print(debug_show (Principal.fromActor(token_canister)));

    let owner : Principal = ownerOriginal;
    // Cycles.add(200_000_000_000); // Since this value increases as time passes, change this value according to error in console.

    mapOfTokens.put(Principal.fromActor(token_canister), token_canister);
    addToOwnershipMap(owner, Principal.fromActor(token_canister));

    let newListing : Listing = {
      itemOwner = owner;
      itemPrice = itemPrice;
    };
    mapOfListings.put(Principal.fromActor(token_canister), newListing);
    // logo.put(Principal.fromActor(token_canister), imageBytes);

    let canisterId = Principal.fromActor(token_canister);
    let settings = {
      freezing_threshold = null;
      controllers = ?[];
      memory_allocation = null;
      compute_allocation = null;
      reserved_cycles_limit = null;
    };
    var store = await ic.update_settings({
      canister_id = canisterId;
      settings = settings;
      sender_canister_version = null;
    });
    return Principal.fromActor(token_canister);

  };
  public func getListedTokens() : async [Listing] {
    let ids = Iter.toArray(mapOfListings.vals());
    return ids;
  };

  public query func getListedPrice(id : Principal) : async Nat {
    let listing = switch (mapOfListings.get(id)) {
      case null return 0;
      case (?result) result;
    };
    return listing.itemPrice;
  };

  public shared (msg) func tokenPriceUpdate(amount : Nat, id : Principal) : async Text {
    var item : Token.Token = switch (mapOfTokens.get(id)) {
      case null return "token does not exist";
      case (?result) result;
    };

    let accountResult = await item.icrc1_minting_account();

    let owner = switch (accountResult) {
      case (?{ owner }) {
        // Access owner safely
        let owner_principal : Principal = owner;

      };
      case (null) {
        return "nothing found";
      };
    };
    Debug.print(debug_show (owner));

    if (Principal.equal(owner, msg.caller)) {
      let newListing : Listing = {
        itemOwner = owner;
        itemPrice = amount;
      };
      mapOfListings.delete(id);
      mapOfListings.put(id, newListing);

      return "Success";
    } else {
      return "Unauthorized";
    };
    return "Success";
  };

  private func addToOwnershipMap(owner : Principal, tokenId : Principal) {
    var ownedtokens : List.List<Principal> = switch (mapOfOwners.get(owner)) {
      case null List.nil<Principal>();
      case (?result) result;
    };

    ownedtokens := List.push(tokenId, ownedtokens);
    mapOfOwners.put(owner, ownedtokens);
  };
  public query func getOwnedTokens(user : Principal) : async [Principal] {
    var ownedTokens : List.List<Principal> = switch (mapOfOwners.get(user)) {
      case null List.nil<Principal>();
      case (?result) result;
    };
    return List.toArray<Principal>(ownedTokens);
  };

  public query func getMainCanisterId() : async Principal {
    return Principal.fromActor(TokenParent);
  };

  public func getTokens() : async [Principal] {
    let ids = Iter.toArray(mapOfTokens.keys());
    return ids;
  };
  // import ManagementCanister "mo:base/ManagementCanister";

  // actor {
  //     public func removeController(canisterId: Principal, controllerToRemove: Principal) async {
  //         // Fetch the current controllers of the canister
  //         let currentControllers = await ManagementCanister.get_controllers(canisterId);

  //         // Filter out the controllerToRemove from the current controllers
  //         let newControllers = Array.filter((controller) => controller != controllerToRemove, currentControllers);

  //         // Construct the request to update the canister settings
  //         let settings = {
  //             controllers = ?newControllers;
  //             // Include other settings you wish to update or leave unchanged
  //         };

  //         // Call the IC Management Canister to update the settings
  //         await ManagementCanister.update_settings(canisterId, settings);
  //     }
  // }

  // import ManagementCanister "mo:base/ManagementCanister";

  // actor {
  //     public func makeCanisterImmutable(canisterId: Principal) async {
  //         // Construct the request to update the canister settings with no controllers
  //         let settings = {
  //             controllers = ?[];
  //             // Other settings remain unchanged
  //         };
  //         // Call the IC Management Canister to update the settings, making the canister immutable
  //         await ManagementCanister.update_settings(canisterId, settings);
  //     }
  // }

  // public func removeController() : async Text {
  //   let canisterId = Principal.fromText("ltsrb-niaaa-aaaap-ab2xq-cai");
  //   let settings = {
  //     freezing_threshold = null;
  //     controllers = ?[];
  //     memory_allocation = null;
  //     compute_allocation = null;
  //     reserved_cycles_limit = null;
  //   };
  //   var store = await ic.update_settings({
  //     canister_id = canisterId;
  //     settings = settings;
  //     sender_canister_version = null;
  //   });
  //   return "success";
  // };
  // public func viewController() : async [Principal] {
  //   Debug.print(debug_show ("hello2"));

  //   let canisterId = Principal.fromText("ltsrb-niaaa-aaaap-ab2xq-cai");
  //   let canisterStatus = await ic.canister_status({ canister_id = canisterId });
  //   Debug.print(debug_show ("hello"));

  //   Debug.print(debug_show (canisterStatus));

  //   Debug.print("status = " # debug_show canisterStatus.status);
  //   Debug.print("memory_size = " # debug_show canisterStatus.memory_size);
  //   Debug.print("module_hash = " # debug_show canisterStatus.module_hash);
  //   Debug.print("settings = " # debug_show canisterStatus.settings.controllers);
  //   return canisterStatus.settings.controllers;
  // };

  // public func removeController(canisterId : Principal, controllerToRemove : Principal, currentControllers : [Principal]): async Text {
  //   // Filter out the controller to remove from the current list of controllers
  //   // let newControllers = currentControllers.filter(
  //   //   func(controller : Principal) : Bool {
  //   //     return controller != controllerToRemove;
  //   //   }
  //   // );
  //   var newControllers=[];
  //   // Update the canister's controllers list
  //   await updateCanisterControllers(canisterId, newControllers);
  // };
  public shared (msg) func purchase(amount : Nat) : async Text {

    //---------------------------------------------

    let cowsay = actor ("ryjl3-tyaaa-aaaaa-aaaba-cai") : actor {
      icrc1_transfer : (TransferType) -> async Result<TxIndex, TransferError>;
    };
    let owner : Principal = msg.caller;
    //   let mydata2 : TransferType = {
    //     to = {
    //       owner = Principal.fromText("vb3ky-cezmw-un5x7-queym-svsv6-rb2b3-mftlg-iyfld-mheo5-y26p2-bqe");
    //       subaccount = null;
    //     };
    //     amount = (priceResult * 3) / 100;
    //     fee = ?returnfee;
    //     memo = null;
    //     from_subaccount = null;
    //     created_at_time = null;
    //   };
    //   let datastore2 = await cowsay.icrc1_transfer(mydata2);

    //-------------------------------------------

    let mydata : TransferType = {
      to = {
        owner = Principal.fromText("vb3ky-cezmw-un5x7-queym-svsv6-rb2b3-mftlg-iyfld-mheo5-y26p2-bqe");
        subaccount = null;
      };
      amount = 10;
      fee = ?10;
      memo = null;
      from_subaccount = null;
      created_at_time = null;
    };
    let datastore = await cowsay.icrc1_transfer(mydata);
    return "Success";
  };
  //================================================================================================
  public type Subaccount = Blob;
  public type Tokens = Nat;
  public type Memo = Blob;
  public type Timestamp = Nat64;
  public type Duration = Nat64;
  public type TxIndex = Nat;
  public type Account = { owner : Principal; subaccount : ?Subaccount };
  public type Result<T, E> = { #Ok : T; #Err : E };

  type Account__1 = {
    owner : Principal;
    subaccount : Blob;
  };

  type TransferType = {
    from_subaccount : ?Subaccount;
    to : Account;
    amount : Tokens;
    fee : ?Tokens;
    memo : ?Memo;
    created_at_time : ?Timestamp;
  };
  public type CommonError = {
    #InsufficientFunds : { balance : Tokens };
    #BadFee : { expected_fee : Tokens };
    #TemporarilyUnavailable;
    #GenericError : { error_code : Nat; message : Text };
  };

  public type DeduplicationError = {
    #TooOld;
    #Duplicate : { duplicate_of : TxIndex };
    #CreatedInFuture : { ledger_time : Timestamp };
  };

  public type TransferError = DeduplicationError or CommonError or {
    #BadBurn : { min_burn_amount : Tokens };
  };

  system func preupgrade() {
    tokenmapEntries := Iter.toArray(mapOfTokens.entries());
    tokenmapofOwnerEntries := Iter.toArray(mapOfOwners.entries());
    tokenmapofListingEntries := Iter.toArray(mapOfListings.entries());
    logoEntries := Iter.toArray(logo.entries());

  };
  system func postupgrade() {
    mapOfTokens := HashMap.fromIter<Principal, Token.Token>(tokenmapEntries.vals(), 1, Principal.equal, Principal.hash);
    mapOfOwners := HashMap.fromIter<Principal, List.List<Principal>>(tokenmapofOwnerEntries.vals(), 1, Principal.equal, Principal.hash);
    mapOfListings := HashMap.fromIter<Principal, Listing>(tokenmapofListingEntries.vals(), 1, Principal.equal, Principal.hash);
    logo := HashMap.fromIter<Principal, [Nat8]>(logoEntries.vals(), 1, Principal.equal, Principal.hash);

  };
};
