import { SYesNoVote } from "@/declarations/backend/backend.did";
import { YesNoAggregate } from "@/declarations/protocol/protocol.did";
import { EYesNoChoice } from "./yesnochoice";

export const get_total_votes = (vote: SYesNoVote): bigint => {
  const aggregate = get_aggregate(vote);
  return aggregate.total_yes + aggregate.total_no;
}

export const get_yes_votes = (vote: SYesNoVote): bigint => {
  return get_aggregate(vote).total_yes;
}

export const get_no_votes = (vote: SYesNoVote): bigint => {
  return get_aggregate(vote).total_no;
}

export const get_votes = (vote: SYesNoVote, choice: EYesNoChoice): bigint => {
  return choice === EYesNoChoice.Yes ? get_yes_votes(vote) : get_no_votes(vote);
}

export const get_cursor = (vote: SYesNoVote): number => {
  const aggregate = get_aggregate(vote);
  return Number(aggregate.total_yes) / Number(aggregate.total_yes + aggregate.total_no);
}

const get_aggregate = (vote: SYesNoVote): YesNoAggregate => {
  return vote.aggregate.current.data;
}