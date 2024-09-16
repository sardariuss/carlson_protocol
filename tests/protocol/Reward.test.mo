import Incentives "../../src/protocol/votes/Incentives";

import { test; suite; } "mo:test";

import { verify; Testify; } = "../utils/Testify";

suite("Reward", func(){

    test("Compute consent", func(){

        // 1. The total number of yes and no is the same
        
        // Verify the consent is 0.5 whatever the choice is
        var consent = Incentives.compute_consent({ choice = #YES(1); total_yes = 500; total_no = 500; });
        verify(consent, 0.5, Testify.float.equalEpsilon9);
        consent := Incentives.compute_consent({ choice = #NO(1); total_yes = 500; total_no = 500; });
        verify(consent, 0.5, Testify.float.equalEpsilon9);
        
        // 2. The total number of yes is 3 times the total number of no
        
        // Verify the consent is greater than 0.75 when voting AYE
        consent := Incentives.compute_consent({ choice = #YES(1); total_yes = 300; total_no = 100; });
        verify(consent, 0.75, Testify.float.greaterThan);
        
        // Verify the consent is less than 0.25 when voting NAY
        consent := Incentives.compute_consent({ choice = #NO(1); total_yes = 300; total_no = 100; });
        verify(consent, 0.25, Testify.float.lessThan);
    });

    test("Compute dissent", func(){

        let total_yes : Float = 200;
        let total_no : Float = 100;

        // 1. Test dissent computation when voting 200 coins with the majority

        // For the first coin alone, the dissent shall be around 100/300 = 0.333
        var dissent = Incentives.compute_dissent({ choice = #YES(1); total_yes; total_no; });
        verify(dissent, 0.333, Testify.float.equalEpsilon3);

        // For 200 coins, the dissent per coin shall be less 0.333, but more than 0.2
        dissent := Incentives.compute_dissent({ choice = #YES(200); total_yes; total_no; });
        verify(dissent, 0.333, Testify.float.lessThan);
        verify(dissent, 0.2, Testify.float.greaterThan);
        
        // For the last coin alone, the dissent shall be around 100/500 = 0.2
        dissent := Incentives.compute_dissent({ choice = #YES(1); total_yes = total_yes + 199; total_no; });
        verify(dissent, 0.2, Testify.float.equalEpsilon3);

        // 2. Test dissent computation when voting 100 coins with the minority

        // For the first coin alone, the dissent shall be around 200/300 = 0.666
        dissent := Incentives.compute_dissent({ choice = #NO(1); total_yes; total_no; });
        verify(dissent, 0.666, Testify.float.equalEpsilon3);

        // For the 100 coins, the dissent per coin shall be less 0.666, but more than 0.5
        dissent := Incentives.compute_dissent({ choice = #NO(100); total_yes; total_no; });
        verify(dissent, 0.666, Testify.float.lessThan);
        verify(dissent, 0.5, Testify.float.greaterThan);

        // For the last coin alone, the dissent shall be around 200/400 = 0.5
        dissent := Incentives.compute_dissent({ choice = #NO(1); total_yes; total_no = total_no + 99; });
        verify(dissent, 0.5, Testify.float.equalEpsilon3);
    });

});