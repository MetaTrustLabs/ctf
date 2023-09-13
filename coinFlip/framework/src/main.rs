use std::env;
use std::fmt;
use rand::Rng;
use anyhow::Result;
use std::mem::drop;
use std::path::Path;
use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};

use tokio::main;

use sui_ctf_framework::NumericalAddress;
use sui_transactional_test_runner::args::SuiValue;
use sui_transactional_test_runner::test_adapter::FakeID;

use move_core_types::value::MoveValue;

async fn handle_client(mut stream: TcpStream) -> Result<()> {

    // Initialize SuiTestAdapter
    let chall = "coin_flip";
    let named_addresses = vec![
        ("challenge".to_string(), NumericalAddress::parse_str("0x16b4ed7e0343b9549e242d26ae44c175bb3468f83032f50c727f1a1412b6aa33").unwrap()),
        ("solution".to_string(), NumericalAddress::parse_str("0xc4f1f2287aa7a5b5e26b4bf0595b1b1a1651975d6ec0c15cc45c8a6ef1317560").unwrap()),
    ];
    
    let precompiled = sui_ctf_framework::get_precompiled(Path::new(&format!(
        "./chall/build/{}/sources/dependencies",
        chall
    )));

    let mut adapter = sui_ctf_framework::initialize(
        named_addresses,
        &precompiled,
        Some(vec!["challenger".to_string(), "solver".to_string()]),
    ).await;
    
    let mut solution_data = [0 as u8; 1000]; 
    let _solution_size = stream.read(&mut solution_data).unwrap();


    // Publish Challenge Module
    let mod_bytes: Vec<u8> = std::fs::read(format!(
        "./chall/build/{}/bytecode_modules/{}.mv",
        chall, chall
    )).unwrap();
    let chall_dependencies: Vec<String> = Vec::new();
    let chall_addr = sui_ctf_framework::publish_compiled_module(&mut adapter, mod_bytes, chall_dependencies, Some(String::from("challenger"))).await;
    println!("[SERVER] Challenge published at: {:?}", chall_addr);


    // Publish Solution Module
    let mut sol_dependencies: Vec<String> = Vec::new();
    sol_dependencies.push(String::from("challenge"));
    let sol_addr = sui_ctf_framework::publish_compiled_module(&mut adapter, solution_data.to_vec(), sol_dependencies, Some(String::from("solver"))).await;
    println!("[SERVER] Solution published at: {:?}", sol_addr);

    let mut output = String::new();
    fmt::write(
        &mut output,
        format_args!(
            "[SERVER] Challenge published at {}. Solution published at {}",
            chall_addr.to_string().as_str(),
            sol_addr.to_string().as_str()
        ),
    ).unwrap();
    stream.write(output.as_bytes()).unwrap();


    // Create Game
    let ret_coin = sui_ctf_framework::fund_account(&mut adapter, "challenger".to_string(), 1337, "challenger".to_string()).await;
    println!("[SERVER] Coin Return: {:#?}", ret_coin);
    
    let mut create_args : Vec<SuiValue> = Vec::new();

    let mut rng = rand::thread_rng();
    let random_byte: u8 = rng.gen();
    println!("Random Seed: {}", random_byte);

    let create_args_1 = SuiValue::Object(FakeID::Enumerated(3, 0), None);
    let create_args_2 = SuiValue::MoveValue(MoveValue::U64(random_byte as u64)); // 0xab
    let create_args_3 = SuiValue::MoveValue(MoveValue::U8(10));

    create_args.push(create_args_1);
    create_args.push(create_args_2);
    create_args.push(create_args_3);

    let ret_val = sui_ctf_framework::call_function(
        &mut adapter,
        chall_addr,
        "coin_flip",
        "create_game",
        create_args,
        Some("challenger".to_string())
    ).await;
    println!("[SERVER] Return value {:#?}", ret_val);
    println!("");


    // Call solve Function
    let ret_coin_solver = sui_ctf_framework::fund_account(&mut adapter, "solver".to_string(), 130, "solver".to_string()).await;
    println!("[SERVER] Coin2 Return: {:#?}", ret_coin_solver);

    let mut solve_args: Vec<SuiValue> = Vec::new();
    let solve_args_1 = SuiValue::Object(FakeID::Enumerated(4, 0), None);
    let solve_args_2 = SuiValue::Object(FakeID::Enumerated(5, 0), None);
    solve_args.push(solve_args_1);
    solve_args.push(solve_args_2);

    let ret_val = sui_ctf_framework::call_function(
        &mut adapter,
        sol_addr,
        "coin_flip_solution",
        "solve",
        solve_args,
        Some("solver".to_string())
    ).await;
    println!("[SERVER] Return value {:#?}", ret_val);
    println!("");

    
    // Check Solution
    let mut sol_args: Vec<SuiValue> = Vec::new();
    let sol_args_1 = SuiValue::Object(FakeID::Enumerated(4, 0), None);
    sol_args.push(sol_args_1);

    let sol_ret = sui_ctf_framework::call_function(
        &mut adapter,
        chall_addr,
        chall,
        "is_solved",
        sol_args,
        Some("challenger".to_string()),
    ).await;
    println!("[SERVER] Return value {:#?}", sol_ret);
    println!("");


    // Validate Solution
    match sol_ret {
        Ok(()) => {
            println!("[SERVER] Correct Solution!");
            println!("");
            if let Ok(flag) = env::var("FLAG") {
                let message = format!("[SERVER] Congrats, flag: {}", flag);
                stream.write(message.as_bytes()).unwrap();
            } else {
                stream.write("[SERVER] Flag not found, please contact admin".as_bytes()).unwrap();
            }
        }
        Err(_error) => {
            println!("[SERVER] Invalid Solution!");
            println!("");
            stream.write("[SERVER] Invalid Solution!".as_bytes()).unwrap();
        }
    };

    Ok(())
}

#[main]
async fn main() -> Result<()> {

    // Create Socket - Port 31337
    let listener = TcpListener::bind("0.0.0.0:31337")?;
    println!("[SERVER] Starting server at port 31337!");

    let local = tokio::task::LocalSet::new();

    // Wait For Incoming Solution
    for stream in listener.incoming() {
        match stream {
            Ok(stream) => {
                println!("[SERVER] New connection: {}", stream.peer_addr()?);
                    let result = local.run_until( async move {
                        tokio::task::spawn_local( async {
                            handle_client(stream).await.unwrap();
                        }).await.unwrap();
                    }).await;
                    println!("[SERVER] Result: {:?}", result);
            }
            Err(e) => {
                println!("[SERVER] Error: {}", e);
            }
        }        
    }

    // Close Socket Server
    drop(listener);
    Ok(())
}
