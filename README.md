# OX_INVENTORY DISCORD LOGS

Advanced Discord logging for **ox_inventory**, built for high-population FiveM servers.

`dincek_invlogs` provides detailed, secure, and performance-friendly inventory logs sent to Discord via webhooks.  
It is designed to handle **80+ concurrent players** without Discord rate-limits, timeouts, or server lag.

---

## ✨ Features

### 📦 ox_inventory Logging
- Item transfers (`swapItems`)
- Stash
- Trunk
- Glovebox
- Pickup / drop
- Player ↔ container interactions

### 🔁 Action Detection
Each log clearly shows what happened:
- **DEPOSIT (LADE IN)** – player puts items into another inventory
- **WITHDRAW (TOG UT)** – player takes items from another inventory
- **TRANSFER** – inventory to inventory movement

### 🧾 Player Information in Logs
Every log includes:
- Player name
- Server ID
- License identifier
- Steam identifier
- Discord ID (pingable)

### 🚀 Queue-Based Discord Sender
- Prevents Discord 429 rate-limit errors
- No HTTP spam or connection timeouts
- FIFO queue (logs arrive in correct order)
- Safe for **80–120+ players**

### 🔐 Secure Webhook Handling
- Webhooks loaded via **ConVars**
- No hard-coded Discord URLs

### 📊 Multiple Discord Channels
- Inventory logs
- Stash logs
- Vehicle logs  
(Easily extendable)

### ⚙️ Fully Configurable
All performance settings are controlled via `invlogs.cfg`:
- Message rate
- Flush interval
- Queue size limit

---

## 🛡️ Designed for Large Servers

This resource is built with performance and stability in mind:
- Handles heavy inventory activity
- Minimal server overhead
- Memory-safe queue with limits
- Optimized for roleplay servers with high player counts

---

## 🔧 Requirements
- **ox_inventory**
- **ox_lib**

---

## ⚡ Installation

1. Place the resource in your `resources/` folder  
2. Add the required ConVars to `server.cfg`
3. Start the resource

```cfg
ensure ox_inventory-discord-logs
