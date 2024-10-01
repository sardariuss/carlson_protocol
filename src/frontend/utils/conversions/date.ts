
// Format a time expressed in nanoseconds to a human-readable date string.
export const timeToDate = (time: bigint): string => {
  const date = new Date(Number(time / 1_000_000n));
  return date.toLocaleString();
}

export const currentTime = (): bigint => {
  return BigInt(Date.now() * 1_000_000);
}