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
#### test usdt token:0x3c83065B83A8Fd66587f330845F4603F7C49275c
#### djs token:0x75B8c892FC65fFF466a7b84A5c5b8aC8ec1395A5
#### djsc token:0x101FF1333e9776D2D39a400287c945221a20d676

#### liquidityManager contract:0x76076ED15b607c75Ed950084283cA342d5CbF9F9
#### nodeDividends contract:0x72B25b3F17598AAdeB315Ea82Bbaa7804374bA98
#### finance contract:0xeA7eB2F853b23450798a3A98c94C8fd6Cd029dD1

### finance func list
```solidity
//查询管理员地址
function admin() external view returns(address);
//查询首码地址
function initialCode() external view returns(address);
//查询理财合约总的理财usdt数量
function totalStakedUsdt() external view returns(uint256);
//判断是否要从DJSV1版本迁移
function whetherNeedMigrate(address user) public view returns(bool);
//从DJSV1版本迁移邀请关系，user是当前用户
function migrationReferral(address user) external;
//判断当前地址是否可以邀请下级
function validReferralCode(address user) external view returns(bool);
//绑定邀请关系，recommender邀请人地址，如果不是initialCode，则需要recommender有理财才可以邀请否则报错
function referral(address recommender) external;
//用户使用usdt进行理财，amountUSDT是usdt的数量
function stake(uint256 amountUSDT) external;
//用户提取收益，默认提取全部收益不需要参数
function claim() external;
//获取用户真实有效可提取收益
function getUserAward(address user) public view returns(uint256);
//获取用户股东收益，只展示不用于提现
function getUserShareLevelAward(address user) public view returns(uint256);
//获取用户固定理财收益，只展示不用于提现
function getUserStakingAward(address user) public view returns(uint256);
struct Record{
        address from;   //奖励来源于谁的质押
        uint256 amount; //奖励数量
        uint256 time;   //获得奖励的时间
}
//获取用户的邀请奖励记录
function getReferralAwardRecords(address user) external view returns(Record[] memory);
//获取用户的直接推荐地址，有质押才能算有效邀请，否则不会展示
function getDirectReferrals(address user) external view returns(address[] memory);
//获取用户基础信息
function getUserInfoBasic(address user) public view returns(
        Process.Level level, //等级
        address recommender, //邀请人
        uint256 stakingUsdt, //理财usdt数量
        uint256 multiple,    //倍数
        uint256 totalAward,  //可提取收益
        uint256 shareAward   //股东收益
);
//获取用户的邀请信息
function getUserInfoReferral(address user) external view returns (
        uint256 referralNum, //邀请人数。只有质押后才会被计算为有效邀请
        uint256 performance, //当前用户的伞下业绩，单位usdt
        uint256 referralAward,//当前用户的邀请奖励，单位usdt
        uint256 subCoinQuota, //当前用户的子币额度，单位是usdt
        bool    isMigration //当前用户是否已经迁移，这个忽略
);
//兑换子币，amountUSDT是usdt的数量，子币额度subCoinQuota
function swapSubToken(uint256 amountUSDT) external;


//管理员方法，用于提取指定数量的token到指定地址
function emergencyWithdraw(address _token, uint256 _amount, address _to) external;


```

### nodeDividends func list
```solidity
//质押NFT，tokenIds是nft的tokenId数组列表
function stake(uint256[] memory tokenIds) external;
//获取可提取的djs(claimable)，已经释放数量(released)
function getReleaseAmountToken(address user)
        public
        view
        returns (uint256 released, uint256 claimable);
//获取可提取的usdt数量
function getAvailableAmountUSDT(address user) public view returns(uint256);
//提取djs
function claimToken(uint256 amountToken) external;
//提取usdt
function claimUSDT() external;
//获取用户信息
function getUserInfo(address user) 
        external 
        view 
        returns (
            uint256 nftQuantity,        //NFT数量
            uint256[] memory tokenIds,  //tokenId质押列表
            uint256 releaseQuota,       //已经释放的额度
            uint256 stakingTime,        //质押时间
            uint256 pendingToken,       //忽略
            uint256 pendingUSDT,        //忽略
            uint256 extractedToken,     //已提取djs数量
            uint256 farmDebt,           //忽略
            uint256 claimableToken,     //可提取的djs数量
            uint256 availableUSDT       //可提取的usdt数量
        );
```