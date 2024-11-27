import { SYesNoVote } from "@/declarations/backend/backend.did";
import { YesNoAggregate } from "@/declarations/protocol/protocol.did";
import { EYesNoChoice } from "./yesnochoice";

export const get_total_votes = (vote: SYesNoVote): bigint => {
  const aggregate = get_aggregate(vote);
  return to_bigint(aggregate.current_yes.DECAYED + aggregate.current_no.DECAYED);
}

export const get_yes_votes = (vote: SYesNoVote): bigint => {
  return to_bigint(get_aggregate(vote).current_yes.DECAYED);
}

export const get_no_votes = (vote: SYesNoVote): bigint => {
  return to_bigint(get_aggregate(vote).current_no.DECAYED);
}

export const get_votes = (vote: SYesNoVote, choice: EYesNoChoice): bigint => {
  return choice === EYesNoChoice.Yes ? get_yes_votes(vote) : get_no_votes(vote);
}

export const get_cursor = (vote: SYesNoVote): number => {
  const aggregate = get_aggregate(vote);
  return aggregate.current_yes.DECAYED / (aggregate.current_yes.DECAYED + aggregate.current_no.DECAYED);
}

const get_aggregate = (vote: SYesNoVote): YesNoAggregate => {
  return vote.aggregate.current.data;
}

const to_bigint = (value: number): bigint => {
  return BigInt(Math.floor(value));
}