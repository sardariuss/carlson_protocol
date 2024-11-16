import Result "mo:base/Result";
import Array "mo:base/Array";
import Debug "mo:base/Debug";

module {

  type Time = Int;
  type Result<Ok, Err> = Result.Result<Ok, Err>;

  type History<T> = {
    var entries: [HistoryEntry<T>];
  };

  public type HistoryEntry<T> = {
    timestamp: Time;
    data: T;
  };

  public func initialize<T>(timestamp: Time, data: T) : History<T> {
    { var entries = [{ timestamp; data; }] };
  };

  public func add<T>(history: History<T>, timestamp: Time, data: T) {
    if (has_non_ascending_date(history, timestamp)) {
      Debug.trap("Date must be greater than the last date");
    };
    history.entries := Array.append(history.entries, [{timestamp; data;}]);
  };

  // Returns the last entry in the history, if it exists
  public func get_last<T>(history: History<T>) : ?HistoryEntry<T> {
    let size = history.entries.size();
    if (size > 0) {
      ?history.entries[size - 1];
    } else {
      null;
    };
  };

  public func unwrap_last<T>(history: History<T>) : HistoryEntry<T> {
    let lastEntry = get_last(history);
    switch (lastEntry) {
      case (?entry) { entry };
      case (null) { Debug.trap("No entries in the timeline") };
    };
  };

  // Checks if a given date is greater than the last entry's date
  func has_non_ascending_date<T>(history: History<T>, date: Time) : Bool {
    let lastEntry = get_last(history);
    switch (lastEntry) {
      case (?entry) { date < entry.timestamp };
      case null { false };
    }
  }

};
