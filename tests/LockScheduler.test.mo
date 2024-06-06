import Duration         "../src/Duration";
import Decay            "../src/Decay";
import LockScheduler    "../src/locks/LockScheduler";
import HotMap           "../src/locks/HotMap";
import Types            "../src/Types";

import { verify; testify; } = "utils/Testify";

import { test; suite; } "mo:test";
import Time             "mo:base/Time";
import Int              "mo:base/Int";
import Debug            "mo:base/Debug";
import Float            "mo:base/Float";
import Buffer           "mo:base/Buffer";
import Iter             "mo:base/Iter";
import Text             "mo:base/Text";

import Map              "mo:map/Map";

suite("LockScheduler", func(){

    type Time = Time.Time;
    type Duration = Types.Duration;
    type Lock = {
        amount: Nat;
        hotness: Float;
    };
    type LockScheduler = LockScheduler.LockScheduler<Lock>;

    // For the test, every "satoshi" of hotness is equivalent to 5 minutes of lock duration
    func hotness_to_duration(hotness: Float) : Nat {
        Int.abs(Float.toInt(hotness * Float.fromInt(Duration.toTime(#MINUTES(5)))));
    };

    func duration_to_hotness(duration: Duration) : Float {
        Float.fromInt(Duration.toTime(duration)) / Float.fromInt(Duration.toTime(#MINUTES(5)));
    };

    func lock_passthrough(lock: Lock) : Lock { lock; };
    func update_lock(_: Lock, lock: Lock) : Lock { lock; };

    func try_repetitive_unlock(lock_scheduler: LockScheduler, map: Map.Map<Nat, Lock>, time_now: Time, target_time: Time) : [Lock] {
        let buffer = Buffer.Buffer<Lock>(0);
        // Arbitrarily take 10 timestamps between time_now and target_time
        for (i in Iter.range(0, 9)) {
            let time = time_now + (target_time - time_now) * i / 10;
            buffer.append(lock_scheduler.try_unlock({ map; time; }));
        };
        Buffer.toArray(buffer);
    };

    func unwrap_lock(lock: ?Lock) : Lock {
        switch(lock) {
            case (?l) { l; };
            case (null) { Debug.trap("Failed to unwrap lock"); };
        };
    };

    let equal_lock = testify<Lock>(
        func(lock: Lock) : Text {
            let buffer = Buffer.Buffer<Text>(8);
            buffer.add("{");
            buffer.add("id = " # debug_show(lock.id));
            buffer.add("amount = " # debug_show(lock.amount));
            buffer.add("timestamp = " # debug_show(lock.timestamp));
            buffer.add("decay = " # debug_show(lock.decay));
            buffer.add("hotness = " # debug_show(lock.hotness));
            buffer.add("duration = " # debug_show(hotness_to_duration(lock.hotness)) # " ns");
            buffer.add("}");
            Text.join("\n", buffer.vals());
        },
        func(l1: Lock, l2: Lock) : Bool {
            l1.id == l2.id and l1.amount == l2.amount and l1.timestamp == l2.timestamp and l1.decay == l2.decay and l1.hotness == l2.hotness;
        }
    );

    let equal_lock_state = testify<Types.LockState>(
        func (state: Types.LockState) : Text { debug_show(state); },
        func (s1: Types.LockState, s2: Types.LockState) : Bool { s1 == s2; }
    );

    let equal_duration = testify<Duration>(
        func (d: Duration) : Text { Int.toText(Duration.toTime(d)) # " ns"; },
        func (d1: Duration, d2: Duration) : Bool { Duration.toTime(d1) == Duration.toTime(d2); }
    );

    let inferior_duration = testify<Duration>(
        func (d: Duration) : Text { Int.toText(Duration.toTime(d)) # " ns"; },
        func (d1: Duration, d2: Duration) : Bool { Duration.toTime(d1) < Duration.toTime(d2); }
    );

    let superior_duration = testify<Duration>(
        func (d: Duration) : Text { Int.toText(Duration.toTime(d)) # " ns"; },
        func (d1: Duration, d2: Duration) : Bool { Duration.toTime(d1) > Duration.toTime(d2); }
    );

    test("Two locks", func(){
        let t0 = Time.now();

        let decay_model = Decay.DecayModel({
            time_init = t0;
            half_life = #HOURS(1);
        });
        
        let lock_scheduler = LockScheduler.LockScheduler({
            decay_model;
            get_lock_duration_ns = hotness_to_duration;
            to_lock = lock_passthrough;
            update_lock;
        });

        let map = Map.new<Nat, Lock>();
        assert(Map.size(map) == 0);

        // Tx0, at t=0, lock 4 sats:
        // -> Lock0 shall be locked for 20 minutes
        var lock0 = lock_scheduler.new_lock({ map; id = 0; amount = 4; timestamp = t0; new = lock_passthrough; });
        assert(Map.size(map) == 1);
        verify(#NS(hotness_to_duration(lock0.hotness)), #MINUTES(20), equal_duration);
        verify<Lock>(
            lock0, {
                id = 0;
                amount = 4;
                timestamp = t0;
                decay = decay_model.computeDecay(t0);
                hotness = duration_to_hotness(#MINUTES(20));
                lock_state = #LOCKED;
            },
            equal_lock);

        // Try to unlock till 19 minutes shall fail
        assert(try_repetitive_unlock(lock_scheduler, map, t0, t0 + 19).size() == 0);
        verify(unwrap_lock(Map.get(map, Map.nhash, 0)).lock_state, #LOCKED, equal_lock_state);

        // Tx1, at t=10s, lock 6 sats
        // -> Lock1 shall be locked for more than 30 minutes but less than 50 minutes
        // -> Lock0 shall now be locked for more than 20 minutes but less than 50 minutes
        let t1 = t0 + Duration.toTime(#MINUTES(10));

        var lock1 = lock_scheduler.new_lock({ map; id = 1; amount = 6; timestamp = t1; new = lock_passthrough; });
        assert(Map.size(map) == 2);
        verify(unwrap_lock(Map.get(map, Map.nhash, 0)).lock_state, #LOCKED, equal_lock_state);
        verify(unwrap_lock(Map.get(map, Map.nhash, 1)).lock_state, #LOCKED, equal_lock_state);

        // Test lock1
        verify<Lock>(
            lock1, {
                id = 1;
                amount = 6;
                timestamp = t1;
                decay = decay_model.computeDecay(t1);
                hotness = lock1.hotness;
                lock_state = #LOCKED;
            },
            equal_lock);
        verify(#NS(hotness_to_duration(lock1.hotness)), #MINUTES(30), superior_duration);
        verify(#NS(hotness_to_duration(lock1.hotness)), #MINUTES(50), inferior_duration);

        // Test lock0
        lock0 := unwrap_lock(Map.get(map, Map.nhash, 0));
        verify<Lock>(
            lock0, {
                id = 0;
                amount = 4;
                timestamp = t0;
                decay = decay_model.computeDecay(t0);
                hotness = lock0.hotness;
                lock_state = #LOCKED;
            },
            equal_lock);
        verify(#NS(hotness_to_duration(lock0.hotness)), #MINUTES(20), superior_duration);
        verify(#NS(hotness_to_duration(lock0.hotness)), #MINUTES(50), inferior_duration);

        // Try to unlock till the lock0's time_left is over shall fail
        assert(try_repetitive_unlock(lock_scheduler, map, t0, t0 + hotness_to_duration(lock0.hotness)).size() == 0);
        verify(unwrap_lock(Map.get(map, Map.nhash, 0)).lock_state, #LOCKED, equal_lock_state);
        verify(unwrap_lock(Map.get(map, Map.nhash, 1)).lock_state, #LOCKED, equal_lock_state);

        // Try to unlock after the lock0's time_left is over shall succeed
        assert(lock_scheduler.try_unlock({ map; time = t0 + hotness_to_duration(lock0.hotness) + 1; }).size() == 1);
        verify(unwrap_lock(Map.get(map, Map.nhash, 0)).lock_state, #REFUNDED, equal_lock_state);
        verify(unwrap_lock(Map.get(map, Map.nhash, 1)).lock_state, #LOCKED, equal_lock_state);

        // Try to unlock after the lock1's time_left is over shall succeed
        assert(lock_scheduler.try_unlock({ map; time = t1 + hotness_to_duration(lock1.hotness) + 1; }).size() == 1);
        verify(unwrap_lock(Map.get(map, Map.nhash, 0)).lock_state, #REFUNDED, equal_lock_state);
        verify(unwrap_lock(Map.get(map, Map.nhash, 1)).lock_state, #REFUNDED, equal_lock_state);
    });
    
})