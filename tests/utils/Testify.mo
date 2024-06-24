import HotMap      "../../src/protocol/locks/HotMap";

import Array       "mo:base/Array";
import Debug       "mo:base/Debug";
import Float       "mo:base/Float";
import Result      "mo:base/Result";
import Nat         "mo:base/Nat";
import Text        "mo:base/Text";
import Int         "mo:base/Int";
import Prim        "mo:⛔";

module {

    type HotElem = HotMap.HotElem;

    type Result<Ok, Err> = Result.Result<Ok, Err>;

    let FLOAT_EPSILON : Float = 1e-12;

    // Utility Functions, needs to be declared before used
    private func intToText(i : Int) : Text {
      if (i == 0) return "0";
      let negative = i < 0;
      var t = "";
      var n = if (negative) { -i } else { i };
      while (0 < n) {
        t := (switch (n % 10) {
          case 0 { "0" };
          case 1 { "1" };
          case 2 { "2" };
          case 3 { "3" };
          case 4 { "4" };
          case 5 { "5" };
          case 6 { "6" };
          case 7 { "7" };
          case 8 { "8" };
          case 9 { "9" };
          case _ { Prim.trap("unreachable") };
        }) # t;
        n /= 10;
      };
      if (negative) { "-" # t } else { t };
    };

    public type Testify<T> = {
        toText : (t : T) -> Text;
        compare    : (x : T, y : T) -> Bool;
    };

    public func testify<T>(
        toText : (t : T) -> Text,
        compare    : (x : T, y : T) -> Bool
    ) : Testify<T> = { toText; compare };

    public func optionalTestify<T>(
        testify : Testify<T>,
    ) : Testify<?T> = {
        toText = func (t : ?T) : Text = switch (t) {
            case (null) { "null" };
            case (? t)    { "?" # testify.toText(t) }
        };
        compare = func (x : ?T, y : ?T) : Bool = switch (x) {
            case (null) switch (y) {
                case (null) { true };
                case (_)    { false };
            };
            case (? x) switch(y) {
                case (null) { false };
                case (? y)    { testify.compare(x, y) };
            };
        };
    };

    public func verify<T>(actual: T, expected: T, testify: Testify<T>){
        if (not testify.compare(actual, expected)){
            Debug.print("Actual: " # testify.toText(actual));
            Debug.print("Expected: " # testify.toText(expected));
            assert(false);
        };
    };

    /// Submodule of primitive testify functions (excl. 'Any', 'None' and 'Null').
    /// https://github.com/dfinity/motoko/blob/master/src/protocol/prelude/prelude.mo
    public module Testify {

        public let bool = {
            equal : Testify<Bool> = {
                toText = func (t : Bool) : Text { if (t) { "true" } else { "false" } };
                compare = func (x : Bool, y : Bool) : Bool { x == y };
            };
        };

        public func result<Ok, Err>(ok_testify: Testify<Ok>, err_testify: Testify<Err>) : { equal: Testify<Result<Ok, Err>> } {
            {
                equal = {
                    toText = func (r : Result<Ok, Err>) : Text {
                        switch (r) {
                            case(#ok(ok))   { ok_testify.toText(ok);   };
                            case(#err(err)) { err_testify.toText(err); };
                        };
                    };
                    compare = func (x : Result<Ok, Err>, y : Result<Ok, Err>) : Bool {
                        switch (x, y) {
                            case(#ok(a), #ok(b))   { ok_testify.compare(a, b);  };
                            case(#err(a), #err(b)) { err_testify.compare(a, b); };
                            case(_, _)             { false;                     };
                        };
                    };
                };
            };
        };

        public func array<T>(testify: Testify<T>) : { equal: Testify<[T]> } {
            {
                equal = {
                    toText = func (a : [T]) : Text {
                        "[ " # Text.join(", ", Array.map(a, testify.toText).vals()) # " ]";
                    };
                    compare = func (x : [T], y : [T]) : Bool {
                        let (x_it, y_it) = (x.vals(), y.vals());
                        loop {
                            switch (x_it.next(), y_it.next()) {
                                case (null, null) { return true; };
                                case (?a, ?b) {
                                    if (not testify.compare(a, b)) { 
                                        return false; 
                                    };
                                };
                                case (_, _) { return false; };
                            };
                        };
                    };
                };
            };
        };

        public let nat = {
            equal : Testify<Nat> = {
                toText = intToText;
                compare = func (x : Nat, y : Nat) : Bool { x == y };
            };
        };

        public let nat8 = {
            equal : Testify<Nat8> = {
                toText = func (n : Nat8) : Text = intToText(Prim.nat8ToNat(n));
                compare = func (x : Nat8, y : Nat8) : Bool { x == y };
            };
        };

        public let nat16 = {
            equal : Testify<Nat16> = {
                toText = func (n : Nat16) : Text = intToText(Prim.nat16ToNat(n));
                compare = func (x : Nat16, y : Nat16) : Bool { x == y };
            };
        };

        public let nat32 = {
                equal : Testify<Nat32> = {
                toText = func (n : Nat32) : Text = intToText(Prim.nat32ToNat(n));
                compare = func (x : Nat32, y : Nat32) : Bool { x == y };
            };
        };

        public let nat64 = {
            equal : Testify<Nat64> = {
                toText = func (n : Nat64) : Text = intToText(Prim.nat64ToNat(n));
                compare = func (x : Nat64, y : Nat64) : Bool { x == y };
            };
        };

        public let int = {
            equal : Testify<Int> = {
                toText = intToText;
                compare = func (x : Int, y : Int) : Bool { x == y };
            };
        };

        public let int8 = {
            equal : Testify<Int8> = {
                toText = func (i : Int8) : Text = intToText(Prim.int8ToInt(i));
                compare = func (x : Int8, y : Int8) : Bool { x == y };
            };
        };

        public let int16 = {
            equal : Testify<Int16> = {
                toText = func (i : Int16) : Text = intToText(Prim.int16ToInt(i));
                compare = func (x : Int16, y : Int16) : Bool { x == y };
            };
        };

        public let int32 = {
            equal : Testify<Int32> = {
                toText = func (i : Int32) : Text = intToText(Prim.int32ToInt(i));
                compare = func (x : Int32, y : Int32) : Bool { x == y };
            };
        };

        public let int64 = {
            equal : Testify<Int64> = {
                toText = func (i : Int64) : Text =    intToText(Prim.int64ToInt(i));
                compare = func (x : Int64, y : Int64) : Bool { x == y };
            };
        };

        public let float = {
            equal : Testify<Float> = {
                toText = func (f : Float) : Text = Prim.floatToText(f);
                compare = func (x : Float, y : Float) : Bool { Float.equalWithin(x, y, FLOAT_EPSILON); };
            };
            equalEpsilon9 : Testify<Float> = {
                toText = func (f : Float) : Text = Prim.floatToText(f);
                compare = func (x : Float, y : Float) : Bool { Float.equalWithin(x, y, 1e-9); };
            };
            equalEpsilon6 : Testify<Float> = {
                toText = func (f : Float) : Text = Prim.floatToText(f);
                compare = func (x : Float, y : Float) : Bool { Float.equalWithin(x, y, 1e-6); };
            };
            equalEpsilon3 : Testify<Float> = {
                toText = func (f : Float) : Text = Prim.floatToText(f);
                compare = func (x : Float, y : Float) : Bool { Float.equalWithin(x, y, 1e-3); };
            };
            greaterThan : Testify<Float> = {
                toText = func (f : Float) : Text = Prim.floatToText(f);
                compare = func (x : Float, y : Float) : Bool { x > y };
            };
            greaterThanOrEqual : Testify<Float> = {
                toText = func (f : Float) : Text = Prim.floatToText(f);
                compare = func (x : Float, y : Float) : Bool { x >= y };
            };
            lessThan : Testify<Float> = {
                toText = func (f : Float) : Text = Prim.floatToText(f);
                compare = func (x : Float, y : Float) : Bool { x < y };
            };
            lessThanOrEqual : Testify<Float> = {
                toText = func (f : Float) : Text = Prim.floatToText(f);
                compare = func (x : Float, y : Float) : Bool { x <= y };
            };
        };

        public let char = {
            equal : Testify<Char> = {
                toText = func (c : Char) : Text = Prim.charToText(c);
                compare = func (x : Char, y : Char) : Bool { x == y };
            };
        };

        public let text = {
            equal : Testify<Text> = {
                toText = func (t : Text) : Text { t };
                compare = func (x : Text, y : Text) : Bool { x == y };
            };
        };

        public let blob = {
            equal : Testify<Blob> = {
                toText = func (b : Blob) : Text { encodeBlob(b) };
                compare = func (x : Blob, y : Blob) : Bool { x == y };
            };
        };

        public let error = {
            equal : Testify<Error> = {
                toText = func (e : Error) : Text { Prim.errorMessage(e) };
                compare = func (x : Error, y : Error) : Bool {
                    Prim.errorCode(x)    == Prim.errorCode(y) and 
                    Prim.errorMessage(x) == Prim.errorMessage(y);
                };
            };
        };

        public let hot_elem = {
            equal : Testify<HotElem> = {
                toText = func (e : HotElem) : Text { 
                    debug_show(e);
                 };
                compare = func (x : HotElem, y : HotElem) : Bool { 
                    x.amount    == y.amount                            and 
                    x.timestamp == y.timestamp                         and 
                    Float.equalWithin(x.decay, y.decay, 1e-12)         and 
                    Float.equalWithin(x.hotness, y.hotness, 1e-1);
                };
            };
        };

        private let hex : [Char] = [
            '0', '1', '2', '3', 
            '4', '5', '6', '7', 
            '8', '9', 'a', 'b', 
            'c', 'd', 'e', 'f',
        ];

        public let principal = {
            equal : Testify<Principal> = {
                toText = func (p : Principal) : Text { debug_show(p) };
                compare = func (x : Principal, y : Principal) : Bool { x == y };
            };
        };

        private func encodeByte(n : Nat8, acc : Text) : Text {
            let c0 = hex[Prim.nat8ToNat(n / 16)];
            let c1 = hex[Prim.nat8ToNat(n % 16)];
            Prim.charToText(c0) # Prim.charToText(c1) # acc;
        };

        private func encodeBlob(b : Blob) : Text {
            let bs = Prim.blobToArray(b);
            var t = "";
            var i = bs.size();
            while (0 < i) {
                i -= 1;
                t := encodeByte(bs[i], t);
            };
            t;
        };
    };
}