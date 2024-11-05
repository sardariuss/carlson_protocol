import { YesNoChoice } from "@/declarations/protocol/protocol.did";

export enum EYesNoChoice {
  Yes = 'True',
  No = 'False'
}

export const toEnum = (candid: YesNoChoice) : EYesNoChoice => {
  if ('YES' in candid) {
    return EYesNoChoice.Yes;
  } else {
    return EYesNoChoice.No;
  }
}

export const toCandid = (enumValue: EYesNoChoice) : YesNoChoice => {
  if (enumValue === EYesNoChoice.Yes) {
    return {'YES': null };
  } else {
    return {'NO': null };
  }
}