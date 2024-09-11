import Migration010 "./00-01-00-initial/Types";

module {
    // do not forget to change current migration when you add a new one
    // you should use this field to import types from you current migration anywhere in your project
    // instead of importing it from migration folder itself
    public let Current = Migration010;
    
    public type Args = Current.Args;

    public type State = {
        #v0_1_0: Migration010.State;
        // do not forget to add your new migration data types here
    };
};