import { useEffect } from "react";
import { protocolActor } from "../actors/ProtocolActor";
import DurationChart from "./charts/DurationChart";
import { to_number_timeline } from "../utils/timeline";

const Info = () => {

    const { data: presenceInfo, call: refreshPresenceInfo } = protocolActor.useQueryCall({
        functionName: "get_presence_info",
        args: [],
    });

    useEffect(() => {
        refreshPresenceInfo();
    }
    , []);

      
    return (
        presenceInfo ? (
            <div className="flex flex-col items-center">
                <div>Amount locked</div>
                <DurationChart duration_timeline={to_number_timeline(presenceInfo.ck_btc_locked)} />
            </div>
        ) : <div>Presence Info not found</div>
    )
}

export default Info;