import Subaccount "Subaccount";

module {

    public type SubaccountRegister = {
        var deposit_index: Nat;
    };

    public class SubaccountIndexer(register: SubaccountRegister){

        public func new_deposit_subaccount(): Blob {
            let id = register.deposit_index;
            register.deposit_index := register.deposit_index + 1;
            Subaccount.from_subaccount_type(#BALLOT_DEPOSITS{ id });
        };

    };
 
};