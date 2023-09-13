module challenge::coin_flip {
    
    // [*] Import dependencies
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;

    // [*] Error Codes
    const ERR_GAME_STARTED : u64 = 31337;
    const ERR_NO_STAKE : u64 = 31338;
    const ERR_GAME_SOLVED : u64 = 31339;
    const ERR_WRONG_PLAYER : u64 = 31340;
    const ERR_NOT_SOLVED : u64 = 31341;
    const ERR_INVALID_FEE : u64 = 31342;

    // [*] Constants
    const RANDOM_ADDRESS: address = @0xcafebabe;
 
    // [*] Structs
    struct Random has drop, store, copy {
        seed: u64
    }

    struct Game has key, store {
        id: UID,
        stake: Coin<SUI>,
        combo: u8,
        fee: u8,
        player: address,
        author: address,
        randomness: Random,
        solved : bool,
    }

    // [*] Public functions
    public entry fun create_game( stake: Coin<SUI>, randomness: u64, fee: u8, ctx: &mut TxContext ) {
        let game = Game {
            id: object::new(ctx),
            stake: stake,
            combo: 0,
            fee: fee,
            player: RANDOM_ADDRESS,
            author: tx_context::sender(ctx),
            randomness: new_generator(randomness),
            solved: false,
        };
        transfer::public_share_object(game);
    }

    public entry fun start_game( game: &mut Game, fee: Coin<SUI>, ctx: &mut TxContext ) {
        assert!(game.player == RANDOM_ADDRESS, ERR_GAME_STARTED);
        assert!(coin::value(&game.stake) > 0, ERR_NO_STAKE);
        assert!(game.solved == false, ERR_GAME_SOLVED);
        assert!(coin::value(&fee) == (game.fee as u64), ERR_INVALID_FEE);

        game.player = tx_context::sender(ctx);
        coin::join(&mut game.stake, fee);
    }

    public entry fun play_game( game: &mut Game, coin_guess: u8, fee: Coin<SUI>, ctx: &mut TxContext ) {        
        assert!(game.player == tx_context::sender(ctx), ERR_WRONG_PLAYER);
        assert!(game.solved == false, 0);
        assert!((coin::value(&fee) as u8) == game.fee, ERR_INVALID_FEE);

        coin::join(&mut game.stake, fee);

        let coin_flip : u8 = ((generate_rand(&mut game.randomness) % 2) as u8);
        if (coin_flip == coin_guess) {
            game.combo = game.combo + 1;
        } else {
            game.combo = 0;
        };

        if (game.combo == 12) {
            game.solved = true;
        }
    }

    public entry fun is_solved(game: &mut Game) {
        assert!(game.solved == true, ERR_NOT_SOLVED);
    }

    public fun get_combos(game: &mut Game) : u8 {
        game.combo
    }
 
    // [*] Local functions
    fun new_generator(seed: u64): Random {
        Random { seed }
    }

    fun generate_rand(r: &mut Random): u64 {
        r.seed = ((((9223372036854775783u128 * ((r.seed as u128)) + 999983) >> 1) & 0x0000000000000000ffffffffffffffff) as u64);
        r.seed
    }

}
