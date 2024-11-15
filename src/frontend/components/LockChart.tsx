import { useState, useMemo, useEffect, useRef } from 'react';
import { ResponsiveLine } from '@nivo/line';
import { CHART_BACKGROUND_COLOR } from '../constants';
import { QueriedBallot } from '@/declarations/protocol/protocol.did';

interface LockChartProps {
  ballots: QueriedBallot[];
};

const LockChart = ({ ballots }: LockChartProps) => {

  const data = ballots.map((ballot, index) => {
    const { YES_NO: { timestamp, duration_ns } } = ballot.ballot;

    return {
      id: ballot.ballot_id.toString(), // Ensure id is a string
      data: [
        {
          x: new Date(Number(timestamp / 1_000_000n)),
          y: index,
        },
        {
          x: new Date(Number((timestamp + duration_ns / 2n) / 1_000_000n)), // Midpoint
          y: index,
        },
        {
          x: new Date(Number((timestamp + duration_ns) / 1_000_000n)),
          y: index,
        },
      ],
    };
  });


  // Function to calculate the number of days between two dates
  const getDaysDifference = (startTime: number, endTime: number) => {
    const start = new Date(startTime);
    const end = new Date(endTime);
    const timeDiff = end - start;
    return timeDiff / (1000 * 3600 * 24); // convert milliseconds to days
  };

  // Get the range of the data in terms of time (from first to last date)
  const dateRange = useMemo(() => {
    const allDates = data.flatMap((lock) => lock.data.map((d) => d.x));
    const minDate = Math.min(...allDates.map((date) => date.getTime()));
    const maxDate = Math.max(...allDates.map((date) => date.getTime()));

    const daysDiff = getDaysDifference(minDate, maxDate);
    console.log('daysDiff', daysDiff);
    return { minDate, maxDate, daysDiff };
  }, [data]);

  // Calculate the chart width based on the data range
  const chartWidth = Math.max(1, (dateRange.daysDiff / 30)) * 800; // 800px per month

  // Set up the chart container ref
  const chartContainerRef = useRef(null);

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

  const customLayer = ({ xScale, yScale }) => {
    return (
      <>
        {/* Render custom lines */}
        {processedSegments.map((segment, index) => {
          const { start, end, color } = segment;
          const x1 = xScale(start.x);
          const x2 = xScale(end.x);
          const y1 = yScale(start.y);
          const y2 = yScale(end.y);
  
          return (
            <line
              key={`line-${index}`}
              x1={x1}
              x2={x2}
              y1={y1}
              y2={y2}
              stroke={color}
              strokeWidth={8} // Adjust thickness
            />
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
            format: '%b %d',
            legend: 'Time',
            legendPosition: 'middle',
            legendOffset: 40,
          }}
          axisLeft={{
            tickValues: [1, 2, 3],
            legend: 'Vote ID',
            legendPosition: 'middle',
            legendOffset: -40,
          }}
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
  );
};

export default LockChart;
