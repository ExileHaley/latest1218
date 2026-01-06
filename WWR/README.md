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

#### finance:

#### finance func list
```solidity
//获取首码地址
function initialCode() external view returns(address);
//合约总共收入usdt数量
function totalUsdtAmount() external view returns(uint256);
//0无效、1大使节点、2理事节点、3股东节点
enum Category{INVALID, ENVOY, DIRECTOR, SHARE}
//获取不同节点对应的价格
function price(Category category) external view returns(uint256);
//验证addr该地址是否有邀请资格
function validInvitationCode(address addr) external view returns(bool);
//邀请，_recommender邀请人地址进行关系绑定
function referral(address _recommender) external;
//质押，这里选择不同的节点
function stake(Category category) external;
//获取用户信息
function getUserInfo(address user) external view 
    returns(
        Category category, //节点类型
        address  recommender, //邀请人地址
        uint256  amount, //当前用户的USDT数量
        uint256  performance, //当前用户的伞下业绩，单位usdt
        uint256  envoyNums, //伞下大使节点人数
        uint256  directorNums, //伞下理事节点人数
        uint256  shareNums //伞下股东节点人数
    );

struct DirectReferralsInfo{
    Category category; //节点类型
    address referral; //地址
    uint256 performance; //伞下业绩
}
//返回直推地址以及信息
function getDirectReferralsInfo(address user) 
    external 
    view 
    returns (DirectReferralsInfo[] memory) 
```