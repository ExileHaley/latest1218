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
$ forge script script/DeployExchange.s.sol -vvv --rpc-url=https://bsc.blockrazor.xyz --broadcast --private-key=[privateKey]
```

### 更新ABI，getDirectReferralInfo方法返回结构体字段有变化

### contract address
-----------------------------------------------------------------------------------
#### USDT:0x55d398326f99059fF775485246999027B3197955
-----------------------------------------------------------------------------------
#### DJS:0xf273F77b4b88bB85E884a0E4521Cc091276B8cAE
-----------------------------------------------------------------------------------
#### Djs`s pancakePair:0xa8147eceCc3aCb7C3B9DbD6744C8844125B16F9D
-----------------------------------------------------------------------------------
#### DJSC:0x224575A57B7e5dC086D1D54ECdE4Bc92c5044260
-----------------------------------------------------------------------------------
#### Djsc`s pancakePair: 0x7df5a8b3e248627A4F43d89D4DA875a17D5c931b
-----------------------------------------------------------------------------------
-----------------------------------------------------------------------------------
#### finance:0x4c5ce1c4994225eD159efB36C9bd720c0F2caa99
-----------------------------------------------------------------------------------
#### financeView:0xCf633eBa368E41e28B11F5259dE74Ce37E972968
-----------------------------------------------------------------------------------
#### liquidityManager:0xC93C6201d0d16DD246198098AF92236890b7565F
-----------------------------------------------------------------------------------
#### nodeDividends:0x24629495Bfd635a50B105efd602b104139eF2F8B
-----------------------------------------------------------------------------------
#### Exchange:0x87924102384beEA7c10553283bE3b32BA8a7deB7
-----------------------------------------------------------------------------------

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
        uint256 staking; //用户质押数量
        uint256 performance; //用户伞下业绩
}
function getDirectReferralInfo(address user) external view returns(Process.Info[] memory);

//兑换子币，amountUSDT是usdt的数量，子币额度subCoinQuota
function swapSubToken(uint256 amountUSDT) external;

//管理员方法，用于提取指定数量的token到指定地址
function emergencyWithdraw(address _token, uint256 _amount, address _to) external;

//amountUSDT传入usdt的数量，返回预估兑换djsc的数量
function getAmountOut(uint256 amountUSDT) external view returns(uint256);

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
        uint256 directNum     //直推人数
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

### liquidityManager func list
```solidity
//获取管理员地址
function admin() external view returns(address);
//如果是管理员地址展示这个页面让管理员操作提现
//_token代币合约地址
//_amount要提现的数量对应
//_to接收者地址
function emergencyWithdraw(address _token, uint256 _amount, address _to) external;

```

### Exchange func list
#### 本合约用于卖出DJS，DJS对本合约进行授权才能进行卖出
```solidity
//兑换，amountDJS是DJS的数量，将指定数量的DJS兑换为USDT
function exhcange(uint256 amountDJS) external;
//查询兑换价格，输入DJS的数量amountDJS，返回兑换USDT的结果大概多少个
function getAmountsOut(uint256 amountDJS) external view returns (uint256);
```