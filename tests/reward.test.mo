import Reward "../src/Reward";

import { test; suite; } "mo:test";
import Float "mo:base/Float";

suite("Reward", func(){

    test("Test context factor computation", func(){

        let reward = Reward.contest_logistic_regression({
            amount = 10;
            total_same = 6;
            total_opposit = 9;
        });

        // See https://www.desmos.com/calculator/jq9uvjji2i
        // Somehow on demos, R does not yeild the same result as in the code (is it a precision issue or an error in the math?)
        // This result has been obtained by evaluating y on demos by incrementing b_a from 0 to 10, each time adding 1 to the denominator for y.
        let expected_reward = 0.691352849519 + // y for b_a = 1
                              0.611719411407 + // y for b_a = 2
                              0.535653670834 + // ...
                              0.466267534398 +
                              0.405014206477 +
                              0.35211483737  +
                              0.307048671755 +
                              0.26894142137  +
                              0.236816527979 +
                              0.2097338217;
        
        assert(Float.equalWithin(reward, expected_reward, 1e-9));
    });

});