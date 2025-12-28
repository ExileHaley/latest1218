### install foundry-rs/forge-std
```shell
$ forge install foundry-rs/forge-std --no-commit --no-git
```
### install openzeppelin-contracts
```shell
$ forge install openzeppelin/openzeppelin-contracts  --no-git
```

### install openzeppelin-contracts-upgradeable
```shell
$ forge install openzeppelin/openzeppelin-contracts-upgradeable  --no-git
```

### deploy nadi
```shell
$ forge script script/Deploy.s.sol -vvv --rpc-url=https://rpc.naaidepin.co --broadcast --private-key=[privateKey]
```
### deploy bsc
```shell
$ forge script script/Recharge.s.sol -vvv --rpc-url=https://bsc.blockrazor.xyz --broadcast --private-key=[privateKey]
```


### verify contract
```shell
$ forge verify-contract --chain-id 56 --compiler-version v0.8.30+commit.a1b79de6 0x7D5014e549E83F2Abb1F346caCd9773245D51923 src/Skp.sol:Skp  --constructor-args 0x000000000000000000000000d4360fae9a810be17b5fc1edf12849675996f71200000000000000000000000073832d01364c48e4b6c49b9ecbf07ab92852b67c000000000000000000000000940fa6e4dcbba8fb25470663849b815a732a021c --etherscan-api-key Y43WNBZNXWR5V4AWQKGAQ9RCQEXTUHK88V

$ cast abi-encode "constructor(address,address,address)" 0xD4360fAE9a810Be17b5fC1edF12849675996f712 0x73832D01364c48e4b6C49B9ECBF07aB92852B67c 0x940FA6e4dCBBA8Fb25470663849B815a732a021C 
```



#### usdt:0x3ea660cDc7b7CCC9F81c955f1F2412dCeb8518A5
#### adx:0x68a4d37635cdB55AF61B8e58446949fB21f384e5

### bsc 链
#### recharge:0x44132e2b86C566C136E894699b6c2aF5D5eA7498

### Nadi链
#### gas:0xCDc2580B36E746Beb3755a55043EBFA02714010f
#### x101:0xc15E4aaf9180791C60C0a3906515f1c0C5199FD6
#### recharge contract:0x5be240960c507F1f9425419512fd765732B0cf65
### recharge func list
```solidity
//管理员方法，使用管理员地址操作，token代币地址，recipients该代币要分配的地址，rates按照地址设置比例，比如10%，就是100，分母是1000
//举例token = usdt合约地址，recipients = [A地址、B地址]，rates = [300,700]，意思就是用户充值的usdt30%给到A地址，70%给到B地址
function setAllocation(address token, address[] calldata recipients, uint256[] calldata rates) external;
//添加流动性时计算所需token1的数量
function getQuoteAmount(
        address token0,
        address token1,
        uint256 amount0
    ) external view returns (uint256);
//添加流动性，token1的数量自动计算，不需要输入，这里token0和token1都需要对recharge授权
function addLiquidity(
        address token0,
        address token1,
        uint256 amount0,
        string calldata remark
    ) external;
//双币充值
function multiRecharge(
        address token0, 
        address token1, 
        uint256 amount0, 
        uint256 amount1, 
        string calldata remark
    ) external;

```
