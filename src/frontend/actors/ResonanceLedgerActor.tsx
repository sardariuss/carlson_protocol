import { createActorContext }                       from "@ic-reactor/react"
import { resonance_ledger, canisterId, idlFactory } from "../../declarations/resonance_ledger"

export type ResonanceLedger = typeof resonance_ledger

export const { ActorProvider: ResonanceLedgerActorProvider, ...resonanceLedgerActor } = createActorContext<ResonanceLedger>({
  canisterId,
  idlFactory,
})
