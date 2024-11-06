import { SYesNoVote } from "@/declarations/backend/backend.did";
import { YesNoAggregate } from "@/declarations/protocol/protocol.did";
import { EYesNoChoice } from "./yesnochoice";

export const last_aggregate = (vote: SYesNoVote): YesNoAggregate => {
  return vote.aggregate_history[vote.aggregate_history.length - 1].aggregate;
}

export const get_total_votes = (vote: SYesNoVote): bigint => {
  const aggregate = last_aggregate(vote);
  return aggregate.total_yes + aggregate.total_no;
}

export const get_yes_votes = (vote: SYesNoVote): bigint => {
  return last_aggregate(vote).total_yes;
}

export const get_no_votes = (vote: SYesNoVote): bigint => {
  return last_aggregate(vote).total_no;
}

export const get_votes = (vote: SYesNoVote, choice: EYesNoChoice): bigint => {
  return choice === EYesNoChoice.Yes ? get_yes_votes(vote) : get_no_votes(vote);
}

export const get_cursor = (vote: SYesNoVote): number => {
  const aggregate = last_aggregate(vote);
  return Number(aggregate.total_yes) / Number(aggregate.total_yes + aggregate.total_no);
}