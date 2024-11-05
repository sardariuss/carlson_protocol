import { useEffect, useMemo, useState } from "react";
import { protocolActor } from "../actors/ProtocolActor";
import { Ballot } from "@/declarations/protocol/protocol.did";
import { EYesNoChoice, toEnum } from "../utils/conversions/yesnochoice";
import { AreaBumpSerie, ResponsiveAreaBump } from "@nivo/bump";
import { formatBalanceE8s } from "../utils/conversions/token";
import { format } from "date-fns";
import { SYesNoVote } from "@/declarations/backend/backend.did";
import { BallotInfo } from "./types";
import { DurationUnit, toNs } from "../utils/conversions/duration";

interface CumulateBetweenDatesArgs {
  ballots: [bigint, Ballot][] | undefined;
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

const CHART_CONFIGURATIONS = new Map<DurationUnit, { interval: bigint, sample: bigint, tick: bigint, format: (date: Date) => string }>([
  [DurationUnit.DAY,   { interval: toNs(1, DurationUnit.DAY),   sample: toNs(1, DurationUnit.HOUR), tick: toNs(2, DurationUnit.HOUR),  format: (date: Date) => format(date,                                     "HH:mm")} ],
  [DurationUnit.WEEK,  { interval: toNs(1, DurationUnit.WEEK),  sample: toNs(6, DurationUnit.HOUR), tick: toNs(12, DurationUnit.HOUR), format: (date: Date) => format(date, date.getHours() === 0 ? "dd MMM" : "HH:mm" )} ],
  [DurationUnit.MONTH, { interval: toNs(1, DurationUnit.MONTH), sample: toNs(1, DurationUnit.DAY),  tick: toNs(2, DurationUnit.DAY),   format: (date: Date) => format(date,                                    "dd MMM")} ],
  [DurationUnit.YEAR,  { interval: toNs(1, DurationUnit.YEAR),  sample: toNs(15, DurationUnit.DAY), tick: toNs(1, DurationUnit.MONTH), format: (date: Date) => format(date,                                   "MMM 'yy")} ],
]);

type ChartData = AreaBumpSerie<{x: number; y: number;}, {id: string; data: {x: number; y: number;}[]}>[];

type ChartProperties = { chartData: ChartData, max: number, priceLevels: number[], dateTicks: number[] };

interface VoteChartrops {
  vote: SYesNoVote;
  ballot: BallotInfo;
  range?: DurationUnit;
}

const VoteChart: React.FC<VoteChartrops> = ({ vote, ballot, range = DurationUnit.WEEK }) => {

  const { interval, sample, tick, format: dateFormat } = CHART_CONFIGURATIONS.get(range)!;

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

      // Calculate end and start dates
      var endDate = currentTime;
      endDate -= endDate % sample;
      endDate += sample;
      const startDate = endDate - interval;

      // Compute cumulative data for YES and NO
      const yesCumul = cumulateBetweenDates({
        ballots: vote.ballot_register.map.filter(([_, ballot]) => toEnum(ballot.choice) === EYesNoChoice.Yes),
        startDate,
        endDate,
        sampleInterval: sample,
        computeDecay: (time: bigint) => computeDecay([{ time }]),
      });
      const noCumul = cumulateBetweenDates({
        ballots: vote.ballot_register.map.filter(([_, ballot]) => toEnum(ballot.choice) === EYesNoChoice.No),
        startDate,
        endDate,
        sampleInterval: sample,
        computeDecay: (time: bigint) => computeDecay([{ time }]),
      });

      Promise.all([yesCumul, noCumul]).then(([yesData, noData]) => {
        // Prepare chart data
        const chartData = [];
        if (yesData.length > 0) {
          chartData.push({ id: "YES", data: yesData });
        }
        if (noData.length > 0) {
          chartData.push({ id: "NO", data: noData });
        }

        // Compute max value and price levels
        var max = 0;
        var ticks: number[] = [];
        yesData.entries().forEach(([_, data], index) => {
          const total = data.y + noData[index].y;
          if (total > max) {
            max = total;
          }
          if ((data.x % Number(tick / 1_000_000n)) === 0) {
            ticks.push(data.x);
          }
        });

        setVoteData({
          chartData,
          max,
          priceLevels: computePriceLevels(0, max),
          dateTicks: ticks,
        });
      });
    };

    computeVoteData(vote, currentTime);
  }, [vote, currentTime]);

  const { chartData, max, priceLevels, dateTicks } = useMemo<ChartProperties>(() => {
    return {
      chartData : voteData.chartData.slice().map((serie) => {
        if (serie.id === (ballot.choice === EYesNoChoice.Yes ? "YES" : "NO")) {
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
    <div style={{ position: 'relative' }} className="h-[320px] w-[50rem]">
      <div style={{ position: 'absolute', top: MARGIN, right: 59, bottom: MARGIN, left: 59 }} className="flex flex-col border-x z-10">
        <ul className="flex flex-col w-full" key={vote.vote_id + "levelssss"}>
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
                { dateFormat(new Date(value)) }
              </text>
            </g>
          ),
        }}
        theme={{
          background: "#ffffff",
          text: {
            fontSize: 11,
            fill: "#333333",
            outlineWidth: 0,
            outlineColor: "transparent"
          },
          axis: {
            domain: {
              line: {
                stroke: "#777777",
                strokeWidth: 1
              }
            },
            legend: {
              text: {
                fontSize: 12,
                fill: "#333333",
                outlineWidth: 0,
                outlineColor: "transparent"
              }
            },
            ticks: {
              line: {
                stroke: "#777777",
                strokeWidth: 1
              },
              text: {
                fontSize: 11,
                fill: "#333333",
                outlineWidth: 0,
                outlineColor: "transparent"
              }
            }
          },
          grid: {
            line: {
              stroke: "#dddddd",
              strokeWidth: 1
            }
          },
          legends: {
            title: {
              text: {
                fontSize: 11,
                fill: "#333333",
                outlineWidth: 0,
                outlineColor: "transparent"
              }
            },
            text: {
              fontSize: 11,
              fill: "#333333",
              outlineWidth: 0,
              outlineColor: "transparent"
            },
            ticks: {
              line: {},
              text: {
                fontSize: 10,
                fill: "#333333",
                outlineWidth: 0,
                outlineColor: "transparent"
              }
            }
          },
          annotations: {
            text: {
              fontSize: 13,
              fill: "#333333",
              outlineWidth: 2,
              outlineColor: "#ffffff",
              outlineOpacity: 1
            },
            link: {
              stroke: "#000000",
              strokeWidth: 1,
              outlineWidth: 2,
              outlineColor: "#ffffff",
              outlineOpacity: 1
            },
            outline: {
              stroke: "#000000",
              strokeWidth: 2,
              outlineWidth: 2,
              outlineColor: "#ffffff",
              outlineOpacity: 1
            },
            symbol: {
              fill: "#000000",
              outlineWidth: 2,
              outlineColor: "#ffffff",
              outlineOpacity: 1
            }
          },
          tooltip: {
            wrapper: {},
            container: {
              background: "#ffffff",
              color: "#333333",
              fontSize: 12
            },
            basic: {},
            chip: {},
            table: {},
            tableCell: {},
            tableCellValue: {}
          }
        }}
      />
    </div>
  );
}

export default VoteChart;