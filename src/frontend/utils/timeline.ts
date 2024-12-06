
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

export const to_number_timeline = (timeline: TimeLine<bigint>): TimeLine<number> => ({
  current: { timestamp: timeline.current.timestamp, data: Number(timeline.current.data) },
  history: timeline.history.map((timed_data) => ({
    timestamp: timed_data.timestamp,
    data: Number(timed_data.data)
  }))
});