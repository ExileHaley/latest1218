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
#### USDT测试代币;0xa738c5B0EAa2dDa253764Ae6e42a1aF636b191Ac
#### ANC 代币:0x3E581a43b5f217C33aeeeC7CF47681549860b166
#### ANC pancakePair:0x0180dE14F352b9e8A5389f0aC52C1bD0D5b0a720
==================================================================================================
#### liquidityManager:0x33D29c4063d05ebc0652C3E7e531464067618fE2
#### farmReferral:0xF8983d197bA821b586fb1C648fD09Fd040299081
#### farmToday:0x90ca38C522cF04184590C15Ec585181bAcFaca5C
#### farmNode:0x4fc705bd61846D5558a5e84A46CE7F486EE03689
==================================================================================================
#### farmCore:0xf22403662942E612F3C361cEdC1df0724bf32783
#### farmView:0xe8B2aC974C29ce5d093E47388C1EF45051450FDf
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
//奖励记录分成三个列表切换展示最好
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
    Process.NodeType nodeType,  //节点类型，必须展示
    uint256 stakingUsdt,        //所有订单总共质押的usdt数量，这个是算力确认文案后必须展示
    StakingOrder[] memory orders,//当前用户的订单列表，必须展示
    address recommender,        //当前用户的邀请人地址，必须展示
    uint256 overallPerformance, //当前用户的总业绩，必须展示，这是总业绩包含小区业绩在内
    uint256 effectivePerformance,//当前用户的小区业绩，必须展示，用户奖励数据都根据该数据分发
    uint256 referralNum,         //当前用户的邀请总人数，伞下总人数，按需求决定是否展示
    uint256 ancAward,           //当前用户可提取的anc收益，可提取，必须展示
    uint256 usdtAward           //当前用户可提取的usdt数量，可提取，必须展示
);
function getUserOtherInfo(address user) external view returns(
    uint256 todayAward,     //如果英雄榜该地址得到了usdt奖励，只展示
    uint256 nodeAward,      //如果是节点，则会产生node usdt奖励，只展示
    uint256 referralAward,  //邀请层级奖励+2万usdt小区业绩达标的奖励，只展示
    bool isRankAnc,         //是否达到2万usdt小区业绩可以参与usdt奖励，做个标识，标识必须展示跟项目方确认文案
    bool isRankUsdt         //是否达到5万usdt小区业绩可以参与该项anc奖励，做个标识，标识必须展示跟项目方确认文案
);

//英雄榜信息
struct Today{
    address user;   //地址
    uint256 performance;    //当日邀请业绩
}
//获取今日英雄榜的参与者以及业绩，这里可以截取前10条展示，不用展示全部
function getTodayTopInfo() external view returns(Process.Today[] memory);


```
