### install foundry-rs/forge-std
```shell
$ forge install foundry-rs/forge-std --no-commit --no-git
```
### install openzeppelin-contracts
```shell
$ forge install openzeppelin/openzeppelin-contracts --no-commit --no-git
```

### install openzeppelin-contracts-upgradeable
```shell
$ forge install openzeppelin/openzeppelin-contracts-upgradeable --no-commit --no-git
```

### deploy wallet
```shell
$ forge script script/Deploy.s.sol -vvv --rpc-url=https://bsc.blockrazor.xyz --broadcast --private-key=[privateKey]
```
### usdt:0x55d398326f99059fF775485246999027B3197955
### gather:0x2D752A0F06F8b0E5aA652484A1Cd32bb6b71176A
### abi:./out/Gather.sol/Gather.json
----------------------------------------------------
### recharge func list:
```solidity
//0无效，1社区节点，2超级节点
enum NodeType{INVALID, SMALL, LARGE}
//获取节点价格
function nodePrice(NodeType nodeType) external view returns(uint256);
//获取用户的节点身份，如果是0则可以购买，否则不允许购买因为已经购买过了
function userInfo(address user) external view returns(NodeType);
//购买节点，这里参数是节点类型，1/2
function buyNode(NodeType nodeType) external;
```
