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

  
==================================================================================================
#### USDT测试代币;0xc0Ac74c92e1ce9100316156cf80b3809d63Be4dA
#### ANC 代币:0x73587A63886CCAA7D59E3Dc53EA2272fab85253A
#### ANC pancakePair:0x6eE140Aff07B5B3556CC773a286D6c2DcbC423C1
==================================================================================================
#### liquidityManager:0xb5e9E6E2E749Cba23C4A3e5126CDe88Ce08B9155
#### farmReferral:0x9B2DfA8ff3c44D928085c9208B5B9430eC66dc3B
#### farmToday:0x42Fa8067d9948D6cB0EFDf6F8Ed5F822414998Fc
#### farmNode:0x348E9C4D8049a29FA97f970427d293dcbb6c5ab3
==================================================================================================
#### farmCore:0x63480bcdBC30EEDa70308F10c39585F61CAf29c7
#### farmView:0x2E43f55F4E54b624d31E84200fd51ee01B2b5940
==================================================================================================
### farmCore func list:
```solidity
//邀请recommender，参数是邀请人地址
function referral(address recommender) external;
//质押，amountUsdt是usdt的数量，100个usdt起步
function stake(uint256 amountUsdt) external;
//提取usdt收益
function claimUsdt() external;
//提取anc收益
function claimAnc() external;
//赎回，
//getUserInfo里StakingOrder[] memory orders,//当前用户的订单列表，
//这里idx是数组的下标
function redeem(uint256 idx) external;


//下面是两个管理员方法
//添加邀请关系，users的所有邀请人都是recommender
function referralForAdmin(address recommender, address[] memory users) external;
//添加节点，nodeType类型，1/2/3=小节点/中节点/大节点，users地址用户数组，liquidity是给每个地址分配的lp数量
function addNodeForAdmin(Process.NodeType nodeType, address[] calldata users, uint256 liquidity) external;

```

==================================================================================================

### farmView func list
```solidity
//获取首码地址
function getInitialCode() external view returns(address);
//判断当前地址是否有邀请资格
function eligibilityCode(address user) external view returns(bool);

//无效0，usdt1，anc2
enum Token {INVALID, USDT_TOKEN, ANC_TOKEN}
struct Record {
    Token token;    //代币奖励种类
    address from;   //奖励来源地址
    uint256 amount; //奖励数量
    uint256 time;   //奖励时间
}
//获取不同类型的奖励记录，都要展示
function getAwardRecord(address user) external view returns(
    Process.Record[] memory node,   //节点奖励的记录
    Process.Record[] memory today,  //英雄榜奖励的记录
    Process.Record[] memory invite  //邀请奖励的记录
);

//直推用户信息
struct Info{
    address user;   //地址
    uint256 stakingUsdt;//质押的usdt数量
    uint256 overall;    //伞下总业绩
    uint256 effective;  //伞下小区业绩
}
//获取直推地址的信息，这里直推人数通过这个数组长度获取一下
function getDirectReferralAddrInfo(address user) external view returns(Process.Info[] memory infos);


//无效0，小节点1、中节点2、大节点3
enum NodeType { INVALID, SMALL, MEDIUM, LARGE }
//订单
struct StakingOrder{
    uint256 stakingUsdt;        //质押的usdt数量
    uint256 stakingLiquidity;   //质押usdt产生的流动性代币数量
    uint256 stakingTime;        //质押时间
    bool    withdrawn;          //当前订单是否已经赎回
}

//获取用户信息
function getUserInfo(address user) external view returns(
    Process.NodeType nodeType,  //节点类型
    uint256 stakingUsdt,        //所有订单总共质押的usdt数量
    StakingOrder[] memory orders,//当前用户的订单列表
    address recommender,        //当前用户的邀请人地址
    uint256 overallPerformance, //当前用户的总业绩
    uint256 effectivePerformance,//当前用户的小区业绩
    uint256 referralNum,         //当前用户的邀请总人数，伞下总人数
    uint256 ancAward,           //当前用户可提取的anc收益，可提取
    uint256 usdtAward           //当前用户可提取的usdt数量，可提取
);
function getUserOtherInfo(address user) external view returns(
    uint256 todayAward,     //如果英雄榜改地址得到了usdt奖励，只展示
    uint256 nodeAward,      //如果是节点，则会产生node usdt奖励，只展示
    uint256 referralAward,  //邀请层级奖励+2万usdt小区业绩达标的奖励，只展示
    bool isRankAnc,         //是否达到2万usdt小区业绩，参与该项usdt奖励，做个标识
    bool isRankUsdt         //是否达到5万usdt小区业绩，参与该项anc奖励，做个标识
);

//英雄榜信息
struct Today{
    address user;   //地址
    uint256 performance;    //当日邀请业绩
}
//获取今日英雄榜的参与者以及业绩
function getTodayTopInfo() external view returns(Process.Today[] memory);


```
