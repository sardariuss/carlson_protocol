
export const dateToTime = (date: Date) : bigint => {
  return BigInt(date.getTime() * 1_000_000);
}

export const timeToDate = (time: bigint) : Date => {
  return new Date(Number(time / 1_000_000n));
}

export const formatDateTime = (date: Date) : string => {
  return date.toLocaleString();
}

export const formatDate = (date: Date) : string => {
  return date.toLocaleDateString();
}