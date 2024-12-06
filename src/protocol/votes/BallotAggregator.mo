import Types              "../Types";

module {

    type Time = Int;

    type UpdateAggregate<A, B>      = Types.UpdateAggregate<A, B>;
    type ComputeDissent<A, B>       = Types.ComputeDissent<A, B>;
    type ComputeConsent<A, B>       = Types.ComputeConsent<A, B>;
    type BallotAggregatorOutcome<A> = Types.BallotAggregatorOutcome<A>;
   
    public class BallotAggregator<A, B>({
        update_aggregate: UpdateAggregate<A, B>;
        compute_dissent: ComputeDissent<A, B>;
        compute_consent: ComputeConsent<A, B>;
    }){

        public func compute_outcome({
            aggregate: A;
            choice: B;
            amount: Nat;
            time: Time;
        }) : BallotAggregatorOutcome<A> {

            // Compute the dissent before updating the aggregate
            let dissent = compute_dissent({ aggregate; choice; amount; time; });
            
            // Update the aggregate before computing the consent
            let update = update_aggregate({ aggregate; choice; amount; time; });

            // Compute the consent
            let consent = compute_consent({ aggregate = update; choice; time; });

            {         
                aggregate = { update };
                ballot = { dissent; consent };
            };
        };

        public func get_consent({
            aggregate: A;
            choice: B;
            time: Time;
        }) : Float {
            compute_consent({ aggregate; choice; time; });
        };

    };

};
