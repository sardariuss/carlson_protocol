import { format }                            from "date-fns";
import { DurationUnit, toNs }                from "../../utils/conversions/duration";

export type DurationParameters = {
    duration: bigint; 
    sample: bigint; 
    tick: bigint; 
    format: (date: Date) => string;
}

export const CHART_CONFIGURATIONS = new Map<DurationUnit, DurationParameters>([
    [DurationUnit.DAY,   { duration: toNs(1, DurationUnit.DAY),   sample: toNs(1, DurationUnit.HOUR), tick: toNs(2, DurationUnit.HOUR),  format: (date: Date) => format(date,                                     "HH:mm")} ],
    [DurationUnit.WEEK,  { duration: toNs(1, DurationUnit.WEEK),  sample: toNs(6, DurationUnit.HOUR), tick: toNs(12, DurationUnit.HOUR), format: (date: Date) => format(date, date.getHours() === 0 ? "dd MMM" : "HH:mm" )} ],
    [DurationUnit.MONTH, { duration: toNs(1, DurationUnit.MONTH), sample: toNs(1, DurationUnit.DAY),  tick: toNs(2, DurationUnit.DAY),   format: (date: Date) => format(date,                                    "dd MMM")} ],
    [DurationUnit.YEAR,  { duration: toNs(1, DurationUnit.YEAR),  sample: toNs(15, DurationUnit.DAY), tick: toNs(1, DurationUnit.MONTH), format: (date: Date) => format(date,                                   "MMM yy")} ],
]);

export type Interval = {
    dates: { date :number; decay: number }[];
    ticks: number[];
}

export const computeInterval = (end: bigint, e_duration: DurationUnit): Interval => {
    
    const { duration, sample, tick } = CHART_CONFIGURATIONS.get(e_duration)!;
    
    // Calculate end and start dates
    let endDate = end;
    endDate -= endDate % sample;
    const numSamples = Math.ceil(Number(duration) / Number(sample));
    const startDate = endDate - sample * BigInt(numSamples);

    const dates = [...Array.from(
      { length: numSamples},
      (_, index) => ({
        date: Number((startDate + BigInt(index) * sample) / 1_000_000n),
        decay: 1
      })
    ), { date: Number(end / 1_000_000n), decay: 1 }];

    return { dates, ticks: computeTicksMs(duration, startDate, tick) };
}

export const computeTicksMs = (duration: bigint, start: bigint, tick_duration: bigint): number[] => {
    const numTicks = Math.ceil(Number(duration) / Number(tick_duration));
    return Array.from(
        { length: numTicks },
        (_, i) => Number((start + BigInt(i) * tick_duration) / 1_000_000n)
    );
}

export const isNotFiniteNorNaN = (value: number) => {
    return !Number.isFinite(value) && !Number.isNaN(value);
  }