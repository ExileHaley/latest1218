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

### 查看未执行执行nonce
```shell
$ cast nonce [wallet-address] --rpc-url https://bsc.blockrazor.xyz
```

#### 映射钱保持不能入金和提现的状态，批量给地址判断没映射的手动进行映射,给一个状态判断是否进行了映射


#### DJS token address:
#### staking address:


#### staking func list
```solidity

```
```
时间轴: t0 -------- t1 -------- t2 -------- t3

说明:
- t0: 上次全局 SHARE 奖励结算时间 (lastShareAwardTime)
- t1: 用户 stake / referral / 任何操作，触发 getShareLevelAward
- t2: 当前时间 (block.timestamp)
- t3: 下一次 claim 或 updateShareFram

流程:

t0: lastShareAwardTime
    └─ perSharePerformanceAward = X
t1: 用户 stake 或 claim
    ├─ delta = t1 - t0
    ├─ totalShareAward = totalStakedUsdt * delta * perSecondStakedAeward * shareRate / 100
    ├─ acc = perSharePerformanceAward + totalShareAward / totalSharePerformance
    ├─ reward = r.performance * acc / decimals
    ├─ finalReward = reward - shareAwardDebt
t2: 用户 claim 奖励
    ├─ 更新 shareAwardDebt = acc * r.performance
    ├─ 更新 extracted / pendingProfit
t3: 下一次 getShareLevelAward
    └─ 同样按照新的 lastShareAwardTime / perSharePerformanceAward / delta 计算
```
