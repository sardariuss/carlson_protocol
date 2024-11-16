
type History<T> = {
  entries: HistoryEntry<T>[];
}

type HistoryEntry<T> = {
  timestamp: bigint;
  data: T;
};

export const get_first = <T>(history: History<T>): HistoryEntry<T> => {
  return history.entries[0];
}

export const get_last = <T>(history: History<T>): HistoryEntry<T> => {
  return history.entries[history.entries.length - 1];
}