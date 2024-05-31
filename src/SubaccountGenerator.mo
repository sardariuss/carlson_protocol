import Types    "Types";

import Nat8     "mo:base/Nat8";
import Nat64    "mo:base/Nat64";
import Blob     "mo:base/Blob";
import Buffer "mo:base/Buffer";

module {

    public let MODULE_VERSION : Nat8 = 0;

    type SubaccountType = Types.SubaccountType;

    public func getSubaccount(subaccount_type: SubaccountType) : Blob {
        let buffer = Buffer.Buffer<Nat8>(32);
        // Add the version (1 byte)
        buffer.add(MODULE_VERSION);
        // Add the type    (1 byte)
        switch(subaccount_type){
            case(#NEW_VOTES_ACCOUNT) {
                buffer.add(0);
            };
            case(#DEPOSIT_BALLOT_ACCOUNT{ id }) {
                buffer.add(1);
                buffer.append(Buffer.fromArray(nat64ToBytes(Nat64.fromNat(id)))); // @todo: Traps on overflow        
            };
        };
        // Add padding to make the buffer 32 bytes
        while (buffer.size() < 32) {
            buffer.add(0);
        };
        // Return the subaccount as a blob
        Blob.fromArray(Buffer.toArray(buffer));
    };

    func nat64ToBytes(x : Nat64) : [Nat8] {
        [ 
            Nat8.fromNat(Nat64.toNat((x >> 56) & (255))),
            Nat8.fromNat(Nat64.toNat((x >> 48) & (255))),
            Nat8.fromNat(Nat64.toNat((x >> 40) & (255))),
            Nat8.fromNat(Nat64.toNat((x >> 32) & (255))),
            Nat8.fromNat(Nat64.toNat((x >> 24) & (255))),
            Nat8.fromNat(Nat64.toNat((x >> 16) & (255))),
            Nat8.fromNat(Nat64.toNat((x >> 8) & (255))),
            Nat8.fromNat(Nat64.toNat((x & 255))) 
        ];
    };
 
}