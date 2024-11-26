
type TimeLine<T> = {
  current: TimedData<T>;
  history: TimedData<T>[];
}

type TimedData<T> = {
  timestamp: bigint;
  data: T;
};

export const get_current = <T>(timeline: TimeLine<T>): TimedData<T> => (
  timeline.current
)

export const get_first = <T>(timeline: TimeLine<T>): TimedData<T> => (
  timeline.history.length > 0 ? timeline.history[0] : timeline.current
)
