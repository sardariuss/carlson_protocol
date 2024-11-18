import { useMemo, useState }                 from "react";
import { protocolActor }                     from "../../actors/ProtocolActor";
import { SBallot }                           from "@/declarations/protocol/protocol.did";
import { EYesNoChoice, toEnum }              from "../../utils/conversions/yesnochoice";
import { AreaBumpSerie, ResponsiveAreaBump } from "@nivo/bump";
import { formatBalanceE8s }                  from "../../utils/conversions/token";
import { SYesNoVote }                        from "@/declarations/backend/backend.did";
import { BallotInfo }                        from "../types";
import { DurationUnit }                from "../../utils/conversions/duration";
import { CHART_BACKGROUND_COLOR }            from "../../constants";
import { CHART_CONFIGURATIONS, computeInterval } from ".";
import IntervalPicker from "./IntervalPicker";

interface CumulateBetweenDatesArgs {
  ballots: [bigint, SBallot][] | undefined;
  startDate: bigint;
  endDate: bigint;
  sampleInterval: bigint;
  computeDecay: (time: bigint) => Promise<number | undefined>;
}

// TODO: optimize because O(n^2)
// The last date shall always be the current time
// The first date shall depend on the interval passed as argument (e.g. 1 day, 1 week, 1 month, 1 year, all)
// First step shall be cumulating all the votes until the first date
// Second step 
const cumulateBetweenDates = async({ ballots, startDate, endDate, sampleInterval, computeDecay }: CumulateBetweenDatesArgs) : Promise<{ x: number; y: number; }[]>=> {
  // Compute all the dates between the first and the last date
  var current = startDate;

  var promises : Promise<{ date: bigint, decay: Number }>[] = [];
    
  while (current < endDate + sampleInterval) {
    promises.push(Promise.resolve({ date: current, decay: 1 }));
    // TODO: uncomment when computeDecay is fixed
//      promises.push(computeDecay([{ time: current }]).then((decay) => {
//          if (decay === undefined) {
//              throw new Error("Decay is undefined");
//          }
//          return { date: current, decay: decay };
//      }));
    current += sampleInterval;
  }

  // Wait for all the dates to be computed
  const dates = await Promise.all(promises);

  // Make sure the dates are sorted in ascending order
  ballots?.sort(([_, a], [__, b]) => Number(a.timestamp - b.timestamp));

  // Start accumulating the votes
  var accumulated = 0;
  var ballotIndex = 0;
  const currentDecay = await computeDecay(endDate).then((decay) => {
    if (decay === undefined) {
        throw new Error("Decay is undefined");
    }
    return decay;
  });
  const numberBallots = ballots?.length ?? 0;

  var data = [];

  for (const { date, decay } of dates) {

    // Continue accumulating the votes until the date is reached
    while (ballotIndex < numberBallots) {
      const ballot = ballots?.[ballotIndex][1];
      if (ballot !== undefined && ballot.timestamp <= date) {
        accumulated += Number(ballot.amount) // TODO: multiply by decay
        ballotIndex++;
      } else {
        break;
      }
    }

    // Add the accumulated votes to the data
    data.push({ x: Number(date / 1_000_000n), y: accumulated }); // TODO: divide by current decay
  }
  
  return data;
}

const computePriceLevels = (min: number, max: number) : number[] => {
  const range = max - min;
  var interval = 10 ** Math.floor(Math.log10(range));
  var levels = [];
  var current = Math.floor(min / interval) * interval;
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
  const lastLine = levels[levels.length - 1];
  const ratio = lastLine / maxY;
  const height = 320 - 2 * MARGIN;
  const margin = (height * ratio - height);
  return margin / 2;
}



type ChartData = AreaBumpSerie<{x: number; y: number;}, {id: string; data: {x: number; y: number;}[]}>[];

type ChartProperties = { chartData: ChartData, max: number, priceLevels: number[], dateTicks: number[] };

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
  });

  const [voteData, setVoteData] = useState<ChartProperties>({
    chartData: [],
    max: 0,
    priceLevels: [],
    dateTicks: []
  });
     
  useMemo(() => {
    
    const computeVoteData = async (vote: SYesNoVote, currentTime: bigint | undefined) => {

      if (!currentTime) {
        setVoteData({ chartData: [], max: 0, priceLevels: [], dateTicks: [] });
        return;
      }

      let { sample } = CHART_CONFIGURATIONS.get(duration)!;

      // Calculate end and start dates
      let { start_ns, end_ns, ticks_ms } = computeInterval(currentTime, duration);

      // Compute cumulative data for YES and NO
      const yesCumul = cumulateBetweenDates({
        ballots: vote.ballot_register.map.filter(([_, ballot]) => toEnum(ballot.choice) === EYesNoChoice.Yes),
        startDate: start_ns,
        endDate: end_ns,
        sampleInterval: sample,
        computeDecay: (time: bigint) => computeDecay([{ time }]),
      });
      const noCumul = cumulateBetweenDates({
        ballots: vote.ballot_register.map.filter(([_, ballot]) => toEnum(ballot.choice) === EYesNoChoice.No),
        startDate: start_ns,
        endDate: end_ns,
        sampleInterval: sample,
        computeDecay: (time: bigint) => computeDecay([{ time }]),
      });

      Promise.all([yesCumul, noCumul]).then(([yesData, noData]) => {
        // Prepare chart data
        const chartData = [];
        if (yesData.length > 0) {
          chartData.push({ id: EYesNoChoice.Yes, data: yesData });
        }
        if (noData.length > 0) {
          chartData.push({ id: EYesNoChoice.No, data: noData });
        }

        // Compute max value and price levels
        var max = 0;
        yesData.entries().forEach(([_, data], index) => {
          const total = data.y + noData[index].y;
          if (total > max) {
            max = total;
          }
        });

        setVoteData({
          chartData,
          max,
          priceLevels: computePriceLevels(0, max),
          dateTicks: ticks_ms,
        });
      });
    };

    computeVoteData(vote, currentTime);
  }, [vote, currentTime, duration]);

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