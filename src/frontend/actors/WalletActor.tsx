import { createActorContext }               from "@ic-reactor/react"
import { wallet, canisterId, idlFactory } from "../../declarations/wallet"

export type Wallet = typeof wallet

export const { ActorProvider: WalletActorProvider, ...walletActor } = createActorContext<Wallet>({
  canisterId,
  idlFactory,
})
