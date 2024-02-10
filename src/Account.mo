import Blob       "mo:base/Blob";
import Principal  "mo:base/Principal";
import Debug      "mo:base/Debug";
import Buffer     "mo:base/Buffer";

module {
  
  // Subaccount shall be a blob of 32 bytes
  public func toSubaccount(principal: Principal) : Blob {
    let blob_principal = Blob.toArray(Principal.toBlob(principal));
    // According to IC interface spec: "As far as most uses of the IC are concerned they are
    // opaque binary blobs with a length between 0 and 29 bytes"
    if (blob_principal.size() > 32) {
      Debug.trap("Cannot convert principal to subaccount: principal length is greater than 32 bytes");
    };
    let buffer = Buffer.Buffer<Nat8>(32);
    buffer.append(Buffer.fromArray(blob_principal));
    // Add padding until 32 bytes
    while(buffer.size() < 32) {
      buffer.add(0);
    };
    // Return the buffer as a blob
    Blob.fromArray(Buffer.toArray(buffer));
  };

};