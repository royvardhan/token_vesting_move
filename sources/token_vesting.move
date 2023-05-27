module my_addrx::TokenVesting
{   
    use std::vector;
    use std::signer;
    use aptos_framework::account;
    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_framework::managed_coin;
    use aptos_framework::coin;
    use aptos_std::type_info;

    // Storing Information of a Vesting Schedule
    struct VestingSchedule has store, drop {
        sender: address,
        receiver: address,
        coin_type: address,
        release_times: vector<u64>,
        release_amounts: vector<u64>,
        total_amount: u64,
        resource_cap: account::SignerCapability,
        released_amount: u64,
        active: bool
    }

    // Storing all the Vesting Schedules of a Sender
    // The key is the address of the receiver
    struct Schedules has key {
        scheduleMap: SimpleMap<address, VestingSchedule>
    }

    const ENO_SENDER_IS_RECEIVER: u64 = 0;
    const ENO_INVALID_RELEASE_TIMES: u64 = 1;
    const ENO_INVALID_AMOUNT_TO_RELEASE: u64 = 2;
    const ENO_SENDER_MISMATCH :u64 = 3;
    const ENO_RECEIVER_MISMATCH: u64 = 4;
    const ENO_SCHEDULE_ACTIVE: u64 = 5;

    fun assert_release_times_in_future(release_times: &vector<u64>, timestamp: u64) {
        let length_of_schedule = vector::length(release_times);
        let i = 0;
        while (i < length_of_schedule) {
            assert!(timestamp < *vector::borrow(release_times, i), 1);
            i = i + 1;
        };
    }

    fun assert_sender_is_not_receiver(sender: address, receiver: address) {
        assert!(sender != receiver, 0);
    }

    fun assert_sender_receiver_data(sender: address, receiver: address, schedule: &VestingSchedule) {
        assert!(sender == schedule.sender, 3);
        assert!(receiver == schedule.receiver, 4);
    }

    fun calculate_claim_amount(schedule: &VestingSchedule, timestamp: u64) : u64 {
        let len_of_schdule = vector::length(&schedule.release_amounts);
        let amount_to_release = 0;
        let i = 0;
        while(i < len_of_schdule) {
            let tmp_amount = *vector::borrow(&schedule.release_amounts, i);
            let tmp_times = *vector::borrow(&schedule.release_times, i);
            if (timestamp >= tmp_times) {
                amount_to_release = amount_to_release + tmp_amount;
            };
                i = i+1;
            };
        amount_to_release = amount_to_release -  schedule.released_amount;
        amount_to_release
    }

    // A helper function that returns the address of CoinType.
    fun coin_address<CoinType>(): address {
        let type_info = type_info::type_of<CoinType>();
        type_info::account_address(&type_info)
    }


    // Create a Vesting Schedule
    // The sender is the owner of the schedule
    // Mapping the receiver to the schedule
    public entry fun create_schedule<CoinType>
    (
    sender: &signer, 
    receiver: address, 
    release_amounts: vector<u64>, 
    release_times: vector<u64>,
    total_amount: u64,
    seeds: vector<u8>
    ) acquires Schedules
    {   
        let now = aptos_framework::timestamp::now_seconds();
        let sender_addr = signer::address_of(sender);
        assert_release_times_in_future(&release_times, now);
        assert_sender_is_not_receiver(sender_addr, receiver);
        let (vesting, vesting_cap) = account::create_resource_account(sender, seeds);
        let vesting_signer_from_cap = account::create_signer_with_capability(&vesting_cap);
        let vesting_resource_addr = signer::address_of(&vesting);
        let schedule = VestingSchedule {
            sender: sender_addr,
            receiver: receiver,
            coin_type: coin_address<CoinType>(),
            release_times: release_times,
            release_amounts: release_amounts,
            total_amount: total_amount,
            resource_cap: vesting_cap,
            released_amount: 0,
            active: false
        };
        if(!exists<Schedules>(sender_addr)) {
            move_to(sender, Schedules {scheduleMap: simple_map::create()})
        };
        let schedule_map = borrow_global_mut<Schedules>(sender_addr);
        simple_map::add(&mut schedule_map.scheduleMap, receiver, schedule);
        managed_coin::register<CoinType>(&vesting_signer_from_cap);
        coin::transfer<CoinType>(sender, vesting_resource_addr, total_amount);
    }

    // Accept a Vesting Schedule
    // The receiver is the signer and accept the schedule from the sender
    // Set the schedule to active
    public entry fun accept_schedule<CoinType>
    (
    receiver: &signer,
    sender: address,
    ) acquires Schedules
    {
        let receiver_addr = signer::address_of(receiver);
        assert_sender_is_not_receiver(sender, receiver_addr);
        assert!(exists<Schedules>(sender), 3);
        let schedules = borrow_global_mut<Schedules>(sender);
        assert!(simple_map::contains_key(&schedules.scheduleMap, &receiver_addr), 4);
        let schedule = simple_map::borrow_mut(&mut schedules.scheduleMap, &receiver_addr);
        assert_sender_receiver_data(sender, receiver_addr, schedule);
        assert!(schedule.active == false, 5);
        schedule.active = true;
    }

    // Claim the unlocked fund
    // The receiver is the signer and claim the unlocked fund from the sender
    // The amount to claim is calculated by the current timestamp
    // Can only be claimed when the schedule is active
    public entry fun claim_unlocked_fund<CoinType>
    (
    receiver: &signer, 
    sender:address, 
    ) 
    acquires Schedules
    {   
        let receiver_addr = signer::address_of(receiver);
        assert_sender_is_not_receiver(sender, receiver_addr);
        assert!(exists<Schedules>(sender), 3);
        let schedules = borrow_global_mut<Schedules>(sender);
        assert!(simple_map::contains_key(&schedules.scheduleMap, &receiver_addr), 4);
        let schedule = simple_map::borrow_mut(&mut schedules.scheduleMap, &receiver_addr);
        assert!(schedule.active == true, 5);
        let vesting_signer_from_cap = account::create_signer_with_capability(&schedule.resource_cap);
        let now = aptos_framework::timestamp::now_seconds();
        let amount_to_release = calculate_claim_amount(schedule, now);
        assert_sender_receiver_data(sender, receiver_addr, schedule);
        assert!(amount_to_release > 0, 2);
        if (!coin::is_account_registered<CoinType>(receiver_addr))
        {managed_coin::register<CoinType>(receiver);};
        coin::transfer<CoinType>(&vesting_signer_from_cap,receiver_addr,amount_to_release);
        schedule.released_amount = schedule.released_amount + amount_to_release;
    }

    // Cancel a Vesting Schedule
    // The sender is the signer and can cancel the schedule from the receiver
    // Cancels the schedule only if it is not active
    // Funds are returned to the sender
    public entry fun cancel_schedule<CoinType>
    (
    sender: &signer,
    receiver: address,
    ) acquires Schedules
    {
        let sender_addr = signer::address_of(sender);
        assert_sender_is_not_receiver(sender_addr, receiver);
        assert!(exists<Schedules>(sender_addr), 3);
        let schedules = borrow_global_mut<Schedules>(sender_addr);
        assert!(simple_map::contains_key(&schedules.scheduleMap, &receiver), 4);
        let schedule = simple_map::borrow_mut(&mut schedules.scheduleMap, &receiver);
        assert_sender_receiver_data(sender_addr, receiver, schedule);
        assert!(schedule.active == false, 5);
        let vesting_signer_from_cap = account::create_signer_with_capability(&schedule.resource_cap);
        coin::transfer<CoinType>(&vesting_signer_from_cap, sender_addr, schedule.total_amount);
        simple_map::remove(&mut schedules.scheduleMap, &receiver);
    }

}