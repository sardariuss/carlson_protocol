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
  type Timeline<T> = Types.Timeline<T>;
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
  };

  public class PresenceDispenser({
    parameters: PresenseParameters;
  }) {

    public func get_presence_parameters() : PresenseParameters {
      parameters;
    };

    public func dispense({
      locks: [ExtendedLock];
      time_dispense: Time;
      total_locked: Timeline<Nat>;
    }){

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

      // If there is an unlock, there has to be at least one entry in the timeline.
      var total_amount = Timeline.get_current(total_locked);

      // Dispense the locks
      for ({ key; time; } in released.vals()) {

        let { amount } = switch(Map.get(map_locks, Map.nhash, key)){
          case(?l) { l };
          case(null) { Debug.trap("Lock not found"); };
        };

        // Dispense the locks up to the time of release which is the time of release of the lock here
        dispense_locks(total_amount, map_locks, time);

        // Subtract the amount from the total locked;
        total_amount -= amount;

        // Update the timeline accordingly
        Timeline.add(total_locked, time, total_amount);

        // Remove the lock from the map
        Map.delete(map_locks, Map.nhash, key);
      };

      dispense_locks(total_amount, map_locks, time_dispense);
    };

    public func dispense_locks(total_amount: Nat, map_locks: Map.Map<Nat, Lock>, time: Time) {

      for ({ amount; add_presence; } in Map.vals(map_locks)) {
        add_presence(Float.fromInt(amount) / Float.fromInt(total_amount) * parameters.presence_per_ns * Float.fromInt(time - parameters.time_last_dispense));
      };

      parameters.time_last_dispense := time;
    };

  };

};