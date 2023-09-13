use std::env;
use std::fmt;
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
    let chall = "mc_chicken";
    let named_addresses = vec![
        ("challenge".to_string(), NumericalAddress::parse_str("0x1c22b6f1045294ae4a81b82035b53d75b57673ce6439a71f571c4b9c81692577").unwrap()),
        ("solution".to_string(), NumericalAddress::parse_str("0x77352e24339d14034474f9a99fc2146a00d90a18da8981d5b9be3cb12114ca89").unwrap()),
    ];
    
    let precompiled = sui_ctf_framework::get_precompiled(Path::new(&format!(
        "./chall/build/{}/sources/dependencies",
        chall
    )));

    let mut adapter = sui_ctf_framework::initialize(
        named_addresses,
        &precompiled,
        Some(vec!["customer".to_string(), "chef".to_string()]),
    ).await;
    
    let mut solution_data = [0 as u8; 1000]; 
    let _solution_size = stream.read(&mut solution_data).unwrap();


    // Publish Challenge Module
    let mod_bytes: Vec<u8> = std::fs::read(format!(
        "./chall/build/{}/bytecode_modules/{}.mv",
        chall, chall
    )).unwrap();
    let chall_dependencies: Vec<String> = Vec::new();
    let chall_addr = sui_ctf_framework::publish_compiled_module(&mut adapter, mod_bytes, chall_dependencies, Some(String::from("customer"))).await;
    println!("[SERVER] Challenge published at: {:?}", chall_addr);


    // Publish Solution Module
    let mut sol_dependencies: Vec<String> = Vec::new();
    sol_dependencies.push(String::from("challenge"));
    let sol_addr = sui_ctf_framework::publish_compiled_module(&mut adapter, solution_data.to_vec(), sol_dependencies, Some(String::from("chef"))).await;
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
    
    
    // Initialize Customer
    let initialize_args : Vec<SuiValue> = Vec::new();

    let ret_val = sui_ctf_framework::call_function(
        &mut adapter,
        chall_addr,
        "mc_chicken",
        "enter_restaurant",
        initialize_args,
        Some("customer".to_string())
    ).await;
    println!("[SERVER] Return value {:#?}", ret_val);
    println!("");


    // Place Order1
    let mut order_args : Vec<SuiValue> = Vec::new();
    let order_args_1 = SuiValue::Object(FakeID::Enumerated(3, 0), None);
    let recepit1 = Vec::from(
       [MoveValue::U8(0x78),
        MoveValue::U8(0x00),
        MoveValue::U8(0xa7),
        MoveValue::U8(0x02),
        MoveValue::U8(0x0e),
        MoveValue::U8(0x00),
        MoveValue::U8(0x29),
        MoveValue::U8(0x01),
        MoveValue::U8(0xa4),
        MoveValue::U8(0x01),
        MoveValue::U8(0x78),
        MoveValue::U8(0x00)]);
        order_args.push(order_args_1);
        order_args.push(SuiValue::MoveValue(MoveValue::Vector(recepit1)));

    let ret_val = sui_ctf_framework::call_function(
        &mut adapter,
        chall_addr,
        "mc_chicken",
        "place_order",
        order_args,
        Some("customer".to_string())
    ).await;
    println!("[SERVER] Return value {:#?}", ret_val);
    println!("");


    // Place Order2
    let mut order2_args : Vec<SuiValue> = Vec::new();
    let order2_args_1 = SuiValue::Object(FakeID::Enumerated(3, 0), None);
    let receipt2 = Vec::from(
       [MoveValue::U8(0x78),
        MoveValue::U8(0x00),
        MoveValue::U8(0xa4),
        MoveValue::U8(0x01),
        MoveValue::U8(0xa4),
        MoveValue::U8(0x01),
        MoveValue::U8(0x29),
        MoveValue::U8(0x01),
        MoveValue::U8(0xa4),
        MoveValue::U8(0x01),
        MoveValue::U8(0x29),
        MoveValue::U8(0x01),
        MoveValue::U8(0xa4),
        MoveValue::U8(0x01),
        MoveValue::U8(0x29),
        MoveValue::U8(0x01),
        MoveValue::U8(0xa4),
        MoveValue::U8(0x01),
        MoveValue::U8(0xa4),
        MoveValue::U8(0x01),
        MoveValue::U8(0x78),
        MoveValue::U8(0x00)]);
        order2_args.push(order2_args_1);
        order2_args.push(SuiValue::MoveValue(MoveValue::Vector(receipt2)));

    let ret_val = sui_ctf_framework::call_function(
        &mut adapter,
        chall_addr,
        "mc_chicken",
        "place_order",
        order2_args,
        Some("customer".to_string())
    ).await;
    println!("[SERVER] Return value {:#?}", ret_val);
    println!("");


    // Initialize Chef
    let initialize_args : Vec<SuiValue> = Vec::new();

    let ret_val = sui_ctf_framework::call_function(
        &mut adapter,
        chall_addr,
        "mc_chicken",
        "become_chef",
        initialize_args,
        Some("chef".to_string())
    ).await;
    println!("[SERVER] Return value {:#?}", ret_val);
    println!("");


    // Call solve Function
    let mut solve_args: Vec<SuiValue> = Vec::new();
    solve_args.push(SuiValue::Object(FakeID::Enumerated(6, 0), None));
    solve_args.push(SuiValue::Object(FakeID::Enumerated(4, 0), None));
    solve_args.push(SuiValue::Object(FakeID::Enumerated(5, 0), None));

    let ret_val = sui_ctf_framework::call_function(
        &mut adapter,
        sol_addr,
        "mc_chicken_solution",
        "solve",
        solve_args,
        Some("chef".to_string())
    ).await;
    println!("[SERVER] Return value {:#?}", ret_val);
    println!("");

    
    // Check Solution
    let mut o1_args: Vec<SuiValue> = Vec::new();
    let o1_args_1 = SuiValue::Object(FakeID::Enumerated(4, 0), None);
    o1_args.push(o1_args_1);

    let status_order1 = sui_ctf_framework::call_function(
        &mut adapter,
        chall_addr,
        chall,
        "assert_is_served",
        o1_args,
        Some("customer".to_string()),
    ).await;
    println!("[SERVER] Return value {:#?}", status_order1);
    println!("");

    
    // Validate Solution
    match status_order1 {
        Ok(()) => {
            let mut o2_args: Vec<SuiValue> = Vec::new();
            let o2_args_1 = SuiValue::Object(FakeID::Enumerated(5, 0), None);
            o2_args.push(o2_args_1);

            let status_order2 = sui_ctf_framework::call_function(
                &mut adapter,
                chall_addr,
                chall,
                "assert_is_served",
                o2_args,
                Some("customer".to_string()),
            ).await;
            println!("[SERVER] Return value {:#?}", status_order2);
            println!("");

            match status_order2 {
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
            }
        }
        Err(_error) => {
            println!("[SERVER] Invalid Solution!");
            println!("");
            stream.write("[SERVER] Invalid Solution!".as_bytes()).unwrap();
        }
    }

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
