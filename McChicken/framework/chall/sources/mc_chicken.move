module challenge::mc_chicken {
    
    // [*] Import dependencies
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::transfer;

    use std::bcs;

    // [*] Error Codes
    const ERR_INCORRECT_ORDER : u64 = 31337;
    const ERR_ORDER_SERVED: u64 = 31338;
    const ERR_ORDER_NOT_SERVED: u64 = 31339;
 
    // [*] Structs
    struct ChefCapability has key, store { id: UID}
    struct CustomerCapability has key, store { id: UID}

    struct Mayo has store, copy, drop { calories : u16 }
    struct Lettuce has store, copy, drop { calories : u16 }
    struct ChickenSchnitzel has store, copy, drop { calories : u16 }
    struct Cheese has store, copy, drop { calories : u16 }
    struct Bun has store, copy, drop { calories : u16 }

    struct Bag<T: store + drop> has key, store {
        id: UID,
        contents: T
    }

    struct Order has key, store {
        id: UID,
        order: vector<u8>,
        served: bool,
    }

    // [*] Public functions
    public entry fun become_chef ( ctx: &mut TxContext ) {
        transfer::transfer(ChefCapability {
            id: object::new(ctx)
        }, tx_context::sender(ctx));
    }

    public entry fun enter_restaurant ( ctx: &mut TxContext ) {
        transfer::transfer(CustomerCapability {
            id: object::new(ctx)
        }, tx_context::sender(ctx));
    }

    public entry fun place_order ( _customer_cap: &mut CustomerCapability, order: vector<u8>, ctx: &mut TxContext ) {
        transfer::public_share_object(Order {
            id: object::new(ctx),
            order: order,
            served: false,
        });
    }

    public entry fun deliver_order <T: store + drop> ( _chef: &mut ChefCapability, order: &mut Order, contents: T, ctx: &mut TxContext ) {
        assert!( !is_served(order), ERR_ORDER_SERVED);
        assert!( bcs::to_bytes(&contents) == order.order, ERR_INCORRECT_ORDER);

        transfer::public_share_object(Bag<T> {
            id: object::new(ctx),
            contents: contents,
        });

        order.served = true;
    }

    public fun get_mayo ( _chef: &mut ChefCapability ) : Mayo {
        Mayo { calories: 679 }
    }

    public fun get_lettuce ( _chef: &mut ChefCapability ) : Lettuce {
        Lettuce { calories: 14 }
    }

    public fun get_chicken_schnitzel ( _chef: &mut ChefCapability ) : ChickenSchnitzel {
        ChickenSchnitzel { calories: 297 }
    }

    public fun get_cheese ( _chef: &mut ChefCapability ) : Cheese {
        Cheese { calories: 420 }
    }

    public fun get_bun ( _chef: &mut ChefCapability ) : Bun {
        Bun { calories: 120 }
    }

    public fun is_served ( order: &mut Order ) : bool {
        order.served
    }

    public fun assert_is_served ( order: &mut Order ) {
        assert!(order.served, ERR_ORDER_NOT_SERVED);
    }

}
