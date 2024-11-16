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

  public class Timeline<T>(history: History<T>) {

    // Adds an entry to the history, ensuring it has a unique, ascending date
    public func add_entry(entry: HistoryEntry<T>) : Result<[HistoryEntry<T>], Text> {
      if (has_non_ascending_date(entry.timestamp)) {
        return #err("Date must be greater than the last date");
      };
      history.entries := Array.append(history.entries, [entry]);
      #ok(history.entries);
    };

    // Returns all entries in the history as an immutable array
    public func get_all_entries() : [HistoryEntry<T>] {
      history.entries;
    };

    // Returns the last entry in the history, if it exists
    public func get_last_entry() : ?HistoryEntry<T> {
      let size = history.entries.size();
      if (size > 0) {
        ?history.entries[size - 1];
      } else {
        null;
      };
    };

    public func unwrap_last_entry() : HistoryEntry<T> {
      let lastEntry = get_last_entry();
      switch (lastEntry) {
        case (?entry) { entry };
        case (null) { Debug.trap("No entries in the timeline") };
      };
    };

    // Checks if a given date is greater than the last entry's date
    private func has_non_ascending_date(date: Time) : Bool {
      let lastEntry = get_last_entry();
      switch (lastEntry) {
        case (?entry) { date < entry.timestamp };
        case null { false };
      }
    }
  };

};
