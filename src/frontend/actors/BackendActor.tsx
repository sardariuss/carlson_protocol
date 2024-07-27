// actor.ts
import { createActorContext }              from "@ic-reactor/react"
import { backend, canisterId, idlFactory } from "../../declarations/backend"

export type Backend = typeof backend

export const { ActorProvider: BackendActorProvider, ...backendActor } = createActorContext<Backend>({
  canisterId,
  idlFactory,
})
