import Principal "mo:base/Principal";
import Debug "mo:base/Debug";

actor class NFT(name : Text, itemPrice : Nat, owner : Principal, content : [Nat8], token_Type : Text) = this {
  private let itemName = name;
  private var price = itemPrice;
  private var nftOwner = owner;
  private let imageBytes = content;
  private var refunded = false;
  private let tokenType = token_Type;

  public query func getName() : async Text {
    return itemName;
  };
  public query func getTokenType() : async Text {
    return tokenType;
  };
  public query func getPrice() : async Nat {
    return price;
  };
  public query func getOwner() : async Principal {
    return nftOwner;
  };

  public query func getAsset() : async [Nat8] {
    return imageBytes;
  };

  public query func getCanisterID() : async Principal {
    return Principal.fromActor(this);
  };

  public shared (msg) func transferOwnership(newOwner : Principal) : async Text {

    if (msg.caller == Principal.fromText("4f422-eaaaa-aaaap-abvfa-cai")) {
      nftOwner := newOwner;
      return "Success";
    } else {
      return "Unauthorized";
    };
  };

  public shared (msg) func transferOwnershipRights(thecaller : Principal,newOwner : Principal) : async Text {
    if (thecaller == nftOwner) {
      nftOwner := newOwner;
      return "Success";
    } else {
      return "Unauthorized";
    };
  };
  public func getRefund(thecaller : Principal) : async Text {
    if (thecaller == nftOwner and refunded == false) {
      refunded := true;
      price := 0;
      return "Success";
    } else {
      if (thecaller != nftOwner) {
        return Principal.toText(thecaller);

      } else {
        return "already refunded";
      };
    };
  };
};
