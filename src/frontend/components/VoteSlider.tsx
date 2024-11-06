import { SYesNoVote } from '@/declarations/backend/backend.did';

import { EYesNoChoice } from '../utils/conversions/yesnochoice';
import { useEffect, useRef, useState } from 'react';
import { formatBalanceE8s } from '../utils/conversions/token';
import { BITCOIN_TOKEN_SYMBOL } from '../constants';
import { BallotInfo } from './types';
import { get_cursor, get_no_votes, get_total_votes, get_yes_votes } from '../utils/conversions/vote';

const CURSOR_HEIGHT = "1rem";
const LIMIT_DISPLAY_RATIO = 0.2; // 20%
// Avoid 0 division, arbitrary use 0.001 and 0.999 values instead of 0 and 1
const MIN_CURSOR = 0.001;
const MAX_CURSOR = 0.999;
const clampCursor = (cursor: number) => {
  return Math.min(Math.max(cursor, MIN_CURSOR), MAX_CURSOR);
}

type Props = {
  id: bigint;
  disabled: boolean;
  vote: SYesNoVote
  ballot: BallotInfo;
  setBallot: (ballot: BallotInfo) => void;
  onMouseUp: () => (void);
  onMouseDown: () => (void);
};

const VoteSlider = ({id, disabled, vote, ballot, setBallot, onMouseUp, onMouseDown}: Props) => {


  const initCursor = clampCursor(get_cursor(vote));

  const [cursor, setCursor] = useState(initCursor);

  const updateBallot = (value: number) => {

    value = clampCursor(value);
    setCursor(value);

    const total = Number(get_total_votes(vote));
    const yes = Number(get_yes_votes(vote));

    const choice = value < initCursor ? EYesNoChoice.No : EYesNoChoice.Yes;
    const amount = BigInt(Math.floor(choice === EYesNoChoice.No ? (yes / value - total) : ((value * total - yes) / (1 - value))));

    setBallot({choice, amount});
  };

  const inputRef = useRef<HTMLInputElement>(null);
  const [isActive, setIsActive] = useState(false);

  const updateInputValue = (ballot: BallotInfo) => {
    if (inputRef.current && !isActive) { // Only update if input is not focused, i.e. the stimulus comes from an external component
      const amount = ballot.amount ?? 0n;
      var newCursor = Number(get_yes_votes(vote) + (ballot.choice === EYesNoChoice.Yes ? amount : 0n));
      newCursor = newCursor / Number(get_total_votes(vote) + amount);
      setCursor(newCursor);
      inputRef.current.value = newCursor.toString();
    }
  };

  useEffect(() => {
    updateInputValue(ballot);
  },
  [ballot]);

	return (
    <div id={"cursor_" + id} className="w-full flex flex-col items-center" style={{ position: 'relative' }}>
      <div className="flex w-full rounded-sm overflow-hidden z-0" style={{ height: CURSOR_HEIGHT, position: 'relative' }}>
        {
          cursor > MIN_CURSOR &&
            <div 
              className={`text-xs font-medium text-center p-0.5 leading-none text-white bg-green-500 border-green-200 border`}
              style={{ width: `${cursor * 100 + "%"}`}}
            >
              { 
                cursor > LIMIT_DISPLAY_RATIO && 
                  <span className={ballot.choice === EYesNoChoice.Yes && (ballot.amount ?? 0n) > 0n ? `animate-pulse` : ``}>
                    { formatBalanceE8s(get_yes_votes(vote) + (ballot.choice === EYesNoChoice.Yes ? (ballot.amount ?? 0n) : 0n), BITCOIN_TOKEN_SYMBOL) + " " + EYesNoChoice.Yes } 
                  </span>
              }
            </div>
        }
        {
          cursor < MAX_CURSOR &&    
            <div className={`text-xs font-medium text-center p-0.5 leading-none text-white bg-red-500 border-red-200 border`}
              style={{ width: `${( 1 - cursor) * 100 + "%"}`}}>
              { 
                (1 - cursor) > LIMIT_DISPLAY_RATIO && 
                  <span className={ballot.choice === EYesNoChoice.No && (ballot.amount ?? 0n) > 0n ? `animate-pulse` : ``}>
                    { formatBalanceE8s(get_no_votes(vote) + (ballot.choice === EYesNoChoice.No ? (ballot.amount ?? 0n) : 0n), BITCOIN_TOKEN_SYMBOL) + " " + EYesNoChoice.No }
                  </span>
              }
            </div>
        }
      </div>
      <input 
        id={"cursor_input_" + id}
        ref={inputRef}
        min="0"
        max="1"
        step="0.01"
        type="range"
        defaultValue={initCursor.toString()}
        onFocus={() => setIsActive(true)}
        onBlur={() => setIsActive(false)}
        onChange={(e) => updateBallot(Number(e.target.value))}
        onTouchEnd={(e) => onMouseUp()}
        onMouseUp={(e) => onMouseUp()}
        onTouchStart={(e) => onMouseDown()}
        onMouseDown={(e) => onMouseDown()}
        className={`w-full z-10 appearance-none focus:outline-none`} 
        style={{position: 'absolute', background: 'transparent', height: CURSOR_HEIGHT, cursor: 'pointer'}}
        disabled={disabled}
      />
    </div>
    
	);
};

export default VoteSlider;