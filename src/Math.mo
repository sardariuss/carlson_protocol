import Float "mo:base/Float";
import Iter "mo:base/Iter";

module {

    public func logistic_regression({
        x: Float;
        mu: Float;
        sigma: Float;
    }) : Float {
        1 / (1 + Float.exp(-((x - mu) / sigma)));
    };
    
}