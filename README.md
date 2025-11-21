# LOVE20 链群（基于 ERC721 标准）

基于 LOVE20 core 协议的生态衍生协议

## 特性

### 核心功能

- 永久存在：链群一旦建立，永久存在
- 唯一性保证：每个链群名称全局唯一，不可重复铸造
- NFT 资产化：基于 ERC721 标准，支持自由转让和交易
- 动态定价：铸造成本随 LOVE20 供应量动态调整
- 名称激励：短名称需要更高成本，鼓励有意义的长名称
- 完整枚举：支持 ERC721Enumerable 扩展，可遍历所有链群
- 灵活配置：关键参数可在部署时配置，适应不同场景需求

## 应用场景

- 链群所有权管理：代表链群的唯一身份和所有权凭证
- 权益转让：通过 NFT 转让实现链群经营权、收益权的流转
- 生态集成：为 LOVE20 生态中的群类协议提供统一的身份系统
- 价值发现：稀缺和有意义的链群名称可能具有市场价值

## 铸造

任何人都可以支付一定数量的 LOVE20 代币，来铸造一个独一无二的链群，并在任何支持此协议的群类扩展协议中，行使群主的权力

铸造时需提供一个未铸造过的链群名称

### 链群名称规则

链群名称需遵循以下验证规则：

- ✅ 长度限制：1-64 字节（UTF-8 编码）
- ✅ 支持字符：字母、数字、特殊符号、中文等 Unicode 字符
- ❌ 禁止内容：
  - 空名称或超过 64 字节的名称
  - 任何位置的空格字符（包括 ASCII 空格和所有 Unicode 空格）
  - 控制字符（如换行符 `\n`、制表符 `\t` 等）
  - 零宽字符（U+200B-U+200F、U+034F、U+FEFF、U+2060、U+00AD）

**被禁止的空格字符包括：**

- ASCII 空格 (U+0020)
- 不换行空格 (U+00A0)
- Ogham 空格标记 (U+1680)
- En/Em 空格系列 (U+2000-U+200A)
- 窄不换行空格 (U+202F)
- 中等数学空格 (U+205F)
- 中文全角空格 (U+3000)

安全特性：系统实现了完整的字符验证，有效防止控制字符注入、零宽字符混淆、视觉欺骗等攻击。

详细规则请参考 [链群名称校验规则](./docs/链群名称校验规则.md)

### 铸造费用

每次铸造需支付一定数量的 LOVE20 代币给到合约，计算公式如下：

铸造基础费用 = LOVE20 剩余未铸造量 / 10^8

对于链群名称字节数 >= 10 字节，只收取基础费用
对于链群名称字节数 < 10 字节的，每比 10 字节少 1 个字节，则所需代币数量 \* 10

例如，当 LOVE20 剩余未铸造量为 80 亿时，不同链群名称字节数对应的铸造费用如下：

| 字节数 | 铸造需 LOVE20 个数 |
| ------ | ------------------ |
| 12     | 80                 |
| 10     | 80                 |
| 8      | 8,000              |
| 6      | 800,000            |
| 4      | 80,000,000         |

⚠️ **注意**：字节数 1-3 的极短名称铸造成本极高（远超 LOVE20 最大供应量），实际上无法铸造。这是有意的设计，鼓励使用更有意义的长名称。

字符与字节参考：

- 英文字母、数字、常见符号：占用 1 个字节（与 ASCII 兼容）
- 欧洲、中东等语言的大部分字符：占用 2 个字节
- 中文、日文、韩文等（CJK）字符：占用 3 个字节
- 一些非常罕见的字符、表情符号：可能占用 4 个字节

## 合约部署

### 前置要求

1. 安装 [Foundry](https://book.getfoundry.sh/getting-started/installation)
2. 配置网络参数和账户信息

### 网络配置

在 `script/network/<网络名称>/` 目录下需要以下配置文件：

- `.account` - 账户配置（keystore 账户名和地址）
- `network.params` - 网络参数（RPC URL、链 ID、区块浏览器配置等）
- `group.params` - Group 完整配置（LOVE20 地址、合约参数）
- `address.group.params` - Group 合约地址（部署后自动生成）

#### Group 配置说明

`group.params` 是唯一需要的配置文件，包含所有部署参数：

```bash
# LOVE20 Token 地址（必需）
LOVE20_TOKEN_ADDRESS=0x...

# 合约参数（可选，有默认值）
BASE_DIVISOR=100000000        # 基础除数（1e8），用于计算铸造成本
BYTES_THRESHOLD=10            # 字节阈值，名称 >= 此长度只需基础费用
MULTIPLIER=10                 # 倍数，每少于阈值 1 字节，成本乘以此值
MAX_GROUP_NAME_LENGTH=64      # 链群名称最大长度（字节）
```

**注意**：所有参数在合约部署时设置，部署后永久不可更改。

项目已包含以下网络配置：

- `anvil` - 本地测试网络
- `thinkium70001_public` - Thinkium 主网
- `thinkium70001_public_test` - Thinkium 测试网

### 一键部署

进入部署脚本目录并执行：

```bash
cd script/deploy
source one_click_deploy.sh <网络名称>
```

例如，部署到 Thinkium 主网测试：

```bash
source one_click_deploy.sh thinkium70001_public_test
```

部署脚本会自动完成以下步骤：

1. **初始化环境** - 加载网络配置和账户信息
2. **部署合约** - 部署 Group 合约并保存地址
3. **验证合约** - 在区块浏览器上验证合约源码（仅 Thinkium 网络）
4. **检查配置** - 验证合约部署正确性

### 分步部署

如果需要单独执行某个步骤：

```bash
cd script/deploy

# 1. 初始化环境
source 00_init.sh <网络名称>

# 2. 部署 Group 合约
forge_script_deploy_group

# 3. 验证合约（仅 Thinkium 网络）
source 03_verify.sh

# 4. 检查部署
source 99_check.sh
```

### 查询信息

使用 `cast` 命令查询合约信息：

```bash
# 设置变量（可选，方便后续使用）
groupAddress=0x...  # Group 合约地址
RPC_URL=https://proxy1.thinkiumrpc.net

# 查询合约基本信息
cast call $groupAddress "name()(string)" --rpc-url $RPC_URL
cast call $groupAddress "symbol()(string)" --rpc-url $RPC_URL
cast call $groupAddress "love20Token()(address)" --rpc-url $RPC_URL
cast call $groupAddress "totalSupply()(uint256)" --rpc-url $RPC_URL

# 查询特定 token 信息
cast call $groupAddress "ownerOf(uint256)(address)" 1 --rpc-url $RPC_URL
cast call $groupAddress "groupNameOf(uint256)(string)" 1 --rpc-url $RPC_URL

# 查询链群名称是否已被使用
cast call $groupAddress "isGroupNameUsed(string)(bool)" "MyGroup" --rpc-url $RPC_URL

# 通过名称查询 token ID
cast call $groupAddress "tokenIdOf(string)(uint256)" "MyGroup" --rpc-url $RPC_URL

# 计算铸造成本
cast call $groupAddress "calculateMintCost(string)(uint256)" "MyGroup" --rpc-url $RPC_URL
```

### 铸造

使用 `cast` 命令铸造链群：

````bash
# 设置变量
groupAddress=0x...             # Group 合约地址
LOVE20_TOKEN_ADDRESS=0x...     # LOVE20 token 地址
GROUP_NAME="YourGroup"         # 链群名称
RPC_URL=https://proxy1.thinkiumrpc.net

# 1. 计算铸造成本
MINT_COST=$(cast call $groupAddress "calculateMintCost(string)(uint256)" "$GROUP_NAME" --rpc-url $RPC_URL)
echo "Mint cost: $MINT_COST"

# 2. 批准 LOVE20 代币（使用 keystore 账户）
cast send $LOVE20_TOKEN_ADDRESS \
  "approve(address,uint256)" \
  $groupAddress $MINT_COST \
  --rpc-url $RPC_URL \
  --account myaccount \
  --gas-price 5000000000 \
  --legacy

# 3. 铸造链群
cast send $groupAddress \
  "mint(string)(uint256)" \
  "$GROUP_NAME" \
  --rpc-url $RPC_URL \
  --account myaccount \
  --gas-price 5000000000 \
  --legacy

## 开发

### 运行测试

```bash
forge test
````

### 编译合约

```bash
forge build
```
