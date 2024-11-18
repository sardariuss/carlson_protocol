import { useMemo, useEffect, useRef, useState } from 'react';
import { ResponsiveLine } from '@nivo/line';
import { CHART_BACKGROUND_COLOR } from '../../constants';
import { SQueriedBallot } from '@/declarations/protocol/protocol.did';
import { get_first, get_last } from '../../utils/history';
import IntervalPicker from './IntervalPicker';
import { DurationUnit, toNs } from '../../utils/conversions/duration';
import { CHART_CONFIGURATIONS, computeTicksMs } from '.';

interface LockChartProps {
  ballots: SQueriedBallot[];
  selected: number | null;
  select_ballot: (index: number | null) => void;
};

const LockChart = ({ ballots, selected, select_ballot }: LockChartProps) => {

  const [duration, setDuration] = useState<DurationUnit>(DurationUnit.WEEK);

  const data = ballots.map((ballot, index) => {
    const { YES_NO: { timestamp, duration_ns } } = ballot.ballot;


    const data = [
      {
        x: new Date(Number(timestamp / 1_000_000n)),
        y: index,
      },
      {
        x: new Date(Number((timestamp + get_first(duration_ns).data) / 1_000_000n)),
        y: index,
      },
      {
        x: new Date(Number((timestamp + get_last(duration_ns).data) / 1_000_000n)),
        y: index,
      },
    ];


    return {
      id: index.toString(), // Watchout, we use the index as the id
      data,
    };
  });


  // Function to calculate the number of days between two timestamps
  const getDaysDifference = (startTime: number, endTime: number): number => {
    const start = new Date(startTime);  // Converts startTime to a Date object
    const end = new Date(endTime);      // Converts endTime to a Date object
    const timeDiff = end.getTime() - start.getTime();  // Difference in milliseconds
    return timeDiff / (1000 * 3600 * 24); // Convert milliseconds to days
  };

  // Get the range of the data in terms of time (from first to last date)
  const dateRange = useMemo(() => {
    const allDates = data.flatMap((lock) => lock.data.map((d) => d.x));
    const minDate = Math.min(...allDates.map((date) => date.getTime()));
    const maxDate = Math.max(...allDates.map((date) => date.getTime()));

    const nsDiff = (maxDate - minDate) * 1_000_000;
    return { minDate, maxDate, nsDiff };
  }, [data]);

  // Calculate the chart width based on the data range
  const chartWidth = Math.max(1, (dateRange.nsDiff / Number(toNs(1, duration)))) * 800; // 800px per month

  const ticks = computeTicksMs(
    BigInt(dateRange.minDate) * 1_000_000n,
    BigInt(dateRange.maxDate) * 1_000_000n,
    CHART_CONFIGURATIONS.get(duration)!.tick
  );

  // Set up the chart container ref
  const chartContainerRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    const currentDate = new Date();
    const currentDateTimestamp = currentDate.getTime();

    // Scroll center calculation
    const rangeStart = dateRange.minDate;
    const rangeEnd = dateRange.maxDate;
    const totalRange = rangeEnd - rangeStart;

    // Calculate the position of the current date within the time range
    const relativePosition = (currentDateTimestamp - rangeStart) / totalRange;

    // Calculate the scroll position to center the current date
    const scrollPosition = relativePosition * (chartWidth - 800); // Adjusted by the chart width and visible area

    if (chartContainerRef.current) {
      chartContainerRef.current.scrollLeft = scrollPosition;
    }
  }, [dateRange, chartWidth]);

  // Preprocess data to generate segments with separate colors
  const processedSegments = useMemo(() => {
    const colors = ['#FF6347', '#1E90FF']; // Colors for segments
    return data.flatMap((lock) => {
      const { id, data: points } = lock;
      const segments = [];
      for (let i = 0; i < points.length - 1; i++) {
        segments.push({
          id,
          start: points[i],
          end: points[i + 1],
          color: colors[i % colors.length], // Alternate colors
        });
      }
      return segments;
    });
  }, [data]);

  interface CustomLayerProps {
    xScale: (value: number | string | Date) => number; // Nivo scale function
    yScale: (value: number | string | Date) => number; // Nivo scale function
  }

  const customLayer = ({ xScale, yScale }: CustomLayerProps) => {
    return (
      <>
        {/* Render custom lines */}
        {processedSegments.map((segment, index) => {
          const { start, end, color } = segment;
          const x1 = xScale(start.x);
          const x2 = xScale(end.x);
          const y1 = yScale(start.y);
          const y2 = yScale(end.y);

          const id = Number(segment.id)

          const border_width = 1;
  
          return (
            <>
              {/* Border line */}
              <line
                key={`border-${index}`}
                x1={x1-border_width}
                x2={x2+border_width}
                y1={y1}
                y2={y2}
                stroke="red" // Border color
                strokeWidth={20 + 2 * border_width} // Slightly larger than the main line
                strokeLinejoin="round"
                style={{
                  opacity: 0.5, // Optional: make the border slightly transparent
                }}
              />

              {/* Main line */}
              <line
                key={`line-${index}`}
                x1={x1}
                x2={x2}
                y1={y1}
                y2={y2}
                stroke={color}
                strokeWidth={20} // Adjust thickness
                onClick={() => select_ballot(id === selected ? null : id)}
                cursor="pointer"
                style={{
                  filter: id === selected ? 'brightness(1.5)' : 'brightness(1)', // Adjust brightness
                }}
              />
            </>
          );
        })}
  
        {/* Render custom lock labels */}
        {processedSegments.map((segment, index) => {
          const { start, id } = segment;
          const x = xScale(start.x); // Position for the label
          const y = yScale(start.y);
  
          return (
            <text
              key={`label-${index}`}
              x={x}
              y={y} // Adjust Y position above the bar
              textAnchor="middle"
              fontSize={12}
              fill="black" // Label color
            >
              {id}
            </text>
          );
        })}
      </>
    );
  };

  return (
    <div className="flex flex-col items-center space-y-1">
      <div
        ref={chartContainerRef}
        style={{
          width: '800px', // Visible area
          height: `${data.length * 75}px`, // Dynamic height based on data length
          overflowX: 'auto',
          overflowY: 'hidden',
        }}
      >
        <div
          style={{
            width: `${chartWidth}px`, // Dynamic width based on data range
            height: '100%',
          }}
        >
          <ResponsiveLine
            data={data}
            xScale={{
              type: 'time',
              format: '%Y-%m-%d',
              precision: 'day',
            }}
            enableGridY={false}
            enableGridX={true}
            xFormat="time:%Y-%m-%d"
            axisBottom={{
              tickSize: 5,
              tickPadding: 5,
              tickRotation: 0,
              tickValues: ticks,
              legend: '',
              legendPosition: 'middle',
              legendOffset: 64,
              renderTick: ({ x, y, value }) => (
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
                    { CHART_CONFIGURATIONS.get(duration)!.format(new Date(value)) }
                  </text>
                </g>
              ),
            }}
            axisLeft={null}
            enablePoints={false}
            lineWidth={20}
            colors={{ scheme: 'category10' }}
            margin={{ top: 50, right: 50, bottom: 50, left: 60 }}
            markers={[
              {
                axis: 'x',
                value: new Date().getTime(), // Convert string to timestamp
                lineStyle: {
                  stroke: '#ff0000',
                  strokeWidth: 1,
                },
              },
            ]}
            theme={{
              background: CHART_BACKGROUND_COLOR,
            }}
            layers={[
              'grid',
              'axes',
              'lines',
              'markers',
              'legends',
              customLayer, // Add custom layer
            ]}
          />
        </div>
      </div>
      <IntervalPicker duration={duration} setDuration={setDuration} />
    </div>
  );
};

export default LockChart;
