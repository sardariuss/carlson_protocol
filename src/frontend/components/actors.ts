// actor.ts
import { createReactor }                   from "@ic-reactor/react"
import { backend, canisterId, idlFactory } from "../../declarations/backend"

export type Backend = typeof backend

export const backendActor = createReactor<Backend>({
  canisterId,
  idlFactory,
  host: "https://localhost:4943",
  withProcessEnv: true,
})
