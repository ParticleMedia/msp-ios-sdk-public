# direnv 配置指南

## 什么是 direnv？

direnv 是一个环境变量管理工具，可以在 cd 进入目录时自动加载 `.envrc` 文件中定义的环境变量。

## 安装 direnv

### macOS (Homebrew)
```bash
brew install direnv
```

### Linux (Ubuntu/Debian)
```bash
sudo apt-get install direnv
```

### 验证安装
```bash
direnv version
```

---

## 配置 Shell Hook

direnv 需要在你的 shell 中注册一个 hook。

### Bash
在 `~/.bashrc` 或 `~/.bash_profile` 中添加：
```bash
eval "$(direnv hook bash)"
```

### Zsh
在 `~/.zshrc` 中添加：
```bash
eval "$(direnv hook zsh)"
```

### Fish
在 `~/.config/fish/config.fish` 中添加：
```fish
direnv hook fish | source
```

**重要**: 添加后需要重新加载配置：
```bash
# Bash
source ~/.bashrc

# Zsh
source ~/.zshrc

# Fish
source ~/.config/fish/config.fish
```

---

## 启用 .envrc

### 首次启用
```bash
cd /path/to/msp-ios-sdk
direnv allow
```

**输出示例**:
```
direnv: loading ~/msp-ios-sdk/.envrc
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ MSP Release Environment Loaded (direnv)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📦 Release Configuration:
   MSP_RELEASE_TIER:        release
   MSP_ALLOW_LOCAL_RELEASE: 1
   MSP_ALLOW_TRUNK_PUSH:    1
   MSP_ALLOW_EXISTING_TAG:  1

📢 Slack Configuration:
   MSP_SLACK_ALERT_ENV:     prod

🔧 SPM Configuration:
   MSP_SPM_ENABLED:         false

💡 Quick Start:
   - New release:     ./Scripts/msp-release.sh run <version>
   - Resume release:  ./Scripts/msp-release.sh resume
   - Preflight test:  ./Scripts/msp-release.sh preflight

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
direnv: export +MSP_ALLOW_EXISTING_TAG +MSP_ALLOW_LOCAL_RELEASE +MSP_ALLOW_TRUNK_PUSH +MSP_RELEASE_TIER +MSP_SLACK_ALERT_ENV +MSP_SPM_ENABLED
```

### 后续使用

**环境变量自动加载**:
```bash
cd ~/msp-ios-sdk
# ✅ 环境变量自动加载！

# 离开目录，环境变量自动卸载
cd ~
# ✅ 环境变量自动清除！

# 再次进入，环境变量重新加载
cd ~/msp-ios-sdk
# ✅ 环境变量重新加载！
```

---

## 使用效果对比

### 修改前（手动 export）
```bash
# 每次都需要手动设置 6 个变量
export MSP_RELEASE_TIER=release \
       MSP_ALLOW_LOCAL_RELEASE=1 \
       MSP_SLACK_ALERT_ENV=prod \
       MSP_SPM_ENABLED=false \
       MSP_ALLOW_EXISTING_TAG=1 \
       MSP_ALLOW_TRUNK_PUSH=1

./Scripts/msp-release.sh resume
```

**问题**:
- ❌ 6 个变量，容易遗漏
- ❌ 容易拼写错误
- ❌ 每次都要重复输入

---

### 修改后（direnv 自动加载）
```bash
# 只需要 cd 进入目录
cd ~/msp-ios-sdk
# ✅ 环境变量自动加载！

# 直接运行发布命令
./Scripts/msp-release.sh resume
```

**优点**:
- ✅ 0 个手动 export
- ✅ 自动化
- ✅ 一次配置，永久生效

---

## 常见问题

### Q1: 修改 .envrc 后如何生效？
```bash
# 方法 1: 重新 allow
direnv allow

# 方法 2: 重新进入目录
cd .. && cd -
```

### Q2: 如何临时禁用 direnv？
```bash
direnv deny
```

### Q3: 如何查看当前加载的环境变量？
```bash
direnv status
```

### Q4: 如何卸载环境变量？
```bash
# 离开目录即可
cd ~
```

---

## 安全提示

⚠️ **重要**: `.envrc` 文件已被 `.gitignore` 忽略，不会提交到 Git

- ✅ 可以安全地添加敏感信息（如 webhook URL）
- ✅ 每个开发者可以自定义自己的配置
- ✅ 不会影响其他团队成员

---

## 故障排查

### direnv 不工作？

**检查 1: direnv 是否安装**
```bash
direnv version
```

**检查 2: Shell hook 是否配置**
```bash
# 检查 .bashrc 或 .zshrc 是否包含 direnv hook
grep direnv ~/.bashrc ~/.zshrc
```

**检查 3: .envrc 是否被 allow**
```bash
direnv status
```

**检查 4: .envrc 语法是否正确**
```bash
bash -n .envrc
```

---

## 更多信息

- 官方文档: https://direnv.net/
- GitHub: https://github.com/direnv/direnv

