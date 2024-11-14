import Types "Types";
import Timeline "utils/Timeline";

import Map "mo:map/Map";
import Buffer "mo:base/Buffer";
import Order "mo:base/Order";
import Debug "mo:base/Debug";
import Float "mo:base/Float";
import Result "mo:base/Result";

module {

  type Time = Int;
  type History<T> = Types.History<T>;
  type Order = Order.Order;
  type Result<Ok, Err> = Result.Result<Ok, Err>;

  type Lock = {
    amount: Nat;
    add_presence: (Float) -> ();
  };

  public type ExtendedLock = Lock and {
    release_time: ?Time;
  };

  type Released = { 
    key: Nat;
    time: Time; 
  };

  type PresenseParameters = {
    presence_per_ns: Float;
    var time_last_dispense: Time;
    amount_history: History<Nat>;
  };

  public class PresenceDispenser({
    parameters: PresenseParameters;
  }) {

    let locked_timeline = Timeline.Timeline(parameters.amount_history);

    public func get_presence_parameters() : PresenseParameters {
      parameters;
    };

    public func dispense({
      locks: [ExtendedLock];
      time_dispense: Time;
    }) : Result<(), Text> {

      // Map locks contains all the locks with their index as key
      let map_locks = Map.new<Nat, Lock>();
      // Released locks contains the index of the locks that have been released with the time of release
      let released = Buffer.Buffer<Released>(0);
      
      // Fill map_locks and released
      var index : Nat = 0;
      while(index < locks.size()) {
        let lock = locks[index];
        Map.set(map_locks, Map.nhash, index, lock);
        switch(lock.release_time) {
          case(?time) {
            released.add({ key = index; time; });
          };
          case(null) {};
        };
        index := index + 1;
      };

      // Make sure the released ones are ordered by time of release
      released.sort(func(a: Released, b: Released) : Order.Order   {
        if (a.time < b.time) { #less }
        else if (a.time > b.time) { #greater }
        else { #equal }
      });

      // Dispense the locks
      for ({ key; time; } in released.vals()) {

        let { amount } = switch(Map.get(map_locks, Map.nhash, key)){
          case(?l) { l };
          case(null) { Debug.trap("Lock not found"); };
        };

        // Dispense the locks up to the time of release which is the time of release of the lock here
        dispense_locks(map_locks, time);

        // Subtract the amount from the total locked and update the timeline accordingly
        let new_amount : Nat = locked_timeline.unwrap_last_entry().data - amount;
        switch(locked_timeline.add_entry({ timestamp = time; data = new_amount; })) {
          case(#err(err)) { return #err(err); };
          case(#ok(_)) {};
        };

        // Remove the lock from the map
        Map.delete(map_locks, Map.nhash, key);
      };

      dispense_locks(map_locks, time_dispense);

      #ok;
    };

    public func dispense_locks(map_locks: Map.Map<Nat, Lock>, time: Time) {

      let total_locked = locked_timeline.unwrap_last_entry().data;

      for ({ amount; add_presence; } in Map.vals(map_locks)) {
        add_presence(Float.fromInt(amount) / Float.fromInt(total_locked) * parameters.presence_per_ns * Float.fromInt(time - parameters.time_last_dispense));
      };

      parameters.time_last_dispense := time;
    };

  };

};