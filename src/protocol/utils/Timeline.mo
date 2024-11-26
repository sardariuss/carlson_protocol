import Result "mo:base/Result";
import Array "mo:base/Array";
import Debug "mo:base/Debug";

module {

  type Time = Int;
  type Result<Ok, Err> = Result.Result<Ok, Err>;

  type Timeline<T> = {
    var current: TimedData<T>;
    var history: [TimedData<T>];
  };

  public type TimedData<T> = {
    timestamp: Time;
    data: T;
  };

  // Initialize the history with the first entry
  public func initialize<T>(timestamp: Time, data: T): Timeline<T> {
    {
      var current = { timestamp; data };
      var history = [];
    }
  };

  // Add a new entry to the history
  public func add<T>(timeline: Timeline<T>, timestamp: Time, data: T) {
    if (timestamp < timeline.current.timestamp) {
      Debug.trap("Date must be greater than the last date");
    };
    timeline.history := Array.append(timeline.history, [timeline.current]);
    timeline.current := { timestamp; data };
  };

  // Retrieve the latest entry
  public func get_current<T>(timeline: Timeline<T>): T {
    timeline.current.data;
  };

  // Retrieve the entire historical log
  public func get_history<T>(timeline: Timeline<T>): [TimedData<T>] {
    timeline.history;
  };

};
