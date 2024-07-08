// actor.ts
import { createReactor } from "@ic-reactor/react"
import { backend, canisterId, idlFactory } from "../../declarations/backend"

export type Backend = typeof backend

export const { useActorStore, useAuth, useQueryCall } = createReactor<Backend>({
  canisterId,
  idlFactory,
  host: "https://localhost:4943",
  withDevtools: true
})
