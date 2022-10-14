module ERC4626::GenericVault{
    use aptos_framework::account;
    use aptos_framework::signer;
    use aptos_framework::coin::{Self, MintCapability, FreezeCapability, BurnCapability};
    use aptos_framework::string::{Self, String, utf8};
    use aptos_framework::managed_coin;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::timestamp;
    use aptos_std::type_info;

    const VAULT_NOT_REGISTERED: u64 = 1;
    const NO_ADMIN_PERMISSION: u64 = 2;
    const COIN_ONE_NOT_REGISTERED: u64 = 3;
    const COIN_TWO_NOT_EXIST:u64 = 4;
    const VAULT_ALREADY_REGISTERED: u64 = 5;
    const INSUFFICIENT_USER_BALANCE: u64 = 6;
    const INSUFFICIENT_VAULT_BALANCE: u64 = 7;
    const INSUFFICIENT_SHARES_AMOUNT: u64 = 8;

    const MODULE_ADDRESS: address = @ERC4626;

    struct VaultInfo<phantom CoinType, phantom YCoinType> has key{
        signer_capability: account::SignerCapability,
        addr: address,
        fees: u64,
        mint_cap: MintCapability<YCoinType>,
        freeze_cap: FreezeCapability<YCoinType>,
        burn_cap: BurnCapability<YCoinType>
    }

    struct VaultSharesSupply <phantom CoinType, phantom YCoinType> has key, drop{
        value: u64
    }

    struct VaultEvents has key{
        deposit_event: EventHandle<DepositEvent>,
        withdrawal_event: EventHandle<WithdrawalEvent>,
        transfer_event: EventHandle<TransferEvent>
    }

    struct DepositEvent has drop, store{
        from: address,
        to: address,
        timestamp: u64,
        vault_name: String,
        from_coin_balance: u64,
        to_coin_balance: u64,
        from_coin_y_balance: u64,
        to_coin_y_balance:u64
    }

    struct WithdrawalEvent has drop, store{
        from: address,
        to: address,
        timestamp: u64,
        vault_name: String,
        from_coin_balance: u64,
        to_coin_balance: u64,
        from_coin_y_balance: u64,
        to_coin_y_balance:u64
    }

    struct TransferEvent has drop, store{
        from: address,
        to: address,
        timestamp: u64,
        vault_name: String,
        from_coin_balance: u64,
        to_coin_balance: u64,
        from_coin_y_balance: u64,
        to_coin_y_balance:u64
    }

    public entry fun initialize_new_vault<CoinType, YCoinType>(contract_owner:&signer, y_coin_name:vector<u8>, y_coin_symbol:vector<u8>, fees: u64){      
        let contract_owner_addr = signer::address_of(contract_owner);
        assert!(contract_owner_addr == MODULE_ADDRESS, NO_ADMIN_PERMISSION);
        assert!(coin::is_account_registered<CoinType>(contract_owner_addr), COIN_ONE_NOT_REGISTERED);
        assert!(!exists<VaultInfo<CoinType, YCoinType>>(contract_owner_addr), VAULT_ALREADY_REGISTERED);  
        let vault_name = get_vault_name<CoinType, YCoinType>();
        let (vault_signer, vault_signer_capability) = account::create_resource_account(contract_owner, *string::bytes(&vault_name));
        let vault_addr = signer::address_of(&vault_signer);
        managed_coin::register<CoinType>(&vault_signer);
        let ( burn_cap, freeze_cap, mint_cap) = coin::initialize<YCoinType>(contract_owner, utf8(y_coin_name), utf8(y_coin_symbol), 0, true);
        move_to(contract_owner, VaultInfo<CoinType, YCoinType>{
            signer_capability: vault_signer_capability,
            addr: vault_addr,
            fees,
            mint_cap,
            freeze_cap,
            burn_cap,
        });
        move_to(&vault_signer, VaultSharesSupply<CoinType, YCoinType>{
            value: 0
        });
    }

    fun register<CoinType>(account: &signer){
        if (!coin::is_account_registered<CoinType>(signer::address_of(account))){
            coin::register<CoinType>(account);
        };
    }

    public entry fun deposit<CoinType, YCoinType>(user: &signer, asset_amount:u64) acquires VaultInfo, VaultSharesSupply, VaultEvents{
        let user_addr = signer::address_of(user);    
        assert!(exists<VaultInfo<CoinType, YCoinType>>(MODULE_ADDRESS), VAULT_NOT_REGISTERED);
        let vault_name = get_vault_name<CoinType, YCoinType>();
        let vault_info = borrow_global<VaultInfo<CoinType, YCoinType>>(MODULE_ADDRESS);
        initialize_vault_events<CoinType, YCoinType>(user);
        register<CoinType>(user);
        register<YCoinType>(user);
        let (from_coin_balance, from_coin_y_balance): (u64, u64) = get_coins_balance<CoinType, YCoinType>(user_addr);
        assert!(from_coin_balance >= asset_amount + vault_info.fees, INSUFFICIENT_USER_BALANCE);
        coin::transfer<CoinType>(user, MODULE_ADDRESS, vault_info.fees);
        coin::transfer<CoinType>(user, vault_info.addr, asset_amount);
        let coins_minted = coin::mint<YCoinType>(asset_amount, &vault_info.mint_cap);
        coin::deposit(user_addr, coins_minted);
        let vault_shares_balance = borrow_global_mut<VaultSharesSupply<CoinType, YCoinType>>(vault_info.addr);
        vault_shares_balance.value = vault_shares_balance.value + asset_amount;
        let (to_coin_balance, to_coin_y_balance): (u64, u64) = get_coins_balance<CoinType, YCoinType>(user_addr);
        event::emit_event(&mut borrow_global_mut<VaultEvents>(user_addr).deposit_event, DepositEvent{
            from: user_addr,
            to: vault_info.addr,
            timestamp: timestamp::now_seconds(),
            vault_name,
            from_coin_balance,
            to_coin_balance,
            from_coin_y_balance,
            to_coin_y_balance
        });
    }

    fun initialize_vault_events<CoinType, YCoinType>(account: &signer) {
        if(!exists<VaultEvents>(signer::address_of(account))){
            move_to(account, VaultEvents{
                deposit_event: account::new_event_handle<DepositEvent>(account),
                withdrawal_event: account::new_event_handle<WithdrawalEvent>(account),
                transfer_event: account::new_event_handle<TransferEvent>(account)
            });
        }; 
    }

    fun get_vault_name<CoinType, YCoinType>(): string::String{
        let cointype_name = get_struct_name<CoinType>();
        let ycointype_name = get_struct_name<YCoinType>();
        let separator = utf8(b"/");
        string::append(&mut cointype_name, separator);
        string::append(&mut cointype_name, ycointype_name);
        cointype_name
    }

    fun get_struct_name<S>(): string::String {
        let type_info = type_info::type_of<S>();
        let struct_name = type_info::struct_name(&type_info);
        utf8(struct_name)
    }

    public fun get_coins_balance<CoinType, YCoinType>(account_addr: address): (u64, u64){
        let coin_balance = coin::balance<CoinType>(account_addr);
        let coin_y_balance = coin::balance<YCoinType>(account_addr);
        (coin_balance, coin_y_balance)
    }

    public entry fun withdraw<CoinType, YCoinType>(user: &signer, assets_amount: u64) acquires VaultInfo, VaultSharesSupply, VaultEvents{
        let user_addr = signer::address_of(user);    
        assert!(exists<VaultInfo<CoinType, YCoinType>>(MODULE_ADDRESS), VAULT_NOT_REGISTERED);
        let vault_name = get_vault_name<CoinType, YCoinType>();
        let vault_info = borrow_global<VaultInfo<CoinType, YCoinType>>(MODULE_ADDRESS);
        let vault_shares_supply = borrow_global_mut<VaultSharesSupply<CoinType, YCoinType>>(vault_info.addr);
        initialize_vault_events<CoinType, YCoinType>(user);
        register<CoinType>(user);
        register<YCoinType>(user);
        let (from_coin_balance, from_coin_y_balance): (u64, u64) = get_coins_balance<CoinType, YCoinType>(user_addr);
        let coin_y_to_burn = convert_asset_to_shares<CoinType>(vault_info.addr, assets_amount, vault_shares_supply.value);
        assert!(from_coin_y_balance >= coin_y_to_burn, INSUFFICIENT_USER_BALANCE);
        assert!(from_coin_balance >= vault_info.fees, INSUFFICIENT_USER_BALANCE);
        coin::transfer<CoinType>(user, MODULE_ADDRESS, vault_info.fees);
        coin::burn_from<YCoinType>(user_addr, coin_y_to_burn, &vault_info.burn_cap);
        vault_shares_supply.value = vault_shares_supply.value - coin_y_to_burn;
        let vault_signer = account::create_signer_with_capability(&vault_info.signer_capability);
        coin::transfer<CoinType>(&vault_signer, user_addr, assets_amount);
        let (to_coin_balance, to_coin_y_balance): (u64, u64) = get_coins_balance<CoinType, YCoinType>(user_addr);
        event::emit_event(&mut borrow_global_mut<VaultEvents>(user_addr).withdrawal_event, WithdrawalEvent{
            from: vault_info.addr,
            to: user_addr,
            timestamp: timestamp::now_seconds(),
            vault_name,
            from_coin_balance,
            to_coin_balance,
            from_coin_y_balance,
            to_coin_y_balance
        });
    }

    fun convert_asset_to_shares<CoinType>(vault_addr: address, assets_amount: u64, shares_supply: u64): u64{
        let asset_supply: u64 = coin::balance<CoinType>(vault_addr);
        (shares_supply * assets_amount) / asset_supply
    }

    fun total_asset_supply<CoinType, YCoinType>(vault_addr: address): u64 {
        coin::balance<CoinType>(vault_addr)
    }

    public entry fun redeem<CoinType, YCoinType>(user: &signer, shares_amount: u64) acquires VaultInfo, VaultEvents, VaultSharesSupply{
        let user_addr = signer::address_of(user);
        let shares_balance = coin::balance<YCoinType>(user_addr);
        assert!( shares_balance >= shares_amount, INSUFFICIENT_SHARES_AMOUNT);
        assert!(exists<VaultInfo<CoinType, YCoinType>>(MODULE_ADDRESS), VAULT_NOT_REGISTERED);
        let vault_name = get_vault_name<CoinType, YCoinType>();
        initialize_vault_events<CoinType, YCoinType>(user);
        let vault_info = borrow_global<VaultInfo<CoinType, YCoinType>>(MODULE_ADDRESS);
        let vault_shares_supply = borrow_global_mut<VaultSharesSupply<CoinType, YCoinType>>(vault_info.addr);
        let shares_supply = vault_shares_supply.value;
        let vault_signer = account::create_signer_with_capability(&vault_info.signer_capability);
        let withdrawal_amount = convert_shares_to_asset<CoinType>(vault_info.addr, shares_amount, shares_supply);
        let (from_coin_balance, from_coin_y_balance): (u64, u64) = get_coins_balance<CoinType, YCoinType>(user_addr);
        coin::burn_from<YCoinType>(user_addr, shares_amount, &vault_info.burn_cap);
        assert!(from_coin_balance >= vault_info.fees, INSUFFICIENT_USER_BALANCE);
        coin::transfer<CoinType>(user, MODULE_ADDRESS, vault_info.fees);
        coin::transfer<CoinType>(&vault_signer, user_addr, withdrawal_amount);
        vault_shares_supply.value = vault_shares_supply.value - shares_amount;
        let (to_coin_balance, to_coin_y_balance): (u64, u64) = get_coins_balance<CoinType, YCoinType>(user_addr);
        event::emit_event(&mut borrow_global_mut<VaultEvents>(user_addr).withdrawal_event, WithdrawalEvent{
            from: vault_info.addr,
            to: user_addr,
            timestamp: timestamp::now_seconds(),
            vault_name,
            from_coin_balance,
            to_coin_balance,
            from_coin_y_balance,
            to_coin_y_balance
        });
    }

    public entry fun max_withdraw<CoinType, YCoinType>(account: &signer, vault_addr:address): u64 acquires VaultSharesSupply{
        let shares_balance = coin::balance<YCoinType>(signer::address_of(account));
        let vault_shares_supply = borrow_global_mut<VaultSharesSupply<CoinType, YCoinType>>(vault_addr);
        convert_shares_to_asset<CoinType>(vault_addr, shares_balance, vault_shares_supply.value)
    }

    fun convert_shares_to_asset<CoinType>(vault_addr: address, shares_amount: u64, shares_supply: u64): u64 {
        let asset_supply: u64 = coin::balance<CoinType>(vault_addr);
        (shares_amount * asset_supply) / shares_supply
    }

    public entry fun transfer<CoinType, YCoinType>(user: &signer, asset_amount:u64) acquires VaultEvents, VaultInfo{
        let user_addr = signer::address_of(user);    
        assert!(exists<VaultInfo<CoinType, YCoinType>>(MODULE_ADDRESS), VAULT_NOT_REGISTERED);
        let vault_name = get_vault_name<CoinType, YCoinType>();
        let vault_info = borrow_global<VaultInfo<CoinType, YCoinType>>(MODULE_ADDRESS);
        initialize_vault_events<CoinType, YCoinType>(user);
        register<CoinType>(user);
        register<YCoinType>(user);
        let (from_coin_balance, from_coin_y_balance): (u64, u64) = get_coins_balance<CoinType, YCoinType>(user_addr);
        assert!(from_coin_balance >= asset_amount, INSUFFICIENT_USER_BALANCE);
        coin::transfer<CoinType>(user, vault_info.addr, asset_amount);
        let (to_coin_balance, to_coin_y_balance): (u64, u64) = get_coins_balance<CoinType, YCoinType>(user_addr);
        event::emit_event(&mut borrow_global_mut<VaultEvents>(user_addr).transfer_event, TransferEvent{
            from: user_addr,
            to: vault_info.addr,
            timestamp: timestamp::now_seconds(),
            vault_name,
            from_coin_balance,
            to_coin_balance,
            from_coin_y_balance,
            to_coin_y_balance
        });
    }
}