import { SBallotType, SLockInfo } from "@/declarations/protocol/protocol.did";
import { fromNullable } from "@dfinity/utils";

export const unwrapLock = (ballot: SBallotType) : SLockInfo => {
    const lock = fromNullable(ballot.YES_NO.lock);
    if (!lock) {
        throw new Error("Lock not found");
    }
    return lock;
}