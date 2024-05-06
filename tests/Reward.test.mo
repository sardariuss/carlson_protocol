import Reward "../src/Reward";

import { test; suite; } "mo:test";

import { verify; Testify; } = "utils/Testify";

suite("Reward", func(){

    test("Compute score", func(){

        // 1. The total number of ayes and nays is the same
        
        // Verify the score is 0.5 whatever the choice is
        var score = Reward.compute_score({ choice = #AYE(1); total_ayes = 500; total_nays = 500; });
        verify(score, 0.5, Testify.float.equalEpsilon9);
        score := Reward.compute_score({ choice = #NAY(1); total_ayes = 500; total_nays = 500; });
        verify(score, 0.5, Testify.float.equalEpsilon9);
        
        // 2. The total number of ayes is 3 times the total number of nays
        
        // Verify the score is greater than 0.75 when voting AYE
        score := Reward.compute_score({ choice = #AYE(1); total_ayes = 300; total_nays = 100; });
        verify(score, 0.75, Testify.float.greaterThan);
        
        // Verify the score is less than 0.25 when voting NAY
        score := Reward.compute_score({ choice = #NAY(1); total_ayes = 300; total_nays = 100; });
        verify(score, 0.25, Testify.float.lessThan);
    });

    test("Compute contest", func(){

        let total_ayes : Float = 200;
        let total_nays : Float = 100;

        // 1. Test contest computation when voting 200 coins with the majority

        // For the first coin alone, the contest shall be around 100/300 = 0.333
        var contest = Reward.compute_contest({ choice = #AYE(1); total_ayes; total_nays; });
        verify(contest, 0.333, Testify.float.equalEpsilon3);

        // For 200 coins, the contest per coin shall be less 0.333, but more than 0.2
        contest := Reward.compute_contest({ choice = #AYE(200); total_ayes; total_nays; });
        verify(contest, 0.333, Testify.float.lessThan);
        verify(contest, 0.2, Testify.float.greaterThan);
        
        // For the last coin alone, the contest shall be around 100/500 = 0.2
        contest := Reward.compute_contest({ choice = #AYE(1); total_ayes = total_ayes + 199; total_nays; });
        verify(contest, 0.2, Testify.float.equalEpsilon3);

        // 2. Test contest computation when voting 100 coins with the minority

        // For the first coin alone, the contest shall be around 200/300 = 0.666
        contest := Reward.compute_contest({ choice = #NAY(1); total_ayes; total_nays; });
        verify(contest, 0.666, Testify.float.equalEpsilon3);

        // For the 100 coins, the contest per coin shall be less 0.666, but more than 0.5
        contest := Reward.compute_contest({ choice = #NAY(100); total_ayes; total_nays; });
        verify(contest, 0.666, Testify.float.lessThan);
        verify(contest, 0.5, Testify.float.greaterThan);

        // For the last coin alone, the contest shall be around 200/400 = 0.5
        contest := Reward.compute_contest({ choice = #NAY(1); total_ayes; total_nays = total_nays + 99; });
        verify(contest, 0.5, Testify.float.equalEpsilon3);
    });

});