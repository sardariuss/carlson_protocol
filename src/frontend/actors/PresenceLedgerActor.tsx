import { createActorContext }                      from "@ic-reactor/react"
import { presence_ledger, canisterId, idlFactory } from "../../declarations/presence_ledger"

export type PresenceLedger = typeof presence_ledger

export const { ActorProvider: PresenceLedgerActorProvider, ...presenceLedgerActor } = createActorContext<PresenceLedger>({
  canisterId,
  idlFactory,
})
