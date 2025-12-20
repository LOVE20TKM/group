# Group 部署脚本使用指南

本目录包含 Group 合约的部署和验证脚本。

## 目录结构

```
deploy/
├── 00_init.sh              # 环境初始化脚本
├── one_click_deploy.sh     # 一键部署脚本
├── 03_verify.sh            # 合约验证脚本
├── 99_check.sh             # 部署检查脚本
└── README.md               # 本文档
```

## 前置要求

### 1. 安装依赖

- [Foundry](https://book.getfoundry.sh/getting-started/installation) - Solidity 开发工具链
- [cast](https://book.getfoundry.sh/cast/) - Foundry 命令行工具（随 Foundry 一起安装）

### 2. 网络配置

在 `script/network/<网络名称>/` 目录下需要以下文件：

#### `.account` (示例)

```bash
KEYSTORE_ACCOUNT=myaccount
ACCOUNT_ADDRESS=0x1234567890123456789012345678901234567890
```

#### `network.params` (示例)

```bash
# Network
SECONDS_PER_BLOCK=3.2
RPC_URL=https://proxy1.thinkiumrpc.net

# Contract Verify (可选，用于合约验证)
CHAIN_ID=70001
VERIFIER=blockscout
VERIFIER_URL=http://chain1.thinkiumscan.net/api/v2
```

#### `group.params` (示例)

```bash
# Group Contract Configuration

# LOVE20 Token Address (required)
LOVE20_TOKEN_ADDRESS=0xaCE196081461beFCCDfB392A0B535A750078b2Aa

# Contract Parameters
BASE_DIVISOR=100000000
BYTES_THRESHOLD=8
MULTIPLIER=10
MAX_GROUP_NAME_LENGTH=64
```

#### `address.group.params`

```bash
# 部署后自动生成，初始为空
groupAddress=
```

### 3. Keystore 账户

部署脚本使用 Foundry 的 keystore 功能进行账户管理。

创建 keystore 账户：

```bash
cast wallet import myaccount --interactive
```

查看已有账户：

```bash
cast wallet list
```

## 使用方法

### 方式一：一键部署（推荐）

```bash
cd script/deploy
source one_click_deploy.sh <网络名称>
```

例如：

```bash
# 部署到 Thinkium 测试网
source one_click_deploy.sh thinkium70001_public_test

# 部署到 Thinkium 主网
source one_click_deploy.sh thinkium70001_public

# 部署到本地 Anvil
source one_click_deploy.sh anvil
```

一键部署会自动完成：

1. 环境初始化和参数加载
2. Group 合约部署
3. 合约源码验证（仅 Thinkium 网络）
4. 部署配置检查

### 方式二：分步部署

#### Step 1: 初始化环境

```bash
cd script/deploy
source 00_init.sh <网络名称>
```

这将：

- 加载网络配置
- 加载账户信息
- 设置 LOVE20 token 地址
- 请求 keystore 密码
- 定义辅助函数（`forge_script`, `cast_call`, `check_equal` 等）

#### Step 2: 部署 Group 合约

```bash
forge_script_deploy_group
```

这将：

- 部署 Group 合约
- 自动保存合约地址到 `script/network/<网络名称>/address.group.params`
- 显示部署摘要

#### Step 3: 验证合约（可选，仅 Thinkium 网络）

```bash
source 03_verify.sh
```

这将在区块浏览器上验证合约源码，使其可读。

#### Step 4: 检查部署

```bash
source 99_check.sh
```

这将验证：

- Group 合约的 LOVE20_TOKEN_ADDRESS 地址是否正确
- 合约名称和符号
- 当前总供应量

## 脚本详解

### 00_init.sh - 环境初始化

**主要功能：**

- 验证并加载网络配置
- 导出环境变量（`network`, `LOVE20_TOKEN_ADDRESS` 等）
- 请求 keystore 密码（仅一次）
- 定义常用函数

**导出的环境变量：**

- `network` - 网络名称
- `network_dir` - 网络配置目录路径
- `LOVE20_TOKEN_ADDRESS` - LOVE20 token 地址
- `KEYSTORE_PASSWORD` - Keystore 密码（session 期间保留）
- 以及 `network.params` 中的所有变量

**定义的函数：**

1. `cast_call(address, function_signature, ...args)` - 调用合约只读函数
2. `check_equal(description, expected, actual)` - 比较两个值是否相等
3. `forge_script(...)` - 执行 Foundry 脚本（带默认参数）
4. `forge_script_deploy_group()` - 部署 Group 合约

### one_click_deploy.sh - 一键部署

依次执行：

1. 环境初始化（`00_init.sh`）
2. 合约部署（`forge_script_deploy_group`）
3. 合约验证（`03_verify.sh`，仅 Thinkium 网络）
4. 部署检查（`99_check.sh`）

### 03_verify.sh - 合约验证

**仅支持：** Thinkium 网络（`thinkium70001*`）

使用 Foundry 的 `forge verify-contract` 命令在区块浏览器上验证合约源码。

### 99_check.sh - 部署检查

验证合约部署的正确性：

- 检查 LOVE20_TOKEN_ADDRESS 地址是否正确
- 显示合约名称、符号和总供应量

## 使用 Cast 命令与合约交互

部署后，你可以使用 `cast` 命令直接与合约交互，无需编写 Solidity 脚本。

### 查询合约（只读操作）

```bash
# 加载环境
source 00_init.sh <网络名称>
source $network_dir/address.group.params

# 使用便捷函数 cast_call（已在 00_init.sh 中定义）
cast_call $groupAddress "name()(string)"
cast_call $groupAddress "symbol()(string)"
cast_call $groupAddress "totalSupply()(uint256)"
cast_call $groupAddress "LOVE20_TOKEN_ADDRESS()(address)"

# 查询特定 token
cast_call $groupAddress "ownerOf(uint256)(address)" 1
cast_call $groupAddress "groupNameOf(uint256)(string)" 1

# 查询链群名称
cast_call $groupAddress "isGroupNameUsed(string)(bool)" "MyGroup"
cast_call $groupAddress "tokenIdOf(string)(uint256)" "MyGroup"

# 计算铸造成本
cast_call $groupAddress "calculateMintCost(string)(uint256)" "MyGroup"
```

### 发送交易（写操作）

```bash
# 铸造 Group 完整流程

# 1. 设置变量
GROUP_NAME="YourGroupName"

# 2. 计算铸造成本
MINT_COST=$(cast_call $groupAddress "calculateMintCost(string)(uint256)" "$GROUP_NAME")
echo "需要 LOVE20: $MINT_COST wei"

# 3. 批准 LOVE20 代币
cast send $LOVE20_TOKEN_ADDRESS \
  "approve(address,uint256)" \
  $groupAddress $MINT_COST \
  --rpc-url $RPC_URL \
  --account $KEYSTORE_ACCOUNT \
  --password "$KEYSTORE_PASSWORD" \
  --gas-price 5000000000 \
  --legacy

# 4. 铸造 Group
cast send $groupAddress \
  "mint(string)(uint256)" \
  "$GROUP_NAME" \
  --rpc-url $RPC_URL \
  --account $KEYSTORE_ACCOUNT \
  --password "$KEYSTORE_PASSWORD" \
  --gas-price 5000000000 \
  --legacy
```

### Cast 命令说明

- `cast call` - 只读调用，不发送交易，不消耗 gas
- `cast send` - 发送交易，需要签名，消耗 gas
- `--account` - 使用 keystore 账户
- `--password` - keystore 密码（已在环境中设置）
- `--gas-price` - gas 价格（Thinkium 网络建议 5 gwei）
- `--legacy` - 使用传统交易格式（Thinkium 需要）

### 常用查询示例

```bash
# 查看自己拥有的 Group 数量
cast_call $groupAddress "balanceOf(address)(uint256)" $ACCOUNT_ADDRESS

# 查看某个地址的第 N 个 token
cast_call $groupAddress "tokenOfOwnerByIndex(address,uint256)(uint256)" $ACCOUNT_ADDRESS 0

# 查看总共铸造了多少个 Group
cast_call $groupAddress "totalSupply()(uint256)"

# 查看第 N 个铸造的 token ID
cast_call $groupAddress "tokenByIndex(uint256)(uint256)" 0
```

## 常见问题

### Q1: 如何添加新的网络配置？

1. 在 `script/network/` 下创建新目录，如 `my_network/`
2. 复制现有网络的配置文件并修改参数
3. 确保包含所有必需的文件：
   - `.account` - keystore 账户配置
   - `network.params` - 网络 RPC 等信息
   - `group.params` - Group 配置（包含 LOVE20 地址）
   - `address.group.params` - 留空，部署后自动填充

### Q2: 部署失败怎么办？

检查以下几点：

1. 网络配置文件是否正确
2. Keystore 账户是否有足够的 gas
3. LOVE20 token 地址是否正确
4. RPC URL 是否可访问

查看详细错误信息：

```bash
# 在 forge_script 命令后添加 -vvvv 参数查看详细日志
forge script script/DeployLOVE20Group.s.sol:DeployLOVE20Group --sig "run()" \
  --rpc-url $RPC_URL \
  --account $KEYSTORE_ACCOUNT \
  --broadcast \
  -vvvv
```

### Q3: 如何重新部署？

如果需要重新部署（例如在测试网测试）：

1. 清空 `address.poolid.params` 文件：

```bash
echo "groupAddress=" > script/network/<网络名称>/address.group.params
```

2. 重新运行部署脚本

### Q4: 部署后如何验证合约工作正常？

使用 `cast call` 查询合约：

```bash
# 加载环境（如果还没加载）
source 00_init.sh <网络名称>

# 加载 Group 地址
source $network_dir/address.group.params

# 查询合约基本信息
cast_call $groupAddress "name()(string)"
cast_call $groupAddress "symbol()(string)"
cast_call $groupAddress "LOVE20_TOKEN_ADDRESS()(address)"
cast_call $groupAddress "totalSupply()(uint256)"

# 计算铸造成本示例
cast_call $groupAddress "calculateMintCost(string)(uint256)" "TestGroup"
```

### Q5: 如何在部署后更新参数文件？

部署脚本会自动更新 `address.group.params`。如果需要手动修改：

```bash
# 直接编辑文件
vim script/network/<网络名称>/address.group.params
```

或者使用命令：

```bash
echo "groupAddress=0x新地址" > script/network/<网络名称>/address.group.params
```

## 安全建议

1. **私钥管理：** 使用 Foundry keystore 而不是明文私钥
2. **密码保护：** 不要在脚本中硬编码密码
3. **测试先行：** 先在测试网部署和测试，再部署到主网
4. **验证地址：** 部署后仔细检查合约地址和配置
5. **备份配置：** 保存好所有配置文件和部署地址

## 参考资源

- [Foundry Book](https://book.getfoundry.sh/)
- [Cast 命令参考](https://book.getfoundry.sh/reference/cast/)
- [Forge Script 文档](https://book.getfoundry.sh/tutorials/solidity-scripting)
