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
$ forge script script/Deploy.s.sol -vvv --rpc-url=https://rpc.naaidepin.co --broadcast --private-key=[privateKey]
```


#### gas:0x43c8bc6149D3D29Be2B676cB51667c9be15B7e94
#### x101:0xe102277ec9716c276B632Ab93A2860E0286982BC
#### recharge contract:0x38A072f3dAb35e5Fc2139A7751bbf31DD2C3a419
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

//余额查询
struct Info{
        address user; //钱包地址
        uint256 amount; //token在该钱包中的数量
    }
function multiBalanceOf(address token, address[] calldata users) external view returns (Info[] memory);
//获取token的价格，address交易对代币，uint256价格有精度
function getPrice(address token) external view returns(address, uint256);
//获取授权数量token代币地址，owner钱包地址，spender接收授权的合约地址
function getAllowance(address token, address owner, address spender) public view virtual returns (uint256);
```