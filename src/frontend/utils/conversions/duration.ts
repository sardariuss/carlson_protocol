
export enum DurationUnit {
  NS = '1ns',
  SECOND = '1s',
  MINUTE = '1m',
  HOUR = '1h',
  DAY = '1D',
  WEEK = '7D',
  MONTH = '1M',
  YEAR = '1Y',
}


export const toNs = (duration: number, unit: DurationUnit): bigint => {
  switch (unit) {
    case DurationUnit.NS:     return BigInt(duration);
    case DurationUnit.SECOND: return BigInt(duration) * 1_000_000_000n;
    case DurationUnit.MINUTE: return BigInt(duration) * 60n * 1_000_000_000n;
    case DurationUnit.HOUR:   return BigInt(duration) * 60n * 60n * 1_000_000_000n;
    case DurationUnit.DAY:    return BigInt(duration) * 24n * 60n * 60n * 1_000_000_000n;
    case DurationUnit.WEEK:   return BigInt(duration) * 7n * 24n * 60n * 60n * 1_000_000_000n;
    case DurationUnit.MONTH:  return BigInt(duration) * 30n * 24n * 60n * 60n * 1_000_000_000n;
    case DurationUnit.YEAR:   return BigInt(duration) * 365n * 24n * 60n * 60n * 1_000_000_000n;
  }
}

export const formatDuration = (ns: bigint): string => {
  const SECONDS_IN_NS = 1_000_000_000n;
  const MINUTES_IN_NS = 60n * SECONDS_IN_NS;
  const HOURS_IN_NS = 60n * MINUTES_IN_NS;
  const DAYS_IN_NS = 24n * HOURS_IN_NS;
  const WEEKS_IN_NS = 7n * DAYS_IN_NS;
  const MONTHS_IN_NS = BigInt(Math.round(30.44 * Number(DAYS_IN_NS))); // Approximate average month
  const YEARS_IN_NS = 365n * DAYS_IN_NS;

  if (ns < MINUTES_IN_NS) {
    // Less than a minute, show in seconds
    const seconds = Number(ns) / 1_000_000_000; // Convert to floating-point
    return `${seconds.toFixed(1)} seconds`;
  } else if (ns < HOURS_IN_NS) {
    // Less than an hour, show in minutes
    const minutes = Number(ns) / Number(MINUTES_IN_NS);
    return `${minutes.toFixed(1)} minutes`;
  } else if (ns < DAYS_IN_NS) {
    // Less than a day, show in hours
    const hours = Number(ns) / Number(HOURS_IN_NS);
    return `${hours.toFixed(1)} hours`;
  } else if (ns < WEEKS_IN_NS) {
    // Less than a week, show in days
    const days = Number(ns) / Number(DAYS_IN_NS);
    return `${Math.round(days)} days`;
  } else if (ns < MONTHS_IN_NS) {
    // Less than a month, show in weeks
    const weeks = Number(ns) / Number(WEEKS_IN_NS);
    return `${weeks.toFixed(1)} weeks`;
  } else if (ns < YEARS_IN_NS) {
    // Less than a year, show in months
    const months = Number(ns) / Number(MONTHS_IN_NS);
    return `${months.toFixed(1)} months`;
  } else {
    // More than a year, show in years
    const years = Number(ns) / Number(YEARS_IN_NS);
    return `${years.toFixed(1)} years`;
  }
}