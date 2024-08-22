import { createActorContext }               from "@ic-reactor/react"
import { protocol, canisterId, idlFactory } from "../../declarations/protocol"

export type Protocol = typeof protocol

export const { ActorProvider: ProtocolActorProvider, ...protocolActor } = createActorContext<Protocol>({
  canisterId,
  idlFactory,
})
