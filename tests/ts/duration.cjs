const toNs = (duration) => {

  const SECONDS_IN_NS = 1_000_000_000n;
  const MINUTES_IN_NS = 60n * SECONDS_IN_NS;
  const HOURS_IN_NS = 60n * MINUTES_IN_NS;
  const DAYS_IN_NS = 24n * HOURS_IN_NS;
  const YEARS_IN_NS = 365n * DAYS_IN_NS;

  if ('NS' in duration) {
    return duration['NS'];
  } else if ('SECONDS' in duration) {
    return BigInt(duration['SECONDS']) * SECONDS_IN_NS;
  } else if ('MINUTES' in duration) {
    return BigInt(duration['MINUTES']) * MINUTES_IN_NS;
  } else if ('HOURS' in duration) {
    return BigInt(duration['HOURS']) * HOURS_IN_NS;
  } else if ('DAYS' in duration) {
    return BigInt(duration['DAYS']) * DAYS_IN_NS;
  } else if ('YEARS' in duration) {
    return BigInt(duration['YEARS']) * YEARS_IN_NS;
  }
  throw new Error('Invalid duration');
}

// Export the function to be used in other files
module.exports = { toNs };