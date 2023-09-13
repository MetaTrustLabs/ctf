module challenge::friendly_fire {
    
    // [*] Import dependencies
    use std::vector;
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::string::{Self, String};

    // [*] Error Codes
    const ERR_INVALID_CODE : u64 = 31337;
 
    // [*] Structs
    struct Status has key, store {
        id : UID,
        solved : bool,
    }

    // [*] Module initializer
    fun init(ctx: &mut TxContext) {
        transfer::public_share_object(Status {
            id: object::new(ctx),
            solved: false
        });
    }

    // [*] Public functions
    public(friend) fun get_flag(status: &mut Status) {
        status.solved = true;
    }

    public entry fun is_owner(status: &mut Status) {
        assert!(status.solved == true, 0);
    }
    
    public entry fun prestige(status: &mut Status, ctxSender: String, _ctx: &mut TxContext) {
        // let digest: &vector<u8> = tx_context::digest(_ctx);
        assert!(ctxSender == std::string::utf8(b"0x31337690420"), ERR_INVALID_CODE) ;
        get_flag(status);
    }

}
