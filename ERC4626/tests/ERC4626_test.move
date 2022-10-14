#[test_only]
module ERC4626::VaultTest{
    use aptos_framework::account;
    use aptos_framework::signer;
    use aptos_framework::managed_coin;
    use aptos_framework::timestamp;
    use aptos_framework::coin::{Self, MintCapability, BurnCapability};
    use aptos_framework::aptos_coin::{Self, AptosCoin};

    use ERC4626::GenericVault;

    const CONTRACT_OWNER: address = @ERC4626;
    const APTOSCOIN_MINT_AMOUNT: u64 = 1000000000; 
    const FEES: u64 = 1000;

    struct YAptosCoin has key {}
    struct ZAptosCoin has key {}

    struct AptosCoinTest has key{
        mint_cap: MintCapability<AptosCoin>,
        burn_cap: BurnCapability<AptosCoin>
    }

    #[test (contract_owner=@ERC4626, user=@0x234, aptos_framework=@aptos_framework)]
    public fun initialiaze_test(contract_owner: &signer, user: &signer, aptos_framework: &signer){
        let (y_coin_name, y_coin_symbol): (vector<u8>, vector<u8>) = (b"yAptos", b"yAPT");
        let (z_coin_name, z_coin_symbol): (vector<u8>, vector<u8>) = (b"zAptos", b"zAPT");
        account::create_account_for_test(signer::address_of(contract_owner));
        account::create_account_for_test(signer::address_of(user));
        timestamp::set_time_has_started_for_testing(aptos_framework);
        mint_aptos(contract_owner, user, aptos_framework);
        GenericVault::initialize_new_vault<AptosCoin, YAptosCoin>(contract_owner, y_coin_name, y_coin_symbol, FEES);
        GenericVault::initialize_new_vault<AptosCoin, ZAptosCoin>(contract_owner, z_coin_name, z_coin_symbol, FEES);
    }

    #[test_only]
    fun mint_aptos(contract_owner: &signer, user: &signer, aptos_framework: &signer){
        let admin_addr = signer::address_of(contract_owner);
        let user_addr = signer::address_of(user);
        let ( burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
        let coins_minted_admin = coin::mint<AptosCoin>(APTOSCOIN_MINT_AMOUNT, &mint_cap);
        let coins_minted_user = coin::mint<AptosCoin>(APTOSCOIN_MINT_AMOUNT, &mint_cap);
        if (!coin::is_account_registered<AptosCoin>(admin_addr)){
	      managed_coin::register<AptosCoin>(contract_owner);
        };
        if (!coin::is_account_registered<AptosCoin>(user_addr)){
	      managed_coin::register<AptosCoin>(user);
        };
        coin::deposit<AptosCoin>(admin_addr, coins_minted_admin);
        coin::deposit<AptosCoin>(user_addr, coins_minted_user);
        move_to(contract_owner, AptosCoinTest{
            mint_cap,
            burn_cap
        });
    }

    #[test(contract_owner=@ERC4626, user=@0x234, aptos_framework=@aptos_framework)]
    #[expected_failure(abort_code = 5)]
    public fun initialiaze_test_vault_already_exist(contract_owner: &signer, user: &signer, aptos_framework:&signer){
        initialiaze_test(contract_owner, user, aptos_framework);
        let (y_coin_name, y_coin_symbol): (vector<u8>, vector<u8>) = (b"yAptos", b"yAPT");
        GenericVault::initialize_new_vault<AptosCoin, YAptosCoin>(contract_owner, y_coin_name, y_coin_symbol, FEES);
    }

    #[test(contract_owner=@ERC4626, user=@0x234, aptos_framework=@aptos_framework)]
    #[expected_failure(abort_code = 2)]
    public fun initialiaze_test_no_permission(contract_owner: &signer, user: &signer, aptos_framework:&signer){
        let (y_coin_name, y_coin_symbol): (vector<u8>, vector<u8>) = (b"yAptos", b"yAPT");
        account::create_account_for_test(signer::address_of(contract_owner));
        account::create_account_for_test(signer::address_of(user));
        mint_aptos(contract_owner, user, aptos_framework);
        GenericVault::initialize_new_vault<AptosCoin, YAptosCoin>(user, y_coin_name, y_coin_symbol, FEES);
    }

    #[test(contract_owner=@ERC4626, user=@0x234, aptos_framework=@aptos_framework)]
    public fun deposit_test(contract_owner: &signer, user: &signer, aptos_framework: &signer){
        let deposit_amount: u64 = 100000;
        let before_aptoscoin_bal: u64 = APTOSCOIN_MINT_AMOUNT;
        let before_yaptoscoin_bal: u64 = 0;
        let user_addr = signer::address_of(user);
        initialiaze_test(contract_owner, user, aptos_framework);
        GenericVault::deposit<AptosCoin, YAptosCoin>(user, deposit_amount);
        let (after_aptoscoin_bal, after_yaptoscoin_bal) = GenericVault::get_coins_balance<AptosCoin, YAptosCoin>(user_addr);
        assert!(before_aptoscoin_bal - after_aptoscoin_bal - FEES == deposit_amount, 0);
        assert!(after_yaptoscoin_bal - before_yaptoscoin_bal == deposit_amount, 1);
    }

    #[test(contract_owner=@ERC4626, user=@0x234, aptos_framework=@aptos_framework)]
    public fun deposit_two_vault_test(contract_owner: &signer, user: &signer, aptos_framework: &signer){
        let deposit_amount: u64 = 100000;
        let second_deposit_amount: u64 = 100000;
        let before_aptoscoin_bal: u64 = APTOSCOIN_MINT_AMOUNT;
        let before_yaptoscoin_bal: u64 = 0;
        let user_addr = signer::address_of(user);
        initialiaze_test(contract_owner, user, aptos_framework);
        GenericVault::deposit<AptosCoin, YAptosCoin>(user, deposit_amount);
        GenericVault::deposit<AptosCoin, ZAptosCoin>(user, deposit_amount);
        let (after_aptoscoin_bal, after_yaptoscoin_bal) = GenericVault::get_coins_balance<AptosCoin, YAptosCoin>(user_addr);
        assert!(before_aptoscoin_bal - second_deposit_amount - after_aptoscoin_bal - FEES * 2 == deposit_amount, 0);
        assert!(after_yaptoscoin_bal - before_yaptoscoin_bal == deposit_amount, 1);
    }

    #[test(contract_owner=@ERC4626, user=@0x234, aptos_framework=@aptos_framework)]
    #[expected_failure(abort_code = 6)]
    public fun deposit_test_user_insufficient_balance(contract_owner: &signer, user: &signer, aptos_framework:&signer){
        let deposit_amount: u64 = APTOSCOIN_MINT_AMOUNT + 1000;
        let before_aptoscoin_bal: u64 = APTOSCOIN_MINT_AMOUNT;
        let before_yaptoscoin_bal: u64 = 0;
        let user_addr = signer::address_of(user);
        initialiaze_test(contract_owner, user, aptos_framework);
        GenericVault::deposit<AptosCoin, YAptosCoin>(user, deposit_amount);
        let (after_aptoscoin_bal, after_yaptoscoin_bal) = GenericVault::get_coins_balance<AptosCoin, YAptosCoin>(user_addr);
        assert!(before_aptoscoin_bal - after_aptoscoin_bal == deposit_amount, 0);
        assert!(after_yaptoscoin_bal - before_yaptoscoin_bal == deposit_amount, 1);
    }

    #[test(contract_owner=@ERC4626, user=@0x234, aptos_framework=@aptos_framework)]
    #[expected_failure(abort_code = 1)]
    public fun deposit_test_invalid_vault(contract_owner: &signer, user: &signer, aptos_framework:&signer){
        let deposit_amount: u64 = APTOSCOIN_MINT_AMOUNT + 1000;
        let before_aptoscoin_bal: u64 = APTOSCOIN_MINT_AMOUNT;
        let before_yaptoscoin_bal: u64 = 0;
        let user_addr = signer::address_of(user);
        initialiaze_test(contract_owner, user, aptos_framework);
        GenericVault::deposit<ZAptosCoin, YAptosCoin>(user, deposit_amount);
        let (after_aptoscoin_bal, after_yaptoscoin_bal) = GenericVault::get_coins_balance<AptosCoin, YAptosCoin>(user_addr);
        assert!(before_aptoscoin_bal - after_aptoscoin_bal == deposit_amount, 0);
        assert!(after_yaptoscoin_bal - before_yaptoscoin_bal == deposit_amount, 1);
    }

    #[test(contract_owner=@ERC4626, user=@0x234, aptos_framework=@aptos_framework)]
    public fun withdraw_test(contract_owner: &signer, user: &signer, aptos_framework: &signer){
        let deposit_amount: u64 = 100000;
        let withdrawal_amount: u64 = 5000;
        let user_addr = signer::address_of(user);
        initialiaze_test(contract_owner, user, aptos_framework);
        GenericVault::deposit<AptosCoin, YAptosCoin>(user, deposit_amount);
        let (before_aptoscoin_bal, before_yaptoscoin_bal) = GenericVault::get_coins_balance<AptosCoin, YAptosCoin>(user_addr);
        GenericVault::withdraw<AptosCoin, YAptosCoin>(user, withdrawal_amount);
        let (after_aptoscoin_bal, after_yaptoscoin_bal) = GenericVault::get_coins_balance<AptosCoin, YAptosCoin>(user_addr);
        assert!(after_aptoscoin_bal - before_aptoscoin_bal  == withdrawal_amount - FEES, 0);
        assert!(before_yaptoscoin_bal - after_yaptoscoin_bal  == withdrawal_amount, 1);
    }

    #[test(contract_owner=@ERC4626, user=@0x234, user2=@345, aptos_framework=@aptos_framework)]
    public fun withdraw_after_trasfer_test(contract_owner: &signer, user: &signer, user2:&signer, aptos_framework: &signer){
        let deposit_amount: u64 = 100000;
        let transfer_amount: u64 = 50000;
        let withdrawal_amount: u64 = 125000;
        let user_addr = signer::address_of(user);
        let user2_addr = signer::address_of(user2);
        account::create_account_for_test(signer::address_of(user2));
        initialiaze_test(contract_owner, user, aptos_framework);
        coin::register<AptosCoin>(user2);
        coin::transfer<AptosCoin>(user, user2_addr, deposit_amount);
        GenericVault::deposit<AptosCoin, YAptosCoin>(user, deposit_amount - FEES);
        GenericVault::deposit<AptosCoin, YAptosCoin>(user2, deposit_amount - FEES);
        GenericVault::transfer<AptosCoin, YAptosCoin>(contract_owner, transfer_amount);
        let (before_aptoscoin_bal, _before_yaptoscoin_bal) = GenericVault::get_coins_balance<AptosCoin, YAptosCoin>(user_addr);
        GenericVault::withdraw<AptosCoin, YAptosCoin>(user, withdrawal_amount - FEES);
        let (after_aptoscoin_bal, after_yaptoscoin_bal) = GenericVault::get_coins_balance<AptosCoin, YAptosCoin>(user_addr);
        assert!(after_aptoscoin_bal - before_aptoscoin_bal  == withdrawal_amount- FEES * 2, 0);  
        assert!(after_yaptoscoin_bal == 0, 0);
    }    

    #[test(contract_owner=@ERC4626, user=@0x234, aptos_framework=@aptos_framework)]
    #[expected_failure(abort_code = 6)]
    public fun withdraw_test_insufficient_user_balance(contract_owner: &signer, user: &signer, aptos_framework: &signer){
        let deposit_amount: u64 = 100000;
        let withdrawal_amount: u64 = deposit_amount + 5000;
        let user_addr = signer::address_of(user);
        initialiaze_test(contract_owner, user, aptos_framework);
        GenericVault::deposit<AptosCoin, YAptosCoin>(user, deposit_amount);
        let (before_aptoscoin_bal, before_yaptoscoin_bal) = GenericVault::get_coins_balance<AptosCoin, YAptosCoin>(user_addr);
        GenericVault::withdraw<AptosCoin, YAptosCoin>(user, withdrawal_amount);
        let (after_aptoscoin_bal, after_yaptoscoin_bal) = GenericVault::get_coins_balance<AptosCoin, YAptosCoin>(user_addr);
        assert!(after_aptoscoin_bal - before_aptoscoin_bal  == withdrawal_amount, 0);
        assert!(before_yaptoscoin_bal - after_yaptoscoin_bal  == withdrawal_amount, 1);
    }

    #[test(contract_owner=@ERC4626, user=@0x234, aptos_framework=@aptos_framework)]
    #[expected_failure(abort_code = 1)]
    public fun withdraw_test_invalid_vault(contract_owner: &signer, user: &signer, aptos_framework: &signer){
        let deposit_amount: u64 = 100000;
        let withdrawal_amount: u64 = deposit_amount + 5000;
        let user_addr = signer::address_of(user);
        initialiaze_test(contract_owner, user, aptos_framework);
        GenericVault::deposit<AptosCoin, YAptosCoin>(user, deposit_amount);
        let (before_aptoscoin_bal, before_yaptoscoin_bal) = GenericVault::get_coins_balance<AptosCoin, YAptosCoin>(user_addr);
        GenericVault::withdraw<ZAptosCoin, YAptosCoin>(user, withdrawal_amount);
        let (after_aptoscoin_bal, after_yaptoscoin_bal) = GenericVault::get_coins_balance<AptosCoin, YAptosCoin>(user_addr);
        assert!(after_aptoscoin_bal - before_aptoscoin_bal  == withdrawal_amount, 0);
        assert!(before_yaptoscoin_bal - after_yaptoscoin_bal  == withdrawal_amount, 1);
    }

    #[test(contract_owner=@ERC4626, user=@0x234, aptos_framework=@aptos_framework)]
    public fun redeem_test_with_admin_transfer(contract_owner: &signer, user: &signer, aptos_framework: &signer){
        let deposit_amount: u64 = 100000;
        let transfer_amount: u64 = 200000;
        let redeem_amount: u64 = 50000;
        let user_addr = signer::address_of(user);
        initialiaze_test(contract_owner, user, aptos_framework);
        GenericVault::deposit<AptosCoin, YAptosCoin>(user, deposit_amount);
        GenericVault::transfer<AptosCoin, YAptosCoin>(contract_owner, transfer_amount);
        let (before_aptoscoin_bal, before_yaptoscoin_bal) = GenericVault::get_coins_balance<AptosCoin, YAptosCoin>(user_addr);
        assert!(before_yaptoscoin_bal == deposit_amount, 0);
        GenericVault::redeem<AptosCoin, YAptosCoin>(user, redeem_amount);
        let (after_aptoscoin_bal, after_yaptoscoin_bal) = GenericVault::get_coins_balance<AptosCoin, YAptosCoin>(user_addr);
        assert!(after_aptoscoin_bal - before_aptoscoin_bal  == (deposit_amount + transfer_amount) / 2 - FEES, 1);
        assert!(after_yaptoscoin_bal  == (deposit_amount - redeem_amount), 2);
    }

    #[test(contract_owner=@ERC4626, user=@0x234, aptos_framework=@aptos_framework)]
    #[expected_failure (abort_code=8)]
    public fun redeem_test_insufficient_amount(contract_owner: &signer, user: &signer, aptos_framework: &signer){
        let deposit_amount: u64 = 100000;
        let transfer_amount: u64 = 200000;
        let redeem_amount: u64 = deposit_amount + 1;
        let user_addr = signer::address_of(user);
        initialiaze_test(contract_owner, user, aptos_framework);
        GenericVault::deposit<AptosCoin, YAptosCoin>(user, deposit_amount);
        GenericVault::transfer<AptosCoin, YAptosCoin>(contract_owner, transfer_amount);
        let (before_aptoscoin_bal, before_yaptoscoin_bal) = GenericVault::get_coins_balance<AptosCoin, YAptosCoin>(user_addr);
        assert!(before_yaptoscoin_bal == deposit_amount, 0);
        GenericVault::redeem<AptosCoin, YAptosCoin>(user, redeem_amount);
        let (after_aptoscoin_bal, after_yaptoscoin_bal) = GenericVault::get_coins_balance<AptosCoin, YAptosCoin>(user_addr);
        assert!(after_aptoscoin_bal - before_aptoscoin_bal  == (deposit_amount + transfer_amount) / 2, 1);
        assert!(after_yaptoscoin_bal  == (deposit_amount - redeem_amount), 2);
    }

}