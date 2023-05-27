# Token Vesting

The `my_addrx::TokenVesting` module implements a token vesting contract. It allows for creating vesting schedules, accepting schedules, claiming unlocked funds, and canceling schedules. Let's go through the code to understand its components.

## Dependencies

The module imports several dependencies:

- `std::vector`: A standard library module for working with dynamic arrays.
- `std::signer`: A standard library module for signer-related operations.
- `aptos_framework::account`: An external module for managing accounts.
- `aptos_std::simple_map::{Self, SimpleMap}`: An external module for managing key-value pairs using a simple map data structure.
- `aptos_framework::managed_coin`: An external module for managing a coin associated with an account.
- `aptos_framework::coin`: An external module for transferring coins.
- `aptos_std::type_info`: An external module for working with type information.

## Vesting Schedule Struct

The `VestingSchedule` struct stores information about a vesting schedule. It has the following fields:
- `sender`: The address of the schedule sender (owner).
- `receiver`: The address of the schedule receiver.
- `coin_type`: The address of the token type associated with the schedule.
- `release_times`: A vector of release times (timestamps) for the schedule.
- `release_amounts`: A vector of corresponding release amounts for each release time.
- `total_amount`: The total amount of tokens to be vested.
- `resource_cap`: The signer capability associated with the vesting schedule.
- `released_amount`: The amount of tokens already released.
- `active`: A boolean indicating whether the schedule is active or not.

## Schedules Struct

The `Schedules` struct stores all the vesting schedules of a sender. It uses a `SimpleMap` to map receiver addresses to their respective `VestingSchedule` instances. The `scheduleMap` field represents the map.

## Error Constants

The module defines several error constants:
- `ENO_SENDER_IS_RECEIVER`: Error code indicating that the sender and receiver addresses are the same.
- `ENO_INVALID_RELEASE_TIMES`: Error code indicating invalid release times.
- `ENO_INVALID_AMOUNT_TO_RELEASE`: Error code indicating an invalid amount to release.
- `ENO_SENDER_MISMATCH`: Error code indicating a sender address mismatch.
- `ENO_RECEIVER_MISMATCH`: Error code indicating a receiver address mismatch.
- `ENO_SCHEDULE_ACTIVE`: Error code indicating that the schedule is already active.

## Helper Functions

The module provides several helper functions:

### `assert_release_times_in_future(release_times: &vector<u64>, timestamp: u64)`

This function asserts that all release times in the given vector are in the future (greater than the current timestamp).

### `assert_sender_is_not_receiver(sender: address, receiver: address)`

This function asserts that the sender and receiver addresses are not the same.

### `assert_sender_receiver_data(sender: address, receiver: address, schedule: &VestingSchedule)`

This function asserts that the sender and receiver addresses match the addresses stored in the provided `VestingSchedule` instance.

### `calculate_claim_amount(schedule: &VestingSchedule, timestamp: u64) -> u64`

This function calculates the amount of tokens that can be claimed based on the provided `VestingSchedule` and the current timestamp. It takes into account the release times and amounts.

### `coin_address<CoinType>() -> address`

This helper function returns the address of the `CoinType`.

## Public Entry Functions

The module provides several public entry functions:

### `create_schedule<CoinType>`

This function is used to create a vest
