
import { STimeline_1 } from "@/declarations/backend/backend.did";
import { nsToMs } from "../../utils/conversions/date";

import { ResponsiveLine, Serie } from '@nivo/line';
import { useMemo, useRef } from "react";
import { CHART_BACKGROUND_COLOR } from "../../constants";
import { protocolActor } from "../../actors/ProtocolActor";
import { formatDuration } from "../../utils/conversions/duration";
import { format } from "date-fns";

interface DurationChartProps {
  duration_timeline: STimeline_1;
};
  
const DurationChart = ({ duration_timeline }: DurationChartProps) => {

  const { data: currentTime } = protocolActor.useQueryCall({
    functionName: "get_time",
  });

  // Set up the chart container ref
  const chartContainerRef = useRef<HTMLDivElement | null>(null);

  const data = useMemo(() => {
    const data : Serie[] = [];
    let points = duration_timeline.history.map((duration_ns) => {
      return {
        x: new Date(nsToMs(duration_ns.timestamp)),
        y: isNaN(duration_ns.data) ? 0 : duration_ns.data
      };
    });
    points.push({
      x: new Date(nsToMs(duration_timeline.current.timestamp)),
      y: isNaN(duration_timeline.current.data) ? 0 : duration_timeline.current.data
    });
    if (currentTime) {
      points.push({
        x: new Date(nsToMs(currentTime)),
        y: duration_timeline.current.data
      });
    }
    data.push({
      id: "Duration",
      data: points
    });
    return data;
  }, [duration_timeline, currentTime]);

  return (
    <div className="flex flex-col items-center space-y-1">
      <div
        ref={chartContainerRef}
        style={{
          width: '800px', // Visible area
          height: `400px`, // Dynamic height based on data length
          overflowX: 'auto',
          overflowY: 'hidden',
        }}
      >
        <ResponsiveLine
          data={data}
          xScale={{
            type: 'time',
          }}
          yScale={{
            type: 'linear',
          }}
          animate={false}
          theme={{
            background: CHART_BACKGROUND_COLOR,
          }}
          enablePoints={false}
          margin={{ top: 50, right: 50, bottom: 50, left: 90 }}
          axisBottom={{
            renderTick: ({ tickIndex, x, y, value }) => {
              return (
                tickIndex % 1 ? <></> :
                <g transform={`translate(${x},${y})`}>
                  <text
                    x={0}
                    y={16}
                    textAnchor="middle"
                    dominantBaseline="central"
                    style={{
                      fontSize: '12px',
                      fill: 'gray',
                    }}
                  >
                    { format(new Date(value), "dd MMM") }
                  </text>
                </g>
              );
            }
          }}
          axisLeft={{
            renderTick: ({ tickIndex, x, y, value }) => {
              return (
                tickIndex % 2 ? <></> :
                <g transform={`translate(${x},${y})`}>
                <text
                  x={-36}
                  y={0}
                  textAnchor="middle"
                  dominantBaseline="central"
                  style={{
                    fontSize: '12px',
                    fill: 'gray',
                  }}
                >
                  { value /*formatDuration(BigInt(value))*/ }
                </text>
              </g>
              );
            }
          }}
          curve="linear"
        />
      </div>
    </div>
  );
}

export default DurationChart;