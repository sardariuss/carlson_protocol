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
    start_ns: bigint; // ns
    end_ns: bigint; // ns
    ticks_ms: number[]; // ms
}

export const computeInterval = (end: bigint, e_duration: DurationUnit): Interval => {
    const { duration, sample, tick } = CHART_CONFIGURATIONS.get(e_duration)!;
    // Calculate end and start dates
    var endDate = end;
    endDate -= endDate % sample;
    endDate += sample;
    const startDate = endDate - duration;

    return { start_ns: startDate, end_ns: endDate, ticks_ms: computeTicksMs(startDate, endDate, tick) };
}

export const computeTicksMs = (start: bigint, end: bigint, tick_duration: bigint): number[] => {
    return Array.from(
        { length: Number(end - start) / Number(tick_duration) }, 
        (_, i) => Number((end - BigInt(i) * tick_duration) / 1_000_000n)
    );
}