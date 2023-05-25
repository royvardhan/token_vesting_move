module my_addrx::TokenVesting
{
    use std::vector;
    use std::signer;
    use aptos_framework::account;
    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_framework::managed_coin;
    use aptos_framework::coin;
    use aptos_std::type_info;


    struct VestingSchedule has key, store {
        sender: address,
        receiver: address,
        coin_type: address,
        release_times: vector<u64>,
        release_amounts: vector<u64>,
        total_amount: u64,
        resource_cap: account::SignerCapability,
        released_amount: u64
    }

    struct VestingCap has key {
        vestingMap: SimpleMap<vector<u8>, address>
    }

    public entry fun create_schedule <CoinType>
    (
    sender: &signer, 
    receiver: address, 
    times: vector<u64>, 
    amounts: vector<u64>,
    total: u64,
    seeds: vector<u8>
    ) acquires VestingCap
    {
        let sender_addr = signer::address_of(sender);
        let (vesting, vesting_cap) = account::create_resource_account(sender, seeds);
        let vesting_addr = signer::address_of(&vesting);
        if(!exists<VestingCap>(sender_addr)) {
            move_to(sender, VestingCap{vestingMap: simple_map::create()});
        };
        let map = borrow_global_mut<VestingCap>(sender_addr);
        simple_map::add(&mut map.vestingMap, seeds, vesting_addr);
        let vesting_signer_from_cap = account::create_signer_with_capability(&vesting_cap);
        let len_of_amt = vector::length(&amounts);
        let len_of_times = vector::length(&times);
        assert!(len_of_amt == len_of_times, 0);
        let total_amount:u64 = 0;
        let i:u64 = 0;
        while (i < len_of_amt) {
            let amount = *vector::borrow(&amounts, i);
            total_amount = total_amount + amount;
            i = i + 1;
        };
        assert!(total_amount == total, 0);
        // Todo  - Add checks for unix_timestamp always greater than now
        let released_amount = 0;
        let coin_addr = coin_address<CoinType>();

        move_to(&vesting_signer_from_cap, VestingSchedule {
            sender: sender_addr,
            receiver: receiver,
            coin_type: coin_addr,
            release_times: times,
            release_amounts: amounts,
            total_amount: total,
            resource_cap: vesting_cap,
            released_amount: released_amount
        });
        let escrow_addr = signer::address_of(&vesting);
        managed_coin::register<CoinType>(&vesting_signer_from_cap);
        coin::transfer<CoinType>(sender, escrow_addr, total);
    }

    public entry fun release_fund<CoinType>
    (
    receiver: &signer, 
    sender:address, 
    seeds: vector<u8>
    ) 
    acquires VestingCap, VestingSchedule 
    {
        let receiver_addr = signer::address_of(receiver);
        assert!(exists<VestingCap>(sender), 0);
        let map = borrow_global<VestingCap>(sender);
        let vesting_addr = *simple_map::borrow(&map.vestingMap, &seeds);
        let vesting_schedule = borrow_global_mut<VestingSchedule>(vesting_addr);
        let vesting_signer_from_cap = account::create_signer_with_capability(&vesting_schedule.resource_cap);
        assert!(vesting_schedule.sender == sender, 0);
        assert!(vesting_schedule.receiver == receiver_addr, 0);
        let len_of_schdule = vector::length(&vesting_schedule.release_amounts);
        let amount_to_release = 0;
        let i = 0;
        let now = aptos_framework::timestamp::now_seconds();
        while(i < len_of_schdule) {
            let tmp_amount = *vector::borrow(&vesting_schedule.release_amounts, i);
            let tmp_times = *vector::borrow(&vesting_schedule.release_times, i);
            if (now >= tmp_times) {
                amount_to_release = amount_to_release + tmp_amount;
            };
                i = i+1;
            };
        amount_to_release = amount_to_release -  vesting_schedule.released_amount;
        if (!coin::is_account_registered<CoinType>(receiver_addr))
        {managed_coin::register<CoinType>(receiver);};
        coin::transfer<CoinType>(&vesting_signer_from_cap,receiver_addr,amount_to_release);
        vesting_schedule.released_amount= vesting_schedule.released_amount + amount_to_release;
        }

    /// A helper function that returns the address of CoinType.
    fun coin_address<CoinType>(): address {
        let type_info = type_info::type_of<CoinType>();
        type_info::account_address(&type_info)
    }
}