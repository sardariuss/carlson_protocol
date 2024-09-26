import { createActorContext }             from "@ic-reactor/react"
import { ledger, canisterId, idlFactory } from "../../declarations/ledger"

export type Ledger = typeof ledger

export const { ActorProvider: LedgerActorProvider, ...ledgerActor } = createActorContext<Ledger>({
  canisterId,
  idlFactory,
})
