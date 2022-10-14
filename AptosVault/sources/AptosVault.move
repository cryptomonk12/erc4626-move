module AptosVault::ConcreteVault{

    use aptos_framework::aptos_coin::{AptosCoin};
    use ERC4626::GenericVault;

    struct YAptosCoin has key {}

    public entry fun initialize_vault(contract_owner: &signer, coin_name: vector<u8>, coin_symbol: vector<u8>, fees: u64){
        GenericVault::initialize_new_vault<AptosCoin, YAptosCoin>(contract_owner, coin_name, coin_symbol, fees);
    }

    public entry fun deposit(user: &signer, amount: u64){
        GenericVault::deposit<AptosCoin, YAptosCoin>(user, amount);
    }

    public entry fun withdraw(user: &signer, assets: u64){
        GenericVault::withdraw<AptosCoin, YAptosCoin>(user, assets);
    }

    public entry fun redeem(user: &signer, shares: u64){
        GenericVault::redeem<AptosCoin, YAptosCoin>(user, shares);
    }

    public entry fun transfer(user: &signer, assets: u64){
        GenericVault::transfer<AptosCoin, YAptosCoin>(user, assets);
    }
}