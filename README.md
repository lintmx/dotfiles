# dotfiles

个人向 dotfiles 配置，管理默认开发环境的配置。

## 目录结构

- `config/`: 配置文件目录，按工具分类
- `scripts/`: 安装脚本目录
- `scripts/install.sh`: 交互式安装入口

## 支持平台

- macOS
- Ubuntu / Debian
- Arch Linux

## 安装

执行：

```bash
./scripts/install.sh
```

安装器会：

- 识别当前平台
- 逐模块询问是否安装
- 模块失败时立即退出
- 对已有配置逐项询问是否覆盖
- 如果目标已经由当前仓库管理，则直接跳过

## 配置约定

### zsh

共享配置在 `config/zsh/.zshrc`。
常用函数单独放在 `config/zsh/functions.zsh`。
安装器会询问如何处理 `$HOME/.zshrc`：

- 替换为最小入口文件
- 保留现有内容并追加一段受管 `source` 片段
- 跳过
- 如果检测到旧的 `~/.zshrc -> ~/.dotfiles/.zshrc` 软链接，会自动迁移为真正的本地文件

这样做的目的：

- 允许按机器情况决定是否完全接管入口文件
- 允许 Homebrew、pnpm、SDKMAN、Claude Code 等工具继续自动修改 `$HOME/.zshrc`
- 避免仓库和外部工具争抢同一个入口文件

### git

共享配置在 `config/git/.gitconfig`，安装后会链接到 `$HOME/.gitconfig`。
当前仓库是个人仓库，`user.name` 和 `user.email` 直接保存在共享配置里。
机器私有配置放在 `$HOME/.gitconfig.local`，安装器只会按需在当前机器上生成一个最小模板，用来放机器相关的额外配置。

建议把以下内容放入本地配置：

- `user.signingkey`
- `gpg.format`
- `gpg.ssh.program`
- `commit.gpgsign`

这些机器相关的额外内容不保存在仓库里。

### ssh / tssh

仓库只管理 SSH 主配置骨架和 tssh 配置，不管理具体 host 列表。

共享 SSH 主配置在 `config/ssh/config`，安装后会链接到 `$HOME/.ssh/config`。
安装器还会：

- 创建 `$HOME/.ssh/conf.d/` 目录，供当前机器自行维护具体的 group / host 配置
- 按需创建 `$HOME/.ssh/config.local` 本地模板，用来放本机专属补充项
- 链接 `config/tssh/tssh.conf` 到 `$HOME/.config/tssh/tssh.conf`

职责约定如下：

- `config/ssh/config`: 共享入口和共享默认项
- `$HOME/.ssh/conf.d/*.conf`: 当前机器自己的具体 host / group 文件，不入仓库
- `$HOME/.ssh/config.local`: 当前机器自己的额外 Include、agent、临时 host 等补充项
- `config/tssh/tssh.conf`: 让 tssh 复用同一份 `~/.ssh/config`

`config/ssh/config` 会按以下顺序加载：

1. `$HOME/.ssh/config.local`
2. `$HOME/.ssh/conf.d/*.conf`
3. 共享 `Host *` 默认项

这意味着新环境初始化后，用户需要自己往 `$HOME/.ssh/conf.d/` 补具体 host 配置；仓库不会提供或覆盖这些文件。

### vim

共享配置在 `config/vim/.vimrc`，使用 `vim-plug` 管理插件。
Vim 使用仓库内固定主题配置。

### tmux

共享本地配置在 `config/tmux/.tmux.conf.local`。
安装器会拉取 `oh-my-tmux`，并分别处理：

- `$HOME/.tmux.conf`
- `$HOME/.tmux.conf.local`

## 覆盖和跳过规则

- 目标不存在：直接创建
- 目标已正确链接到当前仓库：跳过
- 目标存在但不是当前仓库管理：询问是否覆盖
- `~/.zshrc` 已存在：询问替换为最小配置、追加 `source`，或跳过
- `zsh` 的受管片段已存在且路径正确：跳过
- `zsh` 的受管片段存在但路径过期：询问替换为最小配置、更新片段，或跳过
