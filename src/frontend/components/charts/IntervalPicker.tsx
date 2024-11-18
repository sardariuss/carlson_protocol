import { DurationUnit } from "../../utils/conversions/duration";
import { useState } from "react";
import { CHART_CONFIGURATIONS, DurationParameters } from ".";


interface IntervalPickerProps {
  duration: DurationUnit; // Current interval
  setDuration: (duration: DurationUnit) => void; // Callback to set interval
}

const IntervalPicker: React.FC<IntervalPickerProps> = ({ duration, setDuration }) => {

    // Keep track of the currently selected interval
    const handleIntervalChange = (interval: DurationUnit) => {
        setDuration(interval);
    };

    return (
        <div className="flex flex-row space-x-1 bg-gray-800 p-1 rounded">
        {Array.from(CHART_CONFIGURATIONS.keys()).map((interval) => (
            <button
                className={`text-xs w-10 min-w-10 h-6 justify-center items-center button-discrete
                    ${duration === interval ? "bg-gray-700" : "bg-gray-800"}`}
                key={interval}
                onClick={() => handleIntervalChange(interval)}
            >
                {interval} {/* Convert enum to string */}
            </button>
        ))}
        </div>
    );
};

export default IntervalPicker;