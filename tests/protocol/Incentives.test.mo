import Incentives "../../src/protocol/votes/Incentives";

import { test; suite; } "mo:test";
import Float "mo:base/Float";

import { verify; Testify; } = "../utils/Testify";

suite("Incentives", func(){

    test("Dissent", func(){
        var dissent = Incentives.compute_dissent({
            initial_addend = 100.0;
            steepness = 1.0;
            choice = #YES;
            amount = 100;
            total_yes = 0;
            total_no = 0;
        });

        verify<Float>(dissent, 1.0, Testify.float.equalEpsilon9);

        dissent := Incentives.compute_dissent({
            initial_addend = 0.0;
            steepness = 1.0;
            choice = #YES;
            amount = 2;
            total_yes = 9999;
            total_no = 10000;
        });

        let without_addend = dissent;

        verify<Float>(dissent, 0.5, Testify.float.equalEpsilon6);

        dissent := Incentives.compute_dissent({
            initial_addend = 100.0;
            steepness = 1.0;
            choice = #YES;
            amount = 2;
            total_yes = 9999;
            total_no = 10000;
        });

        verify<Float>(dissent, without_addend, Testify.float.greaterThan);

        dissent := Incentives.compute_dissent({
            initial_addend = 0.0;
            steepness = 1.0;
            choice = #YES;
            amount = 10000;
            total_yes = 0;
            total_no = 10000;
        });

        verify<Float>(dissent, 0.5, Testify.float.greaterThan);

        dissent := Incentives.compute_dissent({
            initial_addend = 100.0;
            steepness = 1.0;
            choice = #YES;
            amount = 66394;
            total_yes = 25114;
            total_no = 95243;
        });

        verify<Float>(dissent, 0.5, Testify.float.greaterThan);

        dissent := Incentives.compute_dissent({
            initial_addend = 100.0;
            steepness = 1.0;
            choice = #NO;
            amount = 131260;
            total_yes = 194000;
            total_no = 63079;
        });

        verify<Float>(dissent, 0.607, Testify.float.greaterThan);
    });
    
})