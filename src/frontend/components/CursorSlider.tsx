import { SYesNoVote } from '@/declarations/backend/backend.did';

import React, { useState, useEffect, useRef } from "react";
import { EYesNoChoice } from '../utils/conversions/yesnochoice';

type BallotInfo = {
  choice: EYesNoChoice;
  amount: bigint | undefined;
};

// Cursor between 0 and 1
const toCursorInfo = (grunt: SYesNoVote, ballot: BallotInfo) => {
  const nominator = grunt.aggregate.total_yes + (ballot.choice === EYesNoChoice.Yes ? (ballot.amount ?? 0n) : 0n); 
  const denominator = grunt.aggregate.total_yes + grunt.aggregate.total_no + (ballot.amount ?? 0n);
  return Number(nominator) / Number(denominator);
}

const toBallotInfo = (grunt: SYesNoVote, cursor: number) => {
  const total = grunt.aggregate.total_yes + grunt.aggregate.total_no;
  const init_cursor = toCursorInfo(grunt, { choice: EYesNoChoice.Yes, amount: 0n });
  const cursor_diff = cursor - init_cursor;
  const choice = cursor_diff > 0 ? EYesNoChoice.Yes : EYesNoChoice.No;
  const amount = BigInt(Math.floor(Number(total) * Math.abs(cursor_diff) / Math.abs(1 - Math.abs(cursor_diff))));
  return { choice, amount };
}

type Props = {
  id: bigint;
  disabled: boolean;
  grunt: SYesNoVote
  ballot: BallotInfo;
  setBallot: (ballot: BallotInfo) => void;
  onMouseUp: () => (void);
  onMouseDown: () => (void);
};


export const CursorSlider = ({id, disabled, grunt, ballot, setBallot, onMouseUp, onMouseDown}: Props) => {

  const minimum_slider_width = 200;
  const maximum_slider_width = 500;

  const [thumbSize] = useState(50);
  const [marginWidth] = useState(100);
  const [marginRatio, setMarginRatio] = useState(marginWidth / 200);
  const [sliderWidth, setSliderWidth] = useState(200);

  const demoRef = useRef<any>();

  useEffect(() => {
    const resizeObserver = new ResizeObserver((event) => {
      // Depending on the layout, you may need to swap inlineSize with blockSize
      // https://developer.mozilla.org/en-US/docs/Web/API/ResizeObserverEntry/contentBoxSize
      let width = Math.min(maximum_slider_width, Math.max(minimum_slider_width, event[0].contentBoxSize[0].inlineSize));
      setSliderWidth(width);
      setMarginRatio(marginWidth / width);
    });

    if (demoRef) {
      resizeObserver.observe(demoRef.current);
    }

    return () => {
      resizeObserver.disconnect();
    }
  }, [demoRef]);

  const refreshValue = (value: number) => {
    setBallot(toBallotInfo(grunt, value));
  };

//  useEffect(() => {
//    // From -1 to 1, should compute the value
//    refreshValue(cursor)
//  }, [cursor]);

	return (
    <div id={"cursor_" + id} className="w-full flex flex-col items-center" ref={demoRef}>
      <div className="text-xs mb-2">
        { "TODO" }
      </div>
      <input 
        id={"cursor_input_" + id}
        min="0"
        max="1"
        step="0.01"
        value={toCursorInfo(grunt, ballot)}
        type="range"
        onChange={(e) => refreshValue(Number(e.target.value))}
        onTouchEnd={(e) => onMouseUp()}
        onMouseUp={(e) => onMouseUp()}
        onTouchStart={(e) => onMouseDown()}
        onMouseDown={(e) => onMouseDown()}
        className={`input appearance-none`} 
        style={{
          "--progress-percent": `${ ((marginRatio + toCursorInfo(grunt, ballot) * (1 - 2 * marginRatio)) * 100).toString() + "%"}`,
          "--slider-left-color": `rgba(255, 0, 0, 0.5)`,
          "--slider-right-color": `rgba(0, 255, 0, 0.5)`,
          "--margin-left": `${(marginRatio * 100).toString() + "%"}`,
          "--margin-right": `${((1 - marginRatio) * 100).toString() + "%"}`,
          "--slider-width": `${sliderWidth + "px"}`,
          "--slider-image": `url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' height='128px' width='128px' style='fill:black;font-size:64px;'><text x='50%' y='50%' opacity='1' dominant-baseline='middle' text-anchor='middle'>` + `👍` + `</text></svg>")`,
          "--thumb-size": `${thumbSize + "px"}`,
          "--cursor-type": `${disabled ? "auto" : "grab"}`
        } as React.CSSProperties }
        disabled={disabled}
      />
      <div className="text-xs font-extralight mt-1">  
        { "TODO" }
      </div>
    </div>
	);
};

