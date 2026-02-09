### install foundry-rs/forge-std
```shell
$ forge install foundry-rs/forge-std --no-commit --no-git
```
### install openzeppelin-contracts
```shell
$ forge install openzeppelin/openzeppelin-contracts --no-git
```

### install openzeppelin-contracts-upgradeable
```shell
$ forge install openzeppelin/openzeppelin-contracts-upgradeable --no-git
```

### deploy wallet
```shell
$ forge script script/Deploy.s.sol -vvv --rpc-url=https://bsc.blockrazor.xyz --broadcast --private-key=[privateKey]
```

## verify token
```shell
$ cast abi-encode "constructor(address)" 0xDA61a4Ef3d65F2AE557e6D2842991f82bf0dC0B3 
```

```shell
$ forge verify-contract --chain-id 56 --compiler-version v0.8.30+commit.a1b79de6 0x1A0156d9777d06c4E73a4E46503c6b7E5e4B3C27 src/Sdt.sol:Sdt  --constructor-args 0x000000000000000000000000da61a4ef3d65f2ae557e6d2842991f82bf0dc0b3 --etherscan-api-key Y43WNBZNXWR5V4AWQKGAQ9RCQEXTUHK88V

```

#### sdt token:0x1A0156d9777d06c4E73a4E46503c6b7E5e4B3C27
#### recharge:0x60b77f4df09c433bd12130F2eFA75EC2Fd292fa2
#### abi:./out/recharge.sol/recharge.json

```solidity
//单币种充值，token传0地址标识要充值主币，其他地址正常，amount充值的数量，remark标识
function singleRecharge(address token, uint256 amount, string calldata remark) external payable;
//双币种充值，token0/token1如果其中一个为0地址，则表示充值主币，amount0/amount1要与之对应
function multiRecharge(
        address token0,
        uint256 amount0,
        address token1,
        uint256 amount1,
        string calldata remark
    ) external payable；
```