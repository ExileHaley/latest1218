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

### contract address
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
#### 测试USDT:0xD744485222365dFA77c4c0D139b7916d4e850C43
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
#### DJS:0x6E0630474F817d295889a4DA08bbDb62CcD651aB
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
#### Djs`s pancakePair:0x6D4cb753592EAc693967086C0560c4bE96175475
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
#### DJSC:0x308F6D620657E769c9632c5432c9af88D6dc404B
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
#### Djsc`s pancakePair:0x306092398dEB06F1848575558f63C9e0FBFDDcd2
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
#### finance(finance.json):0xB47f3802b718215847F53076276653a6CbdaB415
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
#### financeView(financeView.json):0x4754fd62BaF1470bE92F0D2266B193805D4eBA26
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
#### liquidityManager:0xA0c9FF380fFCBF3bedb243A0b3107c3495f76ddC
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
#### nodeDividends(nodeDividends.json):0xed051dea7FAF2B6c69aE80DFA34C8Ab8C5d70cDB
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------


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

enum Category {DIRECT, NORMAL_LEVEL, SHARE_LEVEL}

struct Record{
        Category category; //奖励类别, 0代表直推，1代表D0-D5节点收益、2代表股东节点收益
        address from;   //奖励来源于谁的质押
        uint256 amount; //奖励数量
        uint256 time;   //获得奖励的时间
}
//获取用户的邀请奖励记录
function getReferralAwardRecords(address user) external view returns(Record[] memory);

struct Info{
        address user; //直推地址
        uint256 amount; //直推地址对应的伞下业绩+自身质押
}
function getDirectReferralInfo(address user) external view returns(Process.Info[] memory);

//兑换子币，amountUSDT是usdt的数量，子币额度subCoinQuota
function swapSubToken(uint256 amountUSDT) external;

//管理员方法，用于提取指定数量的token到指定地址
function emergencyWithdraw(address _token, uint256 _amount, address _to) external;



```

### financeView func list:
```solidity
//获取用户基础信息
function getUserInfoBasic(address user) public view returns(
        uint256 stakingUsdt, //质押数量
        uint256 extracted,   //已释放数量
        uint256 remaining,   //剩余未来可以释放的数量
        uint256 stakingAward, //静态收益
        uint256 extractable,  //总共可提取数量
        uint256 referralAward, //邀请奖励，包括直推和D0-D5的收益
        uint256 shareAward     //股东节点收益
);

//获取用户邀请信息
function getUserInfoReferral(address user) external view returns (
        Process.Level level,   //等级，0(DO普通用户) 1(D1等级1) 2(D2等级2) 3(D3等级3) 4(D4等级4) 5(D5等级5) 6(SHARE股东等级)
        address recommender,   //当前用户的邀请地址
        uint256 referralNum,   //当前用户总共邀请了多少人
        uint256 performance,   //当前用户伞下邀请的总业绩
        uint256 subCoinQuota,  //当前用户的子币额度
);
```

### nodeDividends func list
```solidity
//用户质押NFT，tokenIds传入nft的tokenId，这里允许多个NFT质押，所以是数组参数
function stake(uint256[] calldata tokenIds) external;
//根据订单编号orderId获取订单信息
function getOrderInfo(
        uint256 orderId
    ) external view returns (
        uint256 nftQuantity, //改订单拥有的NFT数量
        uint256[] memory tokenIds, //改订单质押的NFT tokenId的编号
        uint256 tokenQuota, //获得的代币额度djs
        uint256 stakingTime, //订单质押时间
        uint256 extracted, //当前订单已被提取的djs
        uint256 extractable, //当前订单可提取的djs
        uint256 countDown //当前订单倒计时s
    );
//提取订单收益djs，默认提取全部
function claimOrderAward(uint256 orderId) external;
//提取用户的USDT分红，默认提取全部
function claimUserUSDT() external;
//获取用户信息
function getUserInfo(
        address user
    ) external view returns (
        uint256 amountNFT, //用户所有订单一共质押的NFT数量
        uint256[] memory allOrders, //用户质押的所有订单编号
        uint256 awardUSDT //用户可以提取的USDT分红数量
    );
//在getUserInfo中拿到用户质押的所有订单，在这个方法中进行判断，判断订单是否结束
//结束就是当前订单的所有收益已经全部被提取
function isOrderFinished(uint256 orderId) public view returns (bool);

```
