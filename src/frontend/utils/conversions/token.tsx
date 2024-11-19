
export const toE8s = (amount: number) : bigint | undefined => {
    if (isNaN(amount) || amount < 0) {
        return undefined;
    }
    return BigInt(Math.round(amount * 100_000_000));
}

export const fromE8s = (amountE8s: bigint) => Number(amountE8s) / 100_000_000;

export const formatBalanceE8s = (amountE8s: bigint, token: string) => {
    const precision = 2n;
    const scaleFactor = 10n ** precision;

    const [balance, unit] =
        amountE8s < 100_000n ?             [amountE8s * scaleFactor / 100n,                 "μ"] :
        amountE8s < 100_000_000n ?         [amountE8s * scaleFactor / 100_000n,             "m"] :
        amountE8s < 100_000_000_000n ?     [amountE8s * scaleFactor / 100_000_000n,         "" ] :
        amountE8s < 100_000_000_000_000n ? [amountE8s * scaleFactor / 100_000_000_000n,     "k"] :
                                           [amountE8s * scaleFactor / 100_000_000_000_000n, "M"];

    return `${(Number(balance) / Number(scaleFactor)).toFixed(2)} ${unit}${token}`;
};

