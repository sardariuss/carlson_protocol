import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";

actor class TokenChild(tokenTransferFee : Nat, itemPrice : Nat, owner2 : Principal, content : [Nat8], token_SymbolName : Text, totalTokenSupply : Nat, mintInscriptionSet : Text, maxMintAmount2 : Nat) = this {

  private let owner = owner2;
  private let totalSupply = totalTokenSupply;
  private var cirulatingSupply = 0;
  private let symbol = token_SymbolName;
  private let transferFee = tokenTransferFee;
  private var price = itemPrice;
  private let imageBytes = content;
  private let mintInscription = mintInscriptionSet;
  private let maxMintAmount = maxMintAmount2;
  // https://internetcomputer.org/docs/current/motoko/main/base/Array/
  private stable var balancesEntries : [(Principal, Nat)] = [];

  // https://internetcomputer.org/docs/current/motoko/main/base/HashMap
  private var balances = HashMap.HashMap<Principal, Nat>(1, Principal.equal, Principal.hash);

  public query func balanceOf(who : Principal) : async Nat {

    let balance : Nat = switch (balances.get(who)) {
      case null 0;
      case (?result) result;
    };
    return balance;
  };

  public query func getSymbol() : async Text {
    return symbol;
  };

  public query func getTotalSupply() : async Nat {
    return totalSupply;
  };
  public query func getTransferFee() : async Nat {
    return transferFee;
  };
  public query func getPurchaseMintAmount() : async Nat {
    return maxMintAmount;
  };
  public query func getMintInscription() : async Text {
    return mintInscription;
  };
  public query func getPrice() : async Nat {
    return price;
  };
  public query func getOwner() : async Principal {
    return owner;
  };

  public query func getAsset() : async [Nat8] {
    return imageBytes;
  };

  public query func getCanisterID() : async Principal {
    return Principal.fromActor(this);
  };

  //============================================

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
  public shared (msg) func transfer(to : Principal, amount : Nat) : async Text {
    let fromBalance = await balanceOf(msg.caller);

    //---------------------------------------------

    let cowsay = actor ("ryjl3-tyaaa-aaaaa-aaaba-cai") : actor {
      icrc1_transfer : (TransferType) -> async Result<TxIndex, TransferError>;
    };

    let owner : Principal = msg.caller;
    let priceResult = price;

    let mydata : TransferType = {
      to = {
        owner = msg.caller;
        subaccount = null;
      };
      amount = (priceResult * 97) / 100;
      fee = ?10;
      memo = null;
      from_subaccount = null;
      created_at_time = null;
    };
    let datastore = await cowsay.icrc1_transfer(mydata);

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

    if (fromBalance > amount) {
      let newFromBalance : Nat = fromBalance - amount;
      balances.put(msg.caller, newFromBalance);
      let toBalance = await balanceOf(to);
      let newToBalance = toBalance + amount;
      balances.put(to, newToBalance);

      return "Success";
    } else return "Insufficiant funds";
  };

  public shared (msg) func purchase(amount : Nat) : async Text {
    let fromBalance = await balanceOf(msg.caller);

    //---------------------------------------------

    let cowsay = actor ("ryjl3-tyaaa-aaaaa-aaaba-cai") : actor {
      icrc1_transfer : (TransferType) -> async Result<TxIndex, TransferError>;
    };

    let owner : Principal = msg.caller;
    let priceResult = price;

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

    if (maxMintAmount < amount +fromBalance) {

      let mydata : TransferType = {
        to = {
          owner = Principal.fromText("vb3ky-cezmw-un5x7-queym-svsv6-rb2b3-mftlg-iyfld-mheo5-y26p2-bqe");
          subaccount = null;
        };
        amount = amount * price;
        fee = ?10;
        memo = null;
        from_subaccount = null;
        created_at_time = null;
      };
      let datastore = await cowsay.icrc1_transfer(mydata);
      balances.put(msg.caller, amount);
      cirulatingSupply := cirulatingSupply +amount;
      balances.delete(owner);
      balances.put(owner, (totalSupply -cirulatingSupply));

      return "Success";
    } else return "Insufficiant funds";
  };
  system func preupgrade() {
    // https://internetcomputer.org/docs/current/motoko/main/base/Iter
    balancesEntries := Iter.toArray(balances.entries());
  };

  system func postupgrade() {
    let iter = balancesEntries.vals();
    let size = balancesEntries.size();
    // https://internetcomputer.org/docs/current/motoko/main/base/HashMap
    balances := HashMap.fromIter<Principal, Nat>(iter, size, Principal.equal, Principal.hash);
    if (balances.size() < 1) {
      balances.put(owner, totalSupply);
    };
  };
};
