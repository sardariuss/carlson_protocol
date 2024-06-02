import Types     "Types";

import Nat8      "mo:base/Nat8";
import Nat32     "mo:base/Nat32";
import Nat64     "mo:base/Nat64";
import Blob      "mo:base/Blob";
import Buffer    "mo:base/Buffer";
import Principal "mo:base/Principal";
import Debug     "mo:base/Debug";

module {

    public let MODULE_VERSION : Nat8 = 0;

    type SubaccountType = Types.SubaccountType;

    public func from_subaccount_type(subaccount_type: SubaccountType) : Blob {
        let buffer = Buffer.Buffer<Nat8>(32);
        // Add the version (1 byte)
        buffer.add(MODULE_VERSION);
        // Add the type    (1 byte)
        switch(subaccount_type){
            case(#NEW_VOTE_FEES)      { buffer.add(0); };
            case(#BALLOT_DEPOSITS(_)) { buffer.add(1); };
        };
        // Add extra information if applicable
        switch(subaccount_type){
            case(#BALLOT_DEPOSITS{ id }) {
                buffer.append(Buffer.fromArray(nat64_to_bytes(Nat64.fromNat(id)))); // @todo: Traps on overflow
            };
            case(_) {};
        };
        finalize_subaccount(buffer);
    };

    public func from_principal(principal: Principal) : Blob {
        let blob_principal = Blob.toArray(Principal.toBlob(principal));
        // According to IC interface spec: "As far as most uses of the IC are concerned they are
        // opaque binary blobs with a length between 0 and 29 bytes"
        if (blob_principal.size() > 32) {
            Debug.trap("Cannot convert principal to subaccount: principal length is greater than 32 bytes");
        };
        let buffer = Buffer.Buffer<Nat8>(32);
        buffer.append(Buffer.fromArray(blob_principal));
        finalize_subaccount(buffer);
    };

    public func from_n32(x : Nat32) : Blob {
        let buffer = Buffer.Buffer<Nat8>(32);
        buffer.add(Nat8.fromNat(Nat32.toNat((x >> 24) & (255))));
        buffer.add(Nat8.fromNat(Nat32.toNat((x >> 16) & (255))));
        buffer.add(Nat8.fromNat(Nat32.toNat((x >> 8) & (255))));
        buffer.add(Nat8.fromNat(Nat32.toNat((x & 255))));
        finalize_subaccount(buffer);
    };

    func finalize_subaccount(buffer : Buffer.Buffer<Nat8>) : Blob {
        // Add padding until 32 bytes
        while(buffer.size() < 32) {
            buffer.add(0);
        };
        // Verify the buffer is 32 bytes
        assert(buffer.size() == 32);
        // Return the buffer as a blob
        Blob.fromArray(Buffer.toArray(buffer));
    };

    func nat64_to_bytes(x : Nat64) : [Nat8] {
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
 
};