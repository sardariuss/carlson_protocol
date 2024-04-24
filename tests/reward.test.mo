import Reward "../src/Reward";

import { test; suite; } "mo:test";
import Float "mo:base/Float";
import Debug "mo:base/Debug";
import Int   "mo:base/Int";

suite("Reward", func(){

    test("Contest factor", func(){

        let total_ayes = 400;
        let total_nays = 100;

        let contest_factor_with = Reward.compute_contest_factor({
            choice = #AYE(500);
            total_ayes;
            total_nays;
        });

        assert(Float.equalWithin(contest_factor_with, 0.15, 1e-9));

        let contest_factor_against = Reward.compute_contest_factor({
            choice = #NAY(300);
            total_ayes;
            total_nays;
        });

        assert(Float.equalWithin(contest_factor_against, 0.65, 1e-9));
    });

//    test("Test compute score", func(){
//
//        let choice_with = #AYE(200);
//        let choice_against = #NAY(200);
//
//        // 1. The trend stays the same (4 ayes for 1 nay)
//        var total_ayes = 2000;
//        var total_nays = 500;
//
//        var score_with = Reward.compute_score({ total_ayes; total_nays; choice = choice_with; });
//        Debug.print("Score with: " # debug_show(score_with));
//        var score_against = Reward.compute_score({ total_ayes; total_nays; choice = choice_against; });
//        Debug.print("Score against: " # debug_show(score_against));
//
//        var reward_with = Int.abs(Float.toInt(contest_factor_with * score_with));
//
//        Debug.print("Trend stayed the same, reward with: " # debug_show(reward_with));
//
//        var reward_against = Int.abs(Float.toInt(contest_factor_against * score_against));
//
//        Debug.print("Trend stayed the same, reward against: " # debug_show(reward_against));
//
//        // 2. The trend is confirmed (10 ayes for 1 nay)
//        total_ayes := 5000;
//        total_nays := 500;
//
//        score_with := Reward.compute_score({ total_ayes; total_nays; choice = choice_with; });
//        Debug.print("Score with: " # debug_show(score_with));
//        score_against := Reward.compute_score({ total_ayes; total_nays; choice = choice_against; });
//        Debug.print("Score against: " # debug_show(score_against));
//
//        reward_with := Int.abs(Float.toInt(contest_factor_with * score_with));
//
//        Debug.print("Trend confirmed, reward with: " # debug_show(reward_with));
//
//        reward_against := Int.abs(Float.toInt(contest_factor_against * score_against));
//
//        Debug.print("Trend confirmed, reward against: " # debug_show(reward_against));
//
//        // 4. If the trend changed a little (1 aye for 1 nay)
//        total_ayes := 1000;
//        total_nays := 1000;
//
//        score_with := Reward.compute_score({ total_ayes; total_nays; choice = choice_with; });
//        score_against := Reward.compute_score({ total_ayes; total_nays; choice = choice_against; });
//
//        reward_with := Int.abs(Float.toInt(contest_factor_with * score_with));
//
//        Debug.print("Trend changed a little, reward with: " # debug_show(reward_with));
//
//        reward_against := Int.abs(Float.toInt(contest_factor_against * score_against));
//
//        Debug.print("Trend changed a little, reward against: " # debug_show(reward_against));
//
//        // 4. If the trend changed drastically
//        total_ayes := 500;
//        total_nays := 5000;
//
//        score_with := Reward.compute_score({ total_ayes; total_nays; choice = choice_with; });
//        score_against := Reward.compute_score({ total_ayes; total_nays; choice = choice_against; });
//
//        reward_with := Int.abs(Float.toInt(contest_factor_with * score_with));
//
//        Debug.print("Trend changed drastically, reward with: " # debug_show(reward_with));
//
//        reward_against := Int.abs(Float.toInt(contest_factor_against * score_against));
//
//        Debug.print("Trend changed drastically, reward against: " # debug_show(reward_against));
//
//    });

});