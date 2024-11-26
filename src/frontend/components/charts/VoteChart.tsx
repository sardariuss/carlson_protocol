import { useMemo, useState }                     from "react";
import { protocolActor }                         from "../../actors/ProtocolActor";
import { STimeline_2 }                           from "@/declarations/protocol/protocol.did";
import { EYesNoChoice }                          from "../../utils/conversions/yesnochoice";
import { AreaBumpSerie, ResponsiveAreaBump }     from "@nivo/bump";
import { formatBalanceE8s }                      from "../../utils/conversions/token";
import { SYesNoVote }                            from "@/declarations/backend/backend.did";
import { BallotInfo }                            from "../types";
import { DurationUnit }                          from "../../utils/conversions/duration";
import { CHART_BACKGROUND_COLOR }                from "../../constants";
import { CHART_CONFIGURATIONS, computeInterval } from ".";
import IntervalPicker                            from "./IntervalPicker";

interface ComputeChartPropsArgs {
  currentTime: bigint;
  duration: DurationUnit;
  aggregate: STimeline_2;
}

type ChartData = AreaBumpSerie<{x: number; y: number;}, {id: string; data: {x: number; y: number;}[]}>[];
type ChartProperties = { chartData: ChartData, max: number, priceLevels: number[], dateTicks: number[] };

const computeChartProps = ({ currentTime, duration, aggregate } : ComputeChartPropsArgs) : ChartProperties => {

  let chartData : ChartData = [
    { id: EYesNoChoice.Yes, data: [] },
    { id: EYesNoChoice.No, data: [] },
  ];

  const { dates, ticks } = computeInterval(currentTime, duration);

  let yesAggregate = 0n;
  let noAggregate = 0n;
  let max = 0n;
  let nextAggregateIndex = 0;

  let aggregate_history = [...aggregate.history, aggregate.current];
  
  dates.forEach(({ date }) => {
    // Update aggregate while the next timestamp is within range
    while (
      nextAggregateIndex < aggregate_history.length &&
      date >= Number(aggregate_history[nextAggregateIndex].timestamp / 1_000_000n)
    ) {
      const { data } = aggregate_history[nextAggregateIndex++];
      yesAggregate = data.total_yes;
      noAggregate = data.total_no;
  
      // Update max total
      const total = data.total_yes + data.total_no;
      if (total > max) max = total;
    }
  
    // Push the current data points to chartData
    chartData[0].data.push({ x: date, y: Number(yesAggregate) });
    chartData[1].data.push({ x: date, y: Number(noAggregate) });
  });

  return {
    chartData,
    max: Number(max),
    priceLevels: computePriceLevels(0, Number(max)),
    dateTicks: ticks
  }
}

const computePriceLevels = (min: number, max: number) : number[] => {
  const range = max - min;
  let interval = 10 ** Math.floor(Math.log10(range));
  let levels = [];
  let current = Math.floor(min / interval) * interval;
  while (current < max + interval) {
    levels.push(current);
    current += interval;
  }
  return levels;
}

const getHeightLine = (levels: number[]) => {
  return (320 - 2 * MARGIN) / (levels.length - 1);
}

const MARGIN = 50;

const marginTop = (levels: number[], maxY: number) => {
  if (levels.length === 0) {
    return 0;
  }
  const lastLine = levels[levels.length - 1];
  const ratio = lastLine / maxY;
  const height = 320 - 2 * MARGIN;
  const margin = (height * ratio - height);
  return margin / 2;
}

interface VoteChartrops {
  vote: SYesNoVote;
  ballot: BallotInfo;
}

const VoteChart: React.FC<VoteChartrops> = ({ vote, ballot }) => {

  const [duration, setDuration] = useState<DurationUnit>(DurationUnit.WEEK);

  const { data: currentTime } = protocolActor.useQueryCall({
    functionName: "get_time",
  });

  const { call: computeDecay } = protocolActor.useQueryCall({
    functionName: "compute_decay",
    // TODO: Hack to prevent illegitimate error 'Wrong number of message arguments'
    args: [{time: 0n }],
  });
     
  const voteData = useMemo<ChartProperties>(() => {
    if (!currentTime) {
      return ({ chartData: [], max: 0, priceLevels: [], dateTicks: [] });
    }
    return computeChartProps({ currentTime, duration, aggregate: vote.aggregate });
  }, 
  [vote, currentTime, duration]);

  const { chartData, max, priceLevels, dateTicks } = useMemo<ChartProperties>(() => {
    return {
      chartData : voteData.chartData.slice().map((serie) => {
        if (serie.id === (ballot.choice.toString())) {
          const lastPoint = serie.data[serie.data.length - 1];
          const newLastPoint = { x: lastPoint.x, y: lastPoint.y + Number(ballot.amount) };
          return { id: serie.id, data: [...serie.data.slice(0, serie.data.length - 1), newLastPoint] };
        };
        return serie;
      }),
      max: voteData.max + Number(ballot.amount),
      priceLevels: computePriceLevels(0, voteData.max + Number(ballot.amount)),
      dateTicks: voteData.dateTicks
    };
  }, [voteData, ballot]);

  return (
    <div className="flex flex-col items-center space-y-2">
      <div style={{ position: 'relative' }} className="h-[320px] w-[50rem]">
        <div style={{ position: 'absolute', top: MARGIN, right: 59, bottom: MARGIN, left: 59 }} className="flex flex-col border-x z-10">
          <ul className="flex flex-col w-full" key={vote.vote_id}>
            {
              priceLevels.slice().reverse().map((price, index) => (
                <li key={index}>
                  {
                    (index < (priceLevels.length - 1)) ? 
                    <div className={`flex flex-col w-full`} style={{ height: `${getHeightLine(priceLevels)}px` }}>
                      <div className="flex flex-row w-full items-end" style={{ position: 'relative' }}>
                        <div className="text-xs text-gray-500" style={{ position: 'absolute', left: -55, bottom: -7 }}>{ formatBalanceE8s(BigInt(price), "") }</div>
                        <div className="flex w-full h-[0.5px] bg-gray-300 opacity-50" style={{ position: 'absolute', bottom: 0 }}/>
                      </div>
                    </div> : <></>
                  }
                </li>
              ))
            }
          </ul>
        </div>
        <ResponsiveAreaBump
          isInteractive={false}
          animate={false}
          enableGridX={false}
          startLabel={false}
          endLabel={true}
          align= "end"
          data={chartData}
          margin={{ top: MARGIN + marginTop(priceLevels, max), right: 60, bottom: MARGIN, left: 0 }}
          spacing={0}
          colors={["rgb(34 197 94)", "rgb(239 68 68)"]} // Green for YES, Red for NO
          blendMode="multiply"
          borderColor={{
              from: 'color',
              modifiers: [['darker', 0.7]]
          }}
          axisTop={null}
          axisBottom={{
            tickSize: 5,
            tickPadding: 5,
            tickRotation: 0,
            tickValues: dateTicks,
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
          theme={{
            background: CHART_BACKGROUND_COLOR,
          }}
        />
      </div>
      <IntervalPicker duration={duration} setDuration={setDuration} />
    </div>
  );
}

export default VoteChart;