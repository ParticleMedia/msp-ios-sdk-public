# Slack Notification Configuration Guide

## Overview

MSP iOS SDK release system supports Slack notifications for release status updates. This guide explains how to configure Slack integration using **environment variables** (recommended) or a local config file.

---

## 🔐 Security Best Practices

**⚠️ IMPORTANT**: Never commit Slack credentials to Git!

- ✅ Use **environment variables** for CI/CD pipelines
- ✅ Use **local config file** for development (gitignored)
- ❌ Never commit `slack.conf` with real credentials

---

## 🚀 Quick Start

### Option 1: Environment Variables (Recommended)

**For Production/CI**:
```bash
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
export SLACK_BOT_TOKEN="xoxb-YOUR-BOT-TOKEN"
export MSP_SLACK_ALERT_ENV="prod"

./Scripts/msp-release.sh run <version>
```

**For Testing/Development**:
```bash
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
export SLACK_BOT_TOKEN="xoxb-YOUR-BOT-TOKEN"
export MSP_SLACK_DM_OVERRIDE="U0910UJPD7B"  # Your User ID
export MSP_SLACK_ALERT_ENV="test"
export MSP_SLACK_TEST_WEBHOOK="https://hooks.slack.com/services/YOUR/TEST/WEBHOOK"

./Scripts/msp-release.sh run <version>
```

### Option 2: Local Config File (Development)

```bash
# 1. Copy template
cp Scripts/config/slack.conf.example Scripts/config/slack.conf

# 2. Edit and fill in your credentials
vim Scripts/config/slack.conf

# 3. Run release
./Scripts/msp-release.sh run <version>
```

---

## 📋 Configuration Parameters

### Required Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `SLACK_WEBHOOK_URL` | Webhook URL for channel notifications | `https://hooks.slack.com/services/T.../B.../XXX` |

### Optional Parameters (Basic)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `SLACK_CHANNEL` | Target Slack channel | `#releases` |
| `SLACK_USERNAME` | Bot display name | `MSP iOS SDK Bot` |
| `SLACK_ICON_EMOJI` | Bot icon emoji | `:rocket:` |

### Optional Parameters (Advanced)

| Parameter | Description | Example |
|-----------|-------------|---------|
| `SLACK_BOT_TOKEN` | Bot token for DMs and API features | `xoxb-...` |
| `MSP_SLACK_DM_OVERRIDE` | User ID for direct messages | `U0910UJPD7B` |
| `MSP_SLACK_ALERT_ENV` | Environment: `test` or `prod` | `test` |
| `MSP_SLACK_TEST_WEBHOOK` | Test webhook URL | `https://hooks.slack.com/...` |

---

## 🔑 How to Get Slack Credentials

### 1. Webhook URL

1. Go to https://api.slack.com/apps
2. Select your app or create a new one
3. Navigate to **Incoming Webhooks**
4. Click **Add New Webhook to Workspace**
5. Select target channel and authorize
6. Copy the webhook URL

### 2. Bot Token

1. Go to https://api.slack.com/apps
2. Select your app
3. Navigate to **OAuth & Permissions**
4. Under **Bot Token Scopes**, add:
   - `chat:write` (for sending messages)
   - `chat:write.public` (for posting to public channels)
   - `im:write` (for direct messages)
5. Install the app to your workspace
6. Copy the **Bot User OAuth Token** (starts with `xoxb-`)

### 3. User ID (for Direct Messages)

1. In Slack, right-click on the user
2. Select **View Profile**
3. Click **More** → **Copy member ID**

---

## 🎯 Usage Scenarios

### Scenario 1: Production Release (Channel Notification)

```bash
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/T04Q2K244/B09GFCLUF28/XXX"
export MSP_SLACK_ALERT_ENV="prod"
unset MSP_SLACK_DM_OVERRIDE

./Scripts/msp-release.sh run 0.3.0
```

**Result**: Sends notification to `#releases` channel

---

### Scenario 2: Test Release (Test Channel)

```bash
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/T04Q2K244/B09GFCLUF28/XXX"
export MSP_SLACK_TEST_WEBHOOK="https://hooks.slack.com/services/T04Q2K244/B0A1L0VHXFA/XXX"
export MSP_SLACK_ALERT_ENV="test"

./Scripts/msp-release.sh run 0.3.0-rc.1
```

**Result**: Sends notification to test channel (not production)

---

### Scenario 3: Direct Message to Developer

```bash
export SLACK_BOT_TOKEN="xoxb-4818648140-9559429008596-XXX"
export MSP_SLACK_DM_OVERRIDE="U0910UJPD7B"
export MSP_SLACK_ALERT_ENV="test"

./Scripts/msp-release.sh run 0.3.0-rc.1
```

**Result**: Sends DM to user `U0910UJPD7B` only

---

## 🔄 Priority Order

Configuration sources are evaluated in this order (highest priority first):

1. **Environment Variables** (highest priority)
2. **Local Config File** (`Scripts/config/slack.conf`)
3. **Default Values** (lowest priority)

**Example**: If both `SLACK_WEBHOOK_URL` environment variable and `slack.conf` are set, the environment variable wins.

---

## 🧪 Testing Notifications

Test your Slack configuration without running a full release:

```bash
# Set your credentials
export SLACK_WEBHOOK_URL="your-webhook-url"
export MSP_SLACK_ALERT_ENV="test"

# Test notification
source Scripts/notify/slack.sh
test_slack_notification
```

---

## ⚠️ Troubleshooting

### Problem: "SLACK_WEBHOOK_URL not set, skipping Slack notification"

**Solution**: Set the required environment variable:
```bash
export SLACK_WEBHOOK_URL="your-webhook-url"
```

### Problem: Direct messages not working

**Solution**: Ensure both `SLACK_BOT_TOKEN` and `MSP_SLACK_DM_OVERRIDE` are set:
```bash
export SLACK_BOT_TOKEN="xoxb-your-token"
export MSP_SLACK_DM_OVERRIDE="U0910UJPD7B"
```

### Problem: Notifications going to wrong channel

**Solution**: Check `MSP_SLACK_ALERT_ENV`:
- `test` → Uses `MSP_SLACK_TEST_WEBHOOK`
- `prod` → Uses `SLACK_WEBHOOK_URL`

---

## 🔒 Security Checklist

- [ ] Never commit `slack.conf` with real credentials
- [ ] Use environment variables in CI/CD pipelines
- [ ] Rotate tokens regularly
- [ ] Use test webhooks for development/testing
- [ ] Restrict bot permissions to minimum required
- [ ] Store credentials in secure secret management (e.g., GitHub Secrets)

---

## 📚 References

- [Slack API Documentation](https://api.slack.com/)
- [Incoming Webhooks](https://api.slack.com/messaging/webhooks)
- [Bot Tokens](https://api.slack.com/authentication/token-types#bot)

---

## 📞 Support

For issues with Slack integration, check:
1. `Scripts/notify/slack.sh` - Implementation details
2. Release logs: `/tmp/msp-release-final.log`
3. Slack API logs in terminal output

