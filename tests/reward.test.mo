import Reward "../src/backend/Reward";

import { test; suite; } "mo:test";
import Float "mo:base/Float";
import Debug "mo:base/Debug";
import Int   "mo:base/Int";

suite("Reward", func(){

    test("Test contest factor computation", func(){

        var reward = Reward.linear_contest({
            amount = 100;
            total_same = 0;
            total_opposit = 0;
        });

        assert(Float.equalWithin(reward, 50, 1e-9));

        reward := Reward.linear_contest({
            amount = 10;
            total_same = 6;
            total_opposit = 9;
        });

        let expected_reward = 0.58064516129  + // y for b_a = 1
                              0.545454545455 + // y for b_a = 2
                              0.514285714286 + // ...
                              0.486486486486 +
                              0.461538461538 +
                              0.439024390244 +
                              0.418604651163 +
                              0.4            +
                              0.382978723404 +
                              0.367346938776;
        
        assert(Float.equalWithin(reward, expected_reward, 1e-9));
    });

    test("Test max reward", func(){

        var total_ayes = 400;
        var total_nays = 100;
        let choice_with = #AYE(200);
        let choice_against = #NAY(200);

        let max_reward_with = Reward.compute_max_reward({
            choice = choice_with;
            total_ayes;
            total_nays;
        });

        Debug.print("Max reward with trend: " # debug_show(max_reward_with));

        let max_reward_against = Reward.compute_max_reward({
            choice = choice_against;
            total_ayes;
            total_nays;
        });

        Debug.print("Max reward against trend: " # debug_show(max_reward_against));

        // 1. The trend stays the same (4 ayes for 1 nay)
        total_ayes := 2000;
        total_nays := 500;

        var score_with = Reward.compute_score({ total_ayes; total_nays; choice = choice_with; });
        Debug.print("Score with: " # debug_show(score_with));
        var score_against = Reward.compute_score({ total_ayes; total_nays; choice = choice_against; });
        Debug.print("Score against: " # debug_show(score_against));

        var reward_with = Int.abs(Float.toInt(max_reward_with * score_with));

        Debug.print("Trend stayed the same, reward with: " # debug_show(reward_with));

        var reward_against = Int.abs(Float.toInt(max_reward_against * score_against));

        Debug.print("Trend stayed the same, reward against: " # debug_show(reward_against));

        // 2. The trend is confirmed (10 ayes for 1 nay)
        total_ayes := 5000;
        total_nays := 500;

        score_with := Reward.compute_score({ total_ayes; total_nays; choice = choice_with; });
        Debug.print("Score with: " # debug_show(score_with));
        score_against := Reward.compute_score({ total_ayes; total_nays; choice = choice_against; });
        Debug.print("Score against: " # debug_show(score_against));

        reward_with := Int.abs(Float.toInt(max_reward_with * score_with));

        Debug.print("Trend confirmed, reward with: " # debug_show(reward_with));

        reward_against := Int.abs(Float.toInt(max_reward_against * score_against));

        Debug.print("Trend confirmed, reward against: " # debug_show(reward_against));

        // 4. If the trend changed a little (1 aye for 1 nay)
        total_ayes := 1000;
        total_nays := 1000;

        score_with := Reward.compute_score({ total_ayes; total_nays; choice = choice_with; });
        score_against := Reward.compute_score({ total_ayes; total_nays; choice = choice_against; });

        reward_with := Int.abs(Float.toInt(max_reward_with * score_with));

        Debug.print("Trend changed a little, reward with: " # debug_show(reward_with));

        reward_against := Int.abs(Float.toInt(max_reward_against * score_against));

        Debug.print("Trend changed a little, reward against: " # debug_show(reward_against));

        // 4. If the trend changed drastically
        total_ayes := 500;
        total_nays := 5000;

        score_with := Reward.compute_score({ total_ayes; total_nays; choice = choice_with; });
        score_against := Reward.compute_score({ total_ayes; total_nays; choice = choice_against; });

        reward_with := Int.abs(Float.toInt(max_reward_with * score_with));

        Debug.print("Trend changed drastically, reward with: " # debug_show(reward_with));

        reward_against := Int.abs(Float.toInt(max_reward_against * score_against));

        Debug.print("Trend changed drastically, reward against: " # debug_show(reward_against));

    });

});