import { useEffect, useState, useMemo } from "react";
import { protocolActor } from "../actors/ProtocolActor";
import { fromNullable } from "@dfinity/utils";
import { Ballot } from "@/declarations/protocol/protocol.did";
import { EYesNoChoice, toEnum } from "../utils/conversions/yesnochoice";
import { ResponsiveAreaBump } from "@nivo/bump";

// one day in nanoseconds
const INTERPOLATION_STEP = 24n * 60n * 60n * 1_000_000_000n;

interface CumulateBetweenDatesArgs {
    ballots: [bigint, Ballot][] | undefined;
    firstDate: bigint;
    lastDate: bigint;
}

interface VoteChartrops {
    voteId: bigint;
}

const VoteChart: React.FC<VoteChartrops> = ({ voteId }) => {

  const [firstDate, setFirstDate] = useState<bigint>(0n);
  const [lastDate, setLastDate] = useState<bigint>(0n);

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

    // TODO: optimize because O(n^2)
    // The last date shall always be the current time
    // The first date shall depend on the interval passed as argument (e.g. 1 day, 1 week, 1 month, 1 year, all)
    // First step shall be cumulating all the votes until the first date
    // Second step 
    const cumulateBetweenDates = async({ ballots, firstDate, lastDate }: CumulateBetweenDatesArgs) : Promise<{ x: number; y: number; }[]>=> {

        // Compute all the dates between the first and the last date
        let current = firstDate;
        var promises : Promise<{ date: bigint, decay: Number }>[] = [];
        
        while (current < lastDate) {
            promises.push(computeDecay([{ time: current }]).then((decay) => {
                if (decay === undefined) {
                    throw new Error("Decay is undefined");
                }
                return { date: current, decay: decay };
            }));
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
            while (ballotIndex < numberBallots - 1) {
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

        return data;
    }

    useEffect(() => {
        if (!vote || !currentTime) return;

        const voteData = fromNullable(vote);
        if (!voteData) return;

        setLastDate(currentTime);
        console.log("Last date" + new Date(Number(currentTime / 1_000_000n)));

        let minTimestamp = currentTime;
        voteData.YES_NO.ballot_register.map.forEach(([_, ballot]) => {
            if (ballot.timestamp < minTimestamp) {
                minTimestamp = ballot.timestamp;
            }
        });
        setFirstDate(minTimestamp);
        console.log("First date" + new Date(Number(minTimestamp / 1_000_000n)));

    }, [vote, currentTime]);

    const yesBallots = useMemo(() => {
        return vote ? fromNullable(vote)?.YES_NO.ballot_register.map.filter(([_, ballot]) => toEnum(ballot.choice) === EYesNoChoice.Yes) : [];
    }, [vote]);

    const noBallots = useMemo(() => {
        return vote ? fromNullable(vote)?.YES_NO.ballot_register.map.filter(([_, ballot]) => toEnum(ballot.choice) === EYesNoChoice.No) : [];
    }, [vote]);

    const [yesData, setYesData] = useState<{ x: number; y: number; }[]>([]);

    const [noData, setNoData] = useState<{ x: number; y: number; }[]>([]);

    useEffect(() => {
        if (!yesBallots || !noBallots || !firstDate || !lastDate) return;

        cumulateBetweenDates({ ballots: yesBallots, firstDate, lastDate }).then((data) => {
            setYesData(data);
        });

        cumulateBetweenDates({ ballots: noBallots, firstDate, lastDate }).then((data) => {
            setNoData(data);
        });

    }
    , [yesBallots, noBallots, firstDate, lastDate]);

    return (
      <div style={{ position: 'relative' }} className="h-[20rem] w-[50rem]">
      <ResponsiveAreaBump
      enableGridX={false}
      startLabel={false}
      endLabel={true}
    align= "end"
    data={[
        {
            id: "YES",
            data: []
        },
        {
            id: "NO",
            data: []
        }
    ]}
    margin={{ top: 40, right: 100, bottom: 40, left: 100 }}
    spacing={6}
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
      legend: '',
      legendPosition: 'middle',
      legendOffset: 32,
      renderTick: ({ x, y, value }) => (
          <g transform={`translate(${x},${y})`}>
              <text
                  x={0}
                  y={0}
                  textAnchor="middle"
                  dominantBaseline="central"
                  style={{
                      fontSize: '14px',
                      fill: 'black',
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
    <div style={{ position: 'absolute', top: 40, right: 100, bottom: 40, left: 100 }} className="flex flex-col">
      <div className="flex flex-row w-full items-end">
        <div className="text-black">100k</div>
        <div className="flex w-full h-[1px] bg-gray-300 opacity-25"></div>
      </div>
      <div className="h-20"/>
      <div className="flex flex-row w-full items-end">
        <div className="text-black">100k</div>
        <div className="flex w-full h-[1px] bg-gray-300 opacity-25"></div>
      </div>
      <div className="h-20"/>
      <div className="flex flex-row w-full items-end">
        <div className="text-black">100k</div>
        <div className="flex w-full h-[1px] bg-gray-300 opacity-25"></div>
      </div>
      <div className="h-20"/>
      <div className="flex flex-row w-full items-end">
        <div className="text-black">100k</div>
        <div className="flex w-full h-[1px] bg-gray-300 opacity-25"></div>
      </div>
      <div className="h-20"/>
      <div className="flex flex-row w-full items-end">
        <div className="text-black">100k</div>
        <div className="flex w-full h-[1px] bg-gray-300 opacity-25"></div>
      </div>
      <div className="h-20"/>
    </div>
  </div>

  );
}

export default VoteChart;