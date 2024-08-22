import { createActorContext }             from "@ic-reactor/react"
import { ck_btc, canisterId, idlFactory } from "../../declarations/ck_btc"

export type CkBtc = typeof ck_btc

export const { ActorProvider: CkBtcActorProvider, ...ckBtcActor } = createActorContext<CkBtc>({
  canisterId,
  idlFactory,
})
