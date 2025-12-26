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

### deploy wallet
```shell
$ forge script script/Deploy.s.sol -vvv --rpc-url=https://bsc.blockrazor.xyz --broadcast --private-key=[privateKey]
```

1.添加lp，以第一个输入的代币数量为主，推两个币的数量和lp的数量
2.提现的时候，移除流动性，代币单独提现

3.同时质押两个代币，每个代币有不同的分发方式，分发比例不一样，推两个币的数量

4.代币合约升级，黑洞地址要改dead

5.后端升级，获取授权数量

lp接收地址、lp算力/联合算力提现地址，联合算力目前两个代币对应分发的3、5个地址




1.代币合约更新，卖出销毁比例可调，用户100%到账，避免大阴线
2.合约添加lp、移除lp
3.合约新增双代币充值，不同代币对应不同的分发规则
4.后端服务新增lp提现接口、授权数量查询接口
5.我给你一个兑换接口，服务端给你一个推送，落库