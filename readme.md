# ERC4626

ERC-4626 is a standard to optimize and unify the technical parameters of yield-bearing vaults. It provides a standard API for tokenized yield-bearing vaults that represent shares of a single underlying ERC-20 token. ERC-4626 also outlines an optional extension for tokenized vaults utilizing ERC-20, offering basic functionality for depositing, withdrawing tokens and reading balances. …” [4]

All EIP-4626 tokenized Vaults must implement EIP-20 to represent shares. If a Vault is to be non-transferrable, it may revert on calls to transfer or transferFrom. The EIP-20 operations balanceOf, transfer, totalSupply, etc. operate on the Vault “shares” which represent a claim to ownership on a fraction of the Vault’s underlying holdings.

All EIP-4626 tokenized Vaults must implement EIP-20’s optional metadata extensions. The name and symbol functions sholud reflect the underlying token’s name and symbol in some way.

EIP-4626 tokenized Vaults may implement EIP-2612 to improve the UX of approving shares on various integrations.


 Definitions

* **Asset**: The underlying token managed by the Vault. Has units defined by the corresponding EIP-20 contract.
* **Share**: The token of the Vault. Has a ratio of underlying assets exchanged on mint/deposit/withdraw/redeem (as defined by the Vault).
* **Fee**: An amount of assets or shares charged to the user by the Vault. Fees can exists for deposits, yield, AUM, withdrawals, or anything else prescribed by the Vault.
* **Slippage**: Any difference between advertised share price and economic realities of deposit to or withdrawal from the Vault, which is not accounted by fees.


## Introduction 

The contract is inspired to the Ethereum standard [ERC4626](https://ethereum.org/en/developers/docs/standards/tokens/erc-4626)
but considering the peculiarities of Aptos blockchain.

Here is a [solidity example implementation](https://github.com/transmissions11/solmate/blob/main/src/mixins/ERC4626.sol) 

```rust
  struct VaultInfo<phantom CoinType, phantom YCoinType> has key{
        signer_capability: account::SignerCapability,
        addr: address,
        mint_cap: MintCapability<YCoinType>,
        freeze_cap: FreezeCapability<YCoinType>,
        burn_cap: BurnCapability<YCoinType>
    }
```

Each vault is uniquely defined from the couple ```<phantom CoinType, phantom YCoinType>```
The **CoinType**: represents the asset the user wants deposit in the vault.
The **YCoinType**: represents the share coin that allows to withdraw/redeem the asset.

The contract allow to handle different vaults with a single account.

## Methods list

### Initialize new vault
```public entry fun initialize_new_vault<CoinType, YCoinType>(contract_owner:&signer, y_coin_name:vector<u8>, y_coin_symbol:vector<u8>, fees:u64)```
This method initializes a new vault.

### Deposit
```public entry fun deposit<CoinType, YCoinType>(user: &signer, asset_amount:u64) acquires VaultInfo, VaultSharesSupply, VaultEvents```
The method allows the user to deposit asset and receive back shares 1:1 of the asset deposited.

### Withdraw
```public entry fun withdraw<CoinType, YCoinType>(user: &signer, assets_amount: u64) acquires VaultInfo, VaultSharesSupply, VaultEvents```
This function accepts as input the asset amount the user wants to withdraw. If the user has sufficient shares to withdraw the asset amount the method will succeed.

### Redeem
```public entry fun redeem<CoinType, YCoinType>(user: &signer, shares_amount: u64) acquires VaultInfo, VaultEvents, VaultSharesSupply```
This function accepts as input a share amount value. The user will receive back asset coins proportional to his share partecipation.

### Transfer
```public entry fun transfer<CoinType, YCoinType>(user: &signer, asset_amount:u64) acquires VaultEvents, VaultInfo```
This method allows to deposit assets in the vault but without receive shares back.

# How to use the contract
The logic of the smart contract is contained in **ERC4626.move**. ERC4626 exports generic methods to handle vaults.
The concrete instance that allows interaction with the contract is achieved through **AptosVault.move**. 
You should customize AptosVault.move to handle different asset/share coins.

### 1. Publishing ERC4626 contract
```aptos move publish --package-dir erc4626/ERC4626 --named-addresses ERC4626=default ```

```json
{
  "Result": {
    "transaction_hash": "0x28ded100a300f4798ac34bcd88065148db240fe2fcdad6fa5303c354fb4754e6",
    "gas_used": 2455,
    "gas_unit_price": 100,
    "sender": "3376887002bf3f4a33ff084ec4266f3044a9ac40327212867958ed4d953de3af",
    "sequence_number": 0,
    "success": true,
    "timestamp_us": 1665409837712911,
    "version": 16512389,
    "vm_status": "Executed successfully"
  }
}
```

### 2. Publishing AptosVault
The AptosVault is the concrete instance of the package ERC4626. In this case is implemented with AptosCoin (asset) and YAptosCoin (share).

Before to deploy AptosVault you have to edit the AptosVault toml file with the address of the ERC4626 published before

```toml
[package]
name="AptosVault"
version="0.1.0"

[addresses]
AptosVault="_"
ERC4626="0x3376887002bf3f4a33ff084ec4266f3044a9ac40327212867958ed4d953de3af"

[dependencies]
ERC4626= { local = "../ERC4626/" }
```

```aptos move publish --package-dir AptosVault --named-addresses AptosVault=default```

```json
{
  "Result": {
    "transaction_hash": "0x992c939b27df9cb37d54581848944a0db9df653b4ae0d7ad265a2875a17a90f4",
    "gas_used": 1375,
    "gas_unit_price": 100,
    "sender": "3376887002bf3f4a33ff084ec4266f3044a9ac40327212867958ed4d953de3af",
    "sequence_number": 1,
    "success": true,
    "timestamp_us": 1665409875500956,
    "version": 16513248,
    "vm_status": "Executed successfully"
  }
}
```

### 3. Create vault instance
```aptos move run --function-id 3376887002bf3f4a33ff084ec4266f3044a9ac40327212867958ed4d953de3af::ConcreteVault::initialiaze_vault --args string:aptosCoin string:apt u64:5000```

```json
{
  "Result": {
    "transaction_hash": "0xfbb83e3432e52202dcc7ea930e111332f1562abb753e4466e51f922624b17096",
    "gas_used": 461,
    "gas_unit_price": 100,
    "sender": "3376887002bf3f4a33ff084ec4266f3044a9ac40327212867958ed4d953de3af",
    "sequence_number": 3,
    "success": true,
    "timestamp_us": 1665410572352481,
    "version": 16527440,
    "vm_status": "Executed successfully"
  }
}
```

### 4. Deposit example
```aptos move run --function-id 932d148b45216030dd27a72b1b053db27987c5b93635c40c0852e5be508b8a49::ConcreteVault::deposit --args u64:1000000```

```json
{
  "Result": {
    "transaction_hash": "0x6458d2baa3c1818e8238c9ea6fceeb840d0f8653037cb5e838771fb0e0d71215",
    "gas_used": 582,
    "gas_unit_price": 100,
    "sender": "3376887002bf3f4a33ff084ec4266f3044a9ac40327212867958ed4d953de3af",
    "sequence_number": 4,
    "success": true,
    "timestamp_us": 1665410841570928,
    "version": 16533346,
    "vm_status": "Executed successfully"
  }
}
```

### 5. Trasfer example
```aptos move run --function-id 932d148b45216030dd27a72b1b053db27987c5b93635c40c0852e5be508b8a49::ConcreteVault::transfer --args u64:1111111```

```json
{
  "Result": {
    "transaction_hash": "0x5ff9c238037e5d9615fd819c981203442d3d103c9a714a5f4bfe137a1955bd9d",
    "gas_used": 358,
    "gas_unit_price": 100,
    "sender": "3376887002bf3f4a33ff084ec4266f3044a9ac40327212867958ed4d953de3af",
    "sequence_number": 6,
    "success": true,
    "timestamp_us": 1665410904880749,
    "version": 16534629,
    "vm_status": "Executed successfully"
  }
}
```

### 6. Withdraw example
```aptos move run --function-id 932d148b45216030dd27a72b1b053db27987c5b93635c40c0852e5be508b8a49::ConcreteVault::withdraw --args u64:20000```

```json
{
  "Result": {
    "transaction_hash": "0x7bc0929e524d80570afa7f197cc9d19fcebf0b21dce277406c6a92f5fd21e10e",
    "gas_used": 519,
    "gas_unit_price": 100,
    "sender": "3376887002bf3f4a33ff084ec4266f3044a9ac40327212867958ed4d953de3af",
    "sequence_number": 7,
    "success": true,
    "timestamp_us": 1665410951767585,
    "version": 16535636,
    "vm_status": "Executed successfully"
  }
}
```

### 7. Redeem example
```aptos move run --function-id 932d148b45216030dd27a72b1b053db27987c5b93635c40c0852e5be508b8a49::ConcreteVault::redeem --args u64:33300```

```json
{
  "Result": {
    "transaction_hash": "0x899f677175c3ddeb12695c8e9a883179905f48008deb01a70528c4e3f12ca713",
    "gas_used": 518,
    "gas_unit_price": 100,
    "sender": "3376887002bf3f4a33ff084ec4266f3044a9ac40327212867958ed4d953de3af",
    "sequence_number": 8,
    "success": true,
    "timestamp_us": 1665410991416610,
    "version": 16536619,
    "vm_status": "Executed successfully"
  }
}
```