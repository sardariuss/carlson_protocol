import Types "Types";
import Timeline "utils/Timeline";
import LedgerFacade "payement/LedgerFacade";

import Set "mo:map/Set";
import Map "mo:map/Map";
import Array "mo:base/Array";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Float "mo:base/Float";
import Int "mo:base/Int";

module {

    type UUID = Types.UUID;
    type Timeline<T> = Types.Timeline<T>;
    type Account = Types.Account;
    type Time = Int;
    type DebtInfo = Types.DebtInfo;
    type TransferResult = Types.TransferResult;
    type TxIndex = Types.TxIndex;

    type Set<K> = Set.Set<K>;
    type Map<K, V> = Map.Map<K, V>;

    public func init_debt_info(time: Time, account: Account) : DebtInfo {
        {
            amount = Timeline.initialize<Float>(time, 0.0);
            account;
            var owed = 0.0;
            var pending = 0;
            var transfers = [];
        };
    };

    public class DebtProcessor({
        ledger: LedgerFacade.LedgerFacade;
        debts: Map<UUID, DebtInfo>;
        owed: Set<UUID>;
    }){

        public func add_debt({ id: UUID; account: Account; amount: Float; time: Time; }) {
            let info : DebtInfo = switch(Map.get(debts, Map.thash, id)){
                case(null) { 
                    init_debt_info(time, account);
                };
                case(?v) { v; };
            };
            Timeline.add(info.amount, time, Timeline.current(info.amount) + amount);
            info.owed += amount;
            Map.set(debts, Map.thash, id, info);
            tag_to_transfer(id, info);
        };

        // TODO: ideally use icrc3 to perform multiple transfers at once
        public func transfer_owed() : async* () {
            let calls = Buffer.Buffer<async* ()>(Set.size(owed));
            label infinite while(true){
                switch(Set.pop(owed, Map.thash)){
                    case(null) { break infinite; };
                    case(?id) {
                        switch(Map.get(debts, Map.thash, id)){
                            case(null) { continue infinite; };
                            case(?v) { calls.add(transfer(id, v)); };
                        };
                    };
                };
            };
            for (call in calls.vals()){
                await* call;
            };
        };

        public func get_owed() : [UUID] {
            Set.toArray(owed);
        };

        public func get_ledger() : LedgerFacade.LedgerFacade {
            ledger;
        };

        func transfer(id: UUID, info: DebtInfo) : async* () {
            let difference : Nat = Int.abs(Float.toInt(info.owed)) - info.pending;
            info.pending += difference;
            // Remove the debt from the set, it will be added back if the transfer fails
            Set.delete(owed, Map.thash, id);
            // Run the transfer
            let transfer = await* ledger.transfer({ to = info.account; amount = difference; });
            info.transfers := Array.append(info.transfers, [transfer]);
            info.pending -= difference;
            // Update what is owed if the transfer succeded
            Result.iterate(transfer.result, func(_: TxIndex){
                info.owed -= Float.fromInt(difference);
            });
            // Add the debt back in case there is still something owed
            tag_to_transfer(id, info);
        };

        func tag_to_transfer(id: UUID, info: DebtInfo) {
            if (info.owed > 1.0) {
                Set.add(owed, Map.thash, id);
            } else {
                Set.delete(owed, Map.thash, id);
            };
        };

    };

};