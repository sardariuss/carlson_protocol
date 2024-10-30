import { useEffect, useState } from "react";
import { protocolActor } from "../actors/ProtocolActor";
import { fromNullable } from "@dfinity/utils";
import { Ballot } from "@/declarations/protocol/protocol.did";
import { EYesNoChoice, toEnum } from "../utils/conversions/yesnochoice";
import { AreaBumpSerie, ResponsiveAreaBump } from "@nivo/bump";
import { formatBalanceE8s } from "../utils/conversions/token";
import { format } from "date-fns";

// one day in nanoseconds
const INTERPOLATION_STEP = 24n * 60n * 60n * 1_000_000_000n;

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

const CHART_CONFIGURATIONS = new Map<ERange, { interval: bigint, tick: bigint, format: (date: Date) => string }>([
  [ERange.DAY,   { interval: days(1),   tick: minutes(5), format: (date: Date) => format(date,                                     "HH:mm")} ],
  [ERange.WEEK,  { interval: weeks(1),  tick: hours(12),  format: (date: Date) => format(date, date.getHours() === 0 ? "dd MMM" : "HH:mm" )} ],
  [ERange.MONTH, { interval: months(1), tick: days(2),    format: (date: Date) => format(date,                                    "dd MMM")} ],
  [ERange.YEAR,  { interval: years(1),  tick: months(1),  format: (date: Date) => format(date,                                   "MMM 'yy")} ],
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

interface CumulateBetweenDatesArgs {
  ballots: [bigint, Ballot][] | undefined;
  startDate: bigint;
  endDate: bigint;
}

interface VoteChartrops {
  voteId: bigint;
}

const VoteChart: React.FC<VoteChartrops> = ({ voteId }) => {

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
    console.log("Min: " + min + " Max: " + max);
    const range = max - min;
    var interval = 10 ** Math.floor(Math.log10(range));
    var levels = [];
    var current = Math.floor(min / interval) * interval;
    while (current <= max) {
      levels.push(current);
      current += interval;
    }
    console.log(levels);
    return levels;
  }

  // TODO: optimize because O(n^2)
  // The last date shall always be the current time
  // The first date shall depend on the interval passed as argument (e.g. 1 day, 1 week, 1 month, 1 year, all)
  // First step shall be cumulating all the votes until the first date
  // Second step 
  const cumulateBetweenDates = async({ ballots, startDate, endDate }: CumulateBetweenDatesArgs) : Promise<{ x: number; y: number; }[]>=> {
    // Compute all the dates between the first and the last date
    let current = startDate;
    var promises : Promise<{ date: bigint, decay: Number }>[] = [];
      
    while (current < endDate + INTERPOLATION_STEP) {
      promises.push(Promise.resolve({ date: current, decay: 1 }));
//            promises.push(computeDecay([{ time: current }]).then((decay) => {
//                if (decay === undefined) {
//                    throw new Error("Decay is undefined");
//                }
//                return { date: current, decay: decay };
//            }));
        current += INTERPOLATION_STEP;
    }

    // Wait for all the dates to be computed
    const dates = await Promise.all(promises);

    // Make sure the dates are sorted in ascending order
    ballots?.sort(([_, a], [__, b]) => Number(a.timestamp - b.timestamp));

    // Start accumulating the votes
    var accumulated = 0n;
    var ballotIndex = 0;
    const numberBallots = ballots?.length ?? 0;

    var data = [];

    for (const { date, decay } of dates) {

      // Continue accumulating the votes until the date is reached
      while (ballotIndex < numberBallots) {
        const ballot = ballots?.[ballotIndex][1];
        if (ballot !== undefined && ballot.timestamp <= date) {
          accumulated += ballot.amount; // TODO: multiply by decay
          ballotIndex++;
        } else {
          break;
        }
      }

        // Add the accumulated votes to the data
      data.push({ x: Number(date / 1_000_000n), y: Number(accumulated) });
    }
    
    console.log(data);
    return data;
  }

  const [startDate, setStartDate] = useState<bigint>(0n);
  const [endDate, setEndDate] = useState<bigint>(0n);
  const [data, setData] = useState<ChartData>([]);
  const [priceLevels, setPriceLevels] = useState<number[]>([]);
  const [dateTicks, setDateTicks] = useState<number[]>([]);
        
  useEffect(() => {
    
    if (!vote || !currentTime) return;
    
    // Set the first and last date
    const voteData = fromNullable(vote);
    if (!voteData) return;
    
    setEndDate(currentTime);
    console.log("Last date" + new Date(Number(currentTime / 1_000_000n)));
    var start = currentTime;
    voteData.YES_NO.ballot_register.map.forEach(([_, ballot]) => {
        if (ballot.timestamp < start) {
            start = ballot.timestamp;
        }
    });
    setStartDate(start);
    console.log("Start date" + new Date(Number(start / 1_000_000n)));

    console.log(voteData.YES_NO.ballot_register.map)
    
    const yesCumul = cumulateBetweenDates({
      ballots: voteData.YES_NO.ballot_register.map.filter(([_, ballot]) => toEnum(ballot.choice) === EYesNoChoice.Yes),
      startDate: start,
      endDate: currentTime,
    });
    const noCumul = cumulateBetweenDates({
      ballots: voteData.YES_NO.ballot_register.map.filter(([_, ballot]) => toEnum(ballot.choice) === EYesNoChoice.No),
      startDate: start,
      endDate: currentTime,
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
      // Compute the price levels
      var max = 0;
      yesData.entries().forEach(([_, data], index) => {
        const total = data.y + noData[index].y;
        if (total > max) {
          max = total;
        }
      });
      setPriceLevels(getPriceLevels(0, max));
    });
  }
  , [vote, currentTime]);

  // Assuming `data` is an array of your date values
  const reducedTickValues = data[0]?.data.map((d) => d.x).filter((_, i) => i % 5 === 0);

    return (
      <div style={{ position: 'relative' }} className="h-[20rem] w-[50rem]">
        <ResponsiveAreaBump
          enableGridX={false}
          startLabel={false}
          endLabel={true}
          align= "end"
          data={data}
          margin={{ top: 40, right: 100, bottom: 40, left: 100 }}
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
            tickValues: reducedTickValues,
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
                    fontSize: '14px',
                    fill: 'gray',
                  }}
                >
                  { new Date(value).toLocaleDateString() }
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
        <div style={{ position: 'absolute', top: 40, right: 99, bottom: 40, left: 99 }} className="flex flex-col border-l">
          <div className="flex flex-col w-full h-full">
            {
              priceLevels.slice().reverse().map((price, index) => (
                (index < (priceLevels.length - 1)) ? 
                  <div className="flex flex-col w-full h-full">
                    <div className="flex flex-row w-full items-end" style={{ position: 'relative' }}>
                      <div className="text-xs text-gray-500" style={{ position: 'absolute', left: -50, bottom: -7 }}>{ formatBalanceE8s(BigInt(price), "") }</div>
                      <div className="flex w-full h-[1px] bg-gray-500 opacity-10"/>
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