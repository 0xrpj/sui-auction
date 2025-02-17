/// Module: auction
module auction::auction;

use auction::admin::{AdminCap};
use sui::vec_set::{Self, VecSet};
use sui::vec_map::{Self, VecMap};
use sui::clock::{Self, Clock}; 
use sui::coin::{Coin};
use sui::sui::{SUI};
use sui::event;

// === ERRORS ===

#[error]
const EAlreadyStarted: vector<u8> = b"Auction has already started";
#[error]
const EAlreadyEnded: vector<u8> = b"Auction has already ended";
#[error]
const ENotStarted: vector<u8> = b"Auction has not started";
#[error]
const EAlreadySelected: vector<u8> = b"Bidder already selected";
#[error]
const ENotSelected: vector<u8> = b"Bidder not selected";
#[error]
const EInvalidKeys:vector<u8> = b"Invalid number of keys";
#[error]
const EInvalidAmountSent:vector<u8> = b"Invalid amount sent";

public struct UserBid has key {
    id: UID,
    bidder: address,
    recipient: address,
    offer_price: u64,
    keys_requested: u64,
}

public struct AuctionDetails has key {
    id: UID,
    base_price: u64,
    start_time: u64,
    end_time: u64,
    total_keys: u64,
    has_started: bool,
    has_ended: bool 
}

public struct Vault has key {
    id: UID,
    bids: VecMap<address, Coin<SUI>>,
    selected_bidders: VecSet<address>,
}

public struct BidPlacedEvent has copy, drop {
    recipient: address,
    bidder: address,
    offer_price: u64,
    keys_requested: u64,
}

public struct AuctionEndedEvent has copy, drop {
    auction_id: ID,
}

public struct AuctionStartedEvent has copy, drop {
    auction_id: ID,
    base_price: u64,
    start_time: u64,
    end_time: u64,
    total_keys: u64,
    has_started: bool,
}

fun init(
    ctx: &mut TxContext,
){
    let key_auction = AuctionDetails{
        id: object::new(ctx),
        base_price: 0,
        start_time: 0,
        end_time: 0,
        total_keys: 0,
        has_started: false,
        has_ended: false,
    };
    transfer::share_object(key_auction)
}

public fun start_auction(    
     _: &AdminCap,
    key_auction: &mut AuctionDetails,    
    base_price: u64,
    total_keys: u64,    
    clock: &Clock,
    ctx: &mut TxContext,
){
    assert!(key_auction.has_started == false, EAlreadyStarted);

    key_auction.base_price = base_price;
    key_auction.start_time = clock::timestamp_ms(clock);
    key_auction.end_time = clock::timestamp_ms(clock) + 1296000000u64; // 15 days
    key_auction.total_keys = total_keys;
    key_auction.has_started = true;

    let vault = Vault {
        id: object::new(ctx),
        bids: vec_map::empty(),
        selected_bidders: vec_set::empty(),
    };

    event::emit(AuctionStartedEvent{
        auction_id: object::uid_to_inner(&key_auction.id),
        base_price: key_auction.base_price,
        start_time: key_auction.start_time,
        end_time: key_auction.end_time,
        total_keys: key_auction.total_keys,
        has_started: key_auction.has_started,
    });

    transfer::share_object(vault);
}

public fun end_auction(    
     _: &AdminCap,
    key_auction: &mut AuctionDetails,    
){
    assert!(key_auction.has_ended == false, EAlreadyEnded);
    key_auction.has_ended = true;

    event::emit(AuctionEndedEvent{
        auction_id: object::uid_to_inner(&key_auction.id),
    });
}

public fun bid(    
    keys_requested: u64,
    recipient: address,
    key_auction: &AuctionDetails,    
    vault: &mut Vault,
    payment: Coin<SUI>,
    ctx: &mut TxContext,
){
    assert!(key_auction.has_started == true, ENotStarted);
    assert!(key_auction.has_ended == false, EAlreadyEnded);
    assert!(keys_requested != 0, EInvalidKeys);

    let offer_price = payment.value(); 
    assert!((offer_price/keys_requested)>=key_auction.base_price, EInvalidAmountSent);

    let bidder = ctx.sender();

    let bid = UserBid {
        id: object::new(ctx),
        recipient,
        bidder,
        offer_price,
        keys_requested,
    };

    vault.bids.insert(bidder, payment);

    event::emit(BidPlacedEvent{
        recipient,
        bidder,
        offer_price,
        keys_requested
    });

    transfer::transfer(bid, bidder);
}

public fun select_bidder(
    _: &AdminCap,
    vault: &mut Vault,
    bidder: address,
) {
    assert!(!vault.selected_bidders.contains(&bidder), EAlreadySelected);
    vault.selected_bidders.insert(bidder);
}

public fun refund(
    _: &AdminCap,
    vault: &mut Vault,
    bidder: address,
) {
    assert!(!vault.selected_bidders.contains(&bidder), EAlreadySelected);
    let (_, coin) = vault.bids.remove(&bidder);
    transfer::public_transfer(coin, bidder);
}

public fun withdraw_selected_funds(
    _: &AdminCap,
    vault: &mut Vault,
    admin: address,
    bidder: address,
) {
    assert!(vault.selected_bidders.contains(&bidder), ENotSelected);
    let (_, coin) = vault.bids.remove(&bidder);
    transfer::public_transfer(coin, admin);
}