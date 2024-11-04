import { EYesNoChoice } from "../utils/conversions/yesnochoice";

export type BallotInfo = {
  choice: EYesNoChoice;
  amount: bigint;
};