import { useEffect, useState } from "react";
import { protocolActor } from "../actors/ProtocolActor";
import { fromNullable } from "@dfinity/utils";
import { Ballot } from "@/declarations/protocol/protocol.did";
import { EYesNoChoice, toEnum } from "../utils/conversions/yesnochoice";
import { AreaBumpSerie, ResponsiveAreaBump } from "@nivo/bump";
import { formatBalanceE8s } from "../utils/conversions/token";
import { format } from "date-fns";

const minutes = (n: number) => BigInt(n) * 60n  * 1_000_000_000n;
const hours   = (n: number) => BigInt(n) * 60n  * minutes(1);
const days    = (n: number) => BigInt(n) * 24n  * hours(1);
const weeks   = (n: number) => BigInt(n) * 7n   * days(1);
const months  = (n: number) => BigInt(n) * 30n  * days(1);
const years   = (n: number) => BigInt(n) * 365n * days(1);

enum ERange {
  DAY,
  WEEK,
  MONTH,
  YEAR,
};

const CHART_CONFIGURATIONS = new Map<ERange, { interval: bigint, sample: bigint, tick: bigint, format: (date: Date) => string }>([
  [ERange.DAY,   { interval: days(1),   sample: hours(1), tick: hours(2),  format: (date: Date) => format(date,                                     "HH:mm")} ],
  [ERange.WEEK,  { interval: weeks(1),  sample: hours(6), tick: hours(12), format: (date: Date) => format(date, date.getHours() === 0 ? "dd MMM" : "HH:mm" )} ],
  [ERange.MONTH, { interval: months(1), sample: days(1),  tick: days(2),   format: (date: Date) => format(date,                                    "dd MMM")} ],
  [ERange.YEAR,  { interval: years(1),  sample: days(15), tick: months(1), format: (date: Date) => format(date,                                   "MMM 'yy")} ],
]);

type ChartData = AreaBumpSerie<{
  x: number;
  y: number;
}, {
  id: string;
  data: {
    x: number;
    y: number;
  }[];
}>[];

interface VoteChartrops {
  voteId: bigint;
  range?: ERange;
}

const VoteChart: React.FC<VoteChartrops> = ({ voteId, range = ERange.WEEK }) => {

  const { interval, sample, tick, format: dateFormat } = CHART_CONFIGURATIONS.get(range)!;

  const { data: vote } = protocolActor.useQueryCall({
    functionName: "find_vote",
    args: [{ vote_id: voteId }]
  });

  const { data: currentTime } = protocolActor.useQueryCall({
    functionName: "get_time",
  });

  const { call: computeDecay } = protocolActor.useQueryCall({
    functionName: "compute_decay",
  });

  const getPriceLevels = (min: number, max: number) : number[] => {
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

  interface CumulateBetweenDatesArgs {
    ballots: [bigint, Ballot][] | undefined;
    startDate: bigint;
    endDate: bigint;
    sampleInterval: bigint;
  }

  // TODO: optimize because O(n^2)
  // The last date shall always be the current time
  // The first date shall depend on the interval passed as argument (e.g. 1 day, 1 week, 1 month, 1 year, all)
  // First step shall be cumulating all the votes until the first date
  // Second step 
  const cumulateBetweenDates = async({ ballots, startDate, endDate, sampleInterval }: CumulateBetweenDatesArgs) : Promise<{ x: number; y: number; }[]>=> {
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
    const currentDecay = await computeDecay([{ time: endDate }]).then((decay) => {
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

  const [data, setData] = useState<ChartData>([]);
  const [priceLevels, setPriceLevels] = useState<number[]>([]);
  const [max, setMax] = useState<number>(0);
  const [dateTicks, setDateTicks] = useState<number[]>([]);
        
  useEffect(() => {
    
    if (!vote || !currentTime) return;
    
    // Set the first and last date
    const voteData = fromNullable(vote);
    if (!voteData) return;
    
    var endDate = currentTime;
    endDate -= endDate % sample;
    endDate += sample;
    const startDate = endDate - interval;
    
    const yesCumul = cumulateBetweenDates({
      ballots: voteData.YES_NO.ballot_register.map.filter(([_, ballot]) => toEnum(ballot.choice) === EYesNoChoice.Yes),
      startDate,
      endDate,
      sampleInterval: sample,
    });
    const noCumul = cumulateBetweenDates({
      ballots: voteData.YES_NO.ballot_register.map.filter(([_, ballot]) => toEnum(ballot.choice) === EYesNoChoice.No),
      startDate,
      endDate,
      sampleInterval: sample,
    });
    
    Promise.all([yesCumul, noCumul]).then(([yesData, noData]) => {
        
      // Set the data for the chart
      var chartData = [];
      if (yesData.length > 0) {
        chartData.push({ id: "YES", data: yesData });
      }
      if (noData.length > 0) {
        chartData.push({ id: "NO", data: noData });
      }
      setData(chartData);
      
      // Compute the price levels and ticks
      var max = 0;
      var ticks : number[] = [];
      yesData.entries().forEach(([_, data], index) => {
        const total = data.y + noData[index].y;
        if (total > max) {
          max = total;
        }
        if ((data.x % Number(tick / 1_000_000n)) === 0) {
          ticks.push(data.x);
        }
      });
      setMax(max);
      setPriceLevels(getPriceLevels(0, max));

      // Set the date ticks
      setDateTicks(ticks);
    });
  }
  , [vote, currentTime]);

  const getHeightLine = () => {
    return (320 - 2 * MARGIN) / (priceLevels.length - 1);
  }

  const MARGIN = 50;

  const marginTop = () => {
    const lastLine = priceLevels[priceLevels.length - 1];
    const ratio = lastLine / max;
    const height = 320 - 2 * MARGIN;
    const margin = (height * ratio - height);
    return margin / 2;
  }

  return (
    <div style={{ position: 'relative' }} className="h-[320px] w-[50rem]">
      <ResponsiveAreaBump
        enableGridX={false}
        startLabel={false}
        endLabel={true}
        align= "end"
        data={data}
        margin={{ top: MARGIN + marginTop(), right: 60, bottom: MARGIN, left: 0 }}
        spacing={0}
        colors={["#4CAF50", "#F44336"]} // Green for YES, Red for NO
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
      <div style={{ position: 'absolute', top: MARGIN, right: 59, bottom: MARGIN, left: 59 }} className="flex flex-col border-x">
        <div className="flex flex-col w-full">
          {
            priceLevels.slice().reverse().map((price, index) => (
              (index < (priceLevels.length - 1)) ? 
                <div className={`flex flex-col w-full`} style={{ height: `${getHeightLine()}px` }}>
                  <div className="flex flex-row w-full items-end" style={{ position: 'relative' }}>
                    <div className="text-xs text-gray-500" style={{ position: 'absolute', left: -55, bottom: -7 }}>{ formatBalanceE8s(BigInt(price), "") }</div>
                    <div className="flex w-full h-[0.5px] bg-gray-300 opacity-50" style={{ position: 'absolute', bottom: 0 }}/>
                  </div>
                </div>  
                : <></>
            ))
          }
        </div>
      </div>
    </div>
  );
}

export default VoteChart;