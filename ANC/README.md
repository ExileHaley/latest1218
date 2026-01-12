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

#### FarmCore.sol
- 管理用户质押状态：userInfo
- 管理 stake / withdraw
- 结算 ANC 奖励（pendingAnc）
- 只和 FarmReferral / FarmNode / FarmToday 通过外部接口通信

#### FarmReferral.sol
- 管理推荐关系：referralInfo
- 管理直推列表：directReferralAddrSets
- 管理层级奖励：_processUpline
- 提供外部接口让 FarmCore 在 stake 时调用更新奖励

#### FarmNode.sol
- 管理节点奖励池：cumulateAwardForNode
- 管理节点地址集合
- 提供外部接口让 FarmCore / FarmReferral 发放奖励

#### FarmToday.sol
- 管理每日直推地址和当日 top6 逻辑
- 提供方法计算每日 top6 奖励并发放
- 提供接口供 FarmCore 更新每日业绩