import Decay "../src/Decay";
import Duration "../src/Duration";
import Protocol "../src/Protocol";

import { test; suite; } "mo:test";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Debug "mo:base/Debug";
import Float "mo:base/Float";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Principal "mo:base/Principal";


suite("Decay", func(){

    type Time = Time.Time;

    func try_repetitive_unlock(protocol: Protocol.Protocol, time_now: Time, target_time: Time) : [Protocol.TokensLock] {
        let buffer = Buffer.Buffer<Protocol.TokensLock>(0);
        // Arbirarily take 10 timestamps between time_now and target_time
        for (i in Iter.range(0, 9)) {
            let t = time_now + (target_time - time_now) * i / 10;
            let locks = protocol.try_unlock(t);
            for (lock in Array.vals(locks)) {
                buffer.add(lock);
            };
        };
        Buffer.toArray(buffer);
    };
    
    func print_lock(lock: Protocol.TokensLock) {
        Debug.print("tx_id = " # debug_show(lock.tx_id));
        Debug.print("amount = " # debug_show(lock.amount));
        Debug.print("timestamp = " # debug_show(lock.timestamp));
        Debug.print("growth = " # debug_show(lock.rates.growth));
        Debug.print("decay = " # debug_show(lock.rates.decay));
        Debug.print("time_left = " # debug_show(lock.time_left));
    };

    test("Test decay", func(){
        let t0 = Time.now();
        let params = Decay.getDecayParameters({ half_life = #HOURS(1); time_init = t0; });

        let decay_1 = Decay.computeDecay(params, t0);
        let decay_2 = Decay.computeDecay(params, t0 + Duration.toTime(#HOURS(1)));

        Debug.print("decay ratio: " # debug_show(decay_2 / decay_1));
        assert(Float.equalWithin(decay_2 / decay_1, 2.0, 1e-9));
    });

    test("Protocol 1", func(){
        let t0 = Time.now();
        let account = { owner = Principal.fromText("aaaaa-aa"); subaccount = null; };

        let ns_per_sat = Int.abs(Duration.toTime(#MINUTES(5))); // 5 minutes per sat
        let decay_params = Decay.getDecayParameters({ half_life = #HOURS(1); time_init = t0; });
        let protocol = Protocol.Protocol({ ns_per_sat; decay_params; });

        assert(protocol.get_locks().size() == 0);

        // Tx0, at t=0, lock 4 sats:
        // -> Lock0 shall be locked for 20 minutes
        protocol.lock({ from = account; tx_id = 0; timestamp = t0; amount = 4 });

        assert(protocol.get_locks().size() == 1);
        var lock0 = protocol.get_locks()[0];
        assert(lock0.tx_id == 0);
        assert(lock0.amount == 4);
        assert(lock0.timestamp == t0);
        Debug.print("Lock 0 growth = " # debug_show(lock0.rates.growth));
        Debug.print("Lock 0 decay = " # debug_show(lock0.rates.decay));
        Debug.print("Lock 0 time left = " # debug_show(Float.toInt(lock0.time_left)));
        assert(Float.toInt(Float.nearest(lock0.time_left)) == Duration.toTime(#MINUTES(20)));

        // Try to unlock till 19 minutes shall fail
        assert(try_repetitive_unlock(protocol, t0, t0 + 19).size() == 0);
        assert(protocol.get_locks().size() == 1);

        // Tx1, at t=10s, lock 6 sats
        // -> Lock1 shall be locked for more than 30 minutes but less than 50 minutes
        // -> Lock0 shall now be locked for more than 20 minutes but less than 50 minutes

        let t1 = t0 + Duration.toTime(#MINUTES(10));

        protocol.lock({ from = account; tx_id = 1; timestamp = t1; amount = 6 });
        assert(protocol.get_locks().size() == 2);

        // Test lock0
        lock0 := protocol.get_locks()[0];
        assert(lock0.tx_id == 0);
        assert(lock0.amount == 4);
        assert(lock0.timestamp == t0);
        Debug.print("Lock 0 time left = " # debug_show(Float.toInt(lock0.time_left)));
        assert(Float.toInt(Float.nearest(lock0.time_left)) > Duration.toTime(#MINUTES(20)));
        assert(Float.toInt(Float.nearest(lock0.time_left)) < Duration.toTime(#MINUTES(50)));

        // Test lock1
        var lock1 = protocol.get_locks()[1];
        assert(lock1.tx_id == 1);
        assert(lock1.amount == 6);
        assert(lock1.timestamp == t1);
        Debug.print("Lock 1 growth = " # debug_show(lock1.rates.growth));
        Debug.print("Lock 1 decay = " # debug_show(lock1.rates.decay));
        Debug.print("Lock 1 time left = " # debug_show(Float.toInt(lock1.time_left)));
        assert(Float.toInt(Float.nearest(lock1.time_left)) > Duration.toTime(#MINUTES(30)));
        assert(Float.toInt(Float.nearest(lock1.time_left)) < Duration.toTime(#MINUTES(50)));

        // Try to unlock till the lock0's time_left is over shall fail
        assert(try_repetitive_unlock(protocol, t0, t0 + Float.toInt(Float.nearest(lock0.time_left))).size() == 0);
        assert(protocol.get_locks().size() == 2);

        //// Try to unlock after the lock0's time_left is over shall succeed
        assert(protocol.try_unlock(t0 + Float.toInt(Float.nearest(lock0.time_left)) + 1).size() == 1);
        assert(protocol.get_locks().size() == 1);

        // Tx2, at t=20s, lock 8 sats
    });
    
})