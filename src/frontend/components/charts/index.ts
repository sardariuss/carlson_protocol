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
    endDate += sample;
    const startDate = endDate - duration;

    const dates = Array.from(
      { length: Math.ceil((Number(endDate - startDate) / Number(sample))) },
      (_, index) => ({
        date: Number((startDate + BigInt(index) * sample) / 1_000_000n),
        decay: 1
      })
    );

    return { dates, ticks: computeTicksMs(startDate, endDate, tick) };
}

export const computeTicksMs = (start: bigint, end: bigint, tick_duration: bigint): number[] => {
    console.log("between: ", new Date(Number(start / 1_000_000n)), new Date(Number(end / 1_000_000n)));
    let array = Array.from(
        { length: Math.ceil(Number(end - start) / Number(tick_duration)) }, 
        (_, i) => Number((end - BigInt(i) * tick_duration) / 1_000_000n)
    );
    console.log("Start: ", new Date(array[array.length - 1]));
    console.log("End: ", new Date(array[0]));
    return array;
}

export const isNotFiniteNorNaN = (value: number) => {
    return !Number.isFinite(value) && !Number.isNaN(value);
  }