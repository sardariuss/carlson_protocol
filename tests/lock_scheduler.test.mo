import Duration         "../src/Duration";
import LockScheduler    "../src/LockScheduler";

import { test; suite; } "mo:test";
import Time             "mo:base/Time";
import Int              "mo:base/Int";
import Debug            "mo:base/Debug";
import Float            "mo:base/Float";
import Buffer           "mo:base/Buffer";
import Iter             "mo:base/Iter";
import Text             "mo:base/Text";

import Map              "mo:map/Map";

suite("LockScheduler suite", func(){

    type Time = Time.Time;
    type Lock =  LockScheduler.Lock;
    type LockScheduler = LockScheduler.LockScheduler<LockScheduler.Lock>;

    // For the test, every "satoshi" of hotness is equivalent to 5 minutes of lock duration
    func hotness_to_duration(hotness: Float) : Nat {
        Int.abs(Float.toInt(hotness * Float.fromInt(Duration.toTime(#MINUTES(5)))));
    };

    func lock_to_text(lock: Lock) : Text {
        let buffer = Buffer.Buffer<Text>(6);
        buffer.add("id = " # debug_show(lock.id));
        buffer.add("amount = " # debug_show(lock.amount));
        buffer.add("timestamp = " # debug_show(lock.timestamp));
        buffer.add("growth = " # debug_show(lock.rates.growth));
        buffer.add("decay = " # debug_show(lock.rates.decay));
        buffer.add("hotness = " # debug_show(lock.hotness));
        buffer.add("(duration = " # debug_show(hotness_to_duration(lock.hotness)) # " ns)");
        Text.join("\\n", buffer.vals());
    };

    func lock_passthrough(lock: LockScheduler.Lock) : LockScheduler.Lock { lock; };

    func try_repetitive_unlock(lock_scheduler: LockScheduler, map: Map.Map<Nat, LockScheduler.Lock>, time_now: Time, target_time: Time) : [LockScheduler.Lock] {
        let buffer = Buffer.Buffer<LockScheduler.Lock>(0);
        // Arbitrarily take 10 timestamps between time_now and target_time
        for (i in Iter.range(0, 9)) {
            let time = time_now + (target_time - time_now) * i / 10;
            buffer.append(lock_scheduler.try_unlock({ map; time; }));
        };
        Buffer.toArray(buffer);
    };

    func unwrap_lock(lock: ?LockScheduler.Lock) : LockScheduler.Lock {
        switch(lock) {
            case (?l) { l; };
            case (null) { Debug.trap("Failed to unwrap lock"); };
        };
    };

    test("LockScheduler test 1", func(){
        let t0 = Time.now();
        
        let lock_scheduler = LockScheduler.LockScheduler<LockScheduler.Lock>({
            time_init = t0;
            hotness_half_life = #HOURS(1);
            get_lock_duration_ns = hotness_to_duration;
            to_lock = lock_passthrough;
        });

        let map = Map.new<Nat, LockScheduler.Lock>();

        assert(Map.size(map) == 0);

        // Tx0, at t=0, lock 4 sats:
        // -> Lock0 shall be locked for 20 minutes
        var lock0 = lock_scheduler.new_lock({ map; id = 0; amount = 4; timestamp = t0; from_lock = lock_passthrough; });
        assert(Map.size(map) == 1);
        assert(lock0.id == 0);
        assert(lock0.amount == 4);
        assert(lock0.timestamp == t0);
        Debug.print(lock_to_text(lock0));
        assert(hotness_to_duration(lock0.hotness) == Duration.toTime(#MINUTES(20)));

        // Try to unlock till 19 minutes shall fail
        assert(try_repetitive_unlock(lock_scheduler, map, t0, t0 + 19).size() == 0);
        assert(Map.size(map) == 1);

        // Tx1, at t=10s, lock 6 sats
        // -> Lock1 shall be locked for more than 30 minutes but less than 50 minutes
        // -> Lock0 shall now be locked for more than 20 minutes but less than 50 minutes

        let t1 = t0 + Duration.toTime(#MINUTES(10));

        var lock1 = lock_scheduler.new_lock({ map; id = 1; amount = 6; timestamp = t1; from_lock = lock_passthrough; });
        assert(Map.size(map) == 2);

        // Test lock1
        assert(lock1.id == 1);
        assert(lock1.amount == 6);
        assert(lock1.timestamp == t1);
        Debug.print(lock_to_text(lock1));
        assert(hotness_to_duration(lock1.hotness) > Duration.toTime(#MINUTES(30)));
        assert(hotness_to_duration(lock1.hotness) < Duration.toTime(#MINUTES(50)));

        // Test lock0
        lock0 := unwrap_lock(Map.get(map, Map.nhash, 0));
        assert(lock0.id == 0);
        assert(lock0.amount == 4);
        assert(lock0.timestamp == t0);
        Debug.print("Lock 0 time left = " # debug_show(hotness_to_duration(lock0.hotness)));
        assert(hotness_to_duration(lock0.hotness) > Duration.toTime(#MINUTES(20)));
        assert(hotness_to_duration(lock0.hotness) < Duration.toTime(#MINUTES(50)));

        // Try to unlock till the lock0's time_left is over shall fail
        assert(try_repetitive_unlock(lock_scheduler, map, t0, t0 + hotness_to_duration(lock0.hotness)).size() == 0);
        assert(Map.get(map, Map.nhash, 0) != null);
        assert(Map.get(map, Map.nhash, 1) != null);
        assert(Map.size(map) == 2);

        // Try to unlock after the lock0's time_left is over shall succeed
        assert(lock_scheduler.try_unlock({ map; time = t0 + hotness_to_duration(lock0.hotness) + 1; }).size() == 1);
        assert(Map.get(map, Map.nhash, 0) == null);
        assert(Map.get(map, Map.nhash, 1) != null);
        assert(Map.size(map) == 1);

        // Try to unlock after the lock1's time_left is over shall succeed
        assert(lock_scheduler.try_unlock({ map; time = t1 + hotness_to_duration(lock1.hotness) + 1; }).size() == 1);
        assert(Map.get(map, Map.nhash, 0) == null);
        assert(Map.get(map, Map.nhash, 1) == null);
        assert(Map.size(map) == 0);
    });
    
})