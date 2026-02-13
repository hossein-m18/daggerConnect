# ⚙️ DaggerConnect

<div align="center">

**ریورس تانل قدرتمند با HTTP Mimicry و Traffic Obfuscation**

**[![BUY LICENSE WITH BOT | خرید لایسنس از ربات]](https://t.me/DaggerConnectBot)**

[ویژگی‌ها](#-ویژگیها) • [نصب سریع](#-نصب-سریع) • [مثال‌ها](#-مثالها) • [پیکربندی](#-پیکربندی-پیشرفته)

</div>

<div align="center">

[![Version](https://img.shields.io/badge/version-1.1-blue.svg)](https://github.com/itsFLoKi/DaggerConnect/releases)
[![License](https://img.shields.io/badge/license-Proprietary-red.svg)](LICENSE)
[![Go](https://img.shields.io/badge/Go-1.21+-00ADD8.svg)](https://golang.org)

</div>

---

## 📖 فهرست مطالب

- [معرفی](#-معرفی)
- [ویژگی‌های جدید v1.1](#-ویژگیهای-جدید-v11)
- [ویژگی‌ها](#-ویژگیها)
- [نصب سریع](#-نصب-سریع)
- [راهنمای استفاده](#-راهنمای-استفاده)
- [مثال‌ها](#-مثالها)
- [پیکربندی پیشرفته](#-پیکربندی-پیشرفته)
- [بنچمارک](#-بنچمارک-و-عملکرد)

---

## 🎯 معرفی

یک راهکار حرفه‌ای برای ایجاد تونل‌های امن و پرسرعت معکوس بین سرورهاست که با بهره‌گیری از آخرین فناوری‌های شبکه، امکان انتقال ترافیک با کمترین تاخیر را فراهم می‌کند. این سیستم به‌طور خاص برای محیط‌های حساس به تاخیر و نیازمند امنیت بالا طراحی شده است.

### 🔥 چرا DaggerConnect?

✅ **سرعت بالا** - با استفاده از SMUX و KCP  
✅ **چند پروتکل** - TCP, KCP, WebSocket, WSS, HTTP Mimicry  
✅ **UDP Support** - پشتیبانی کامل از UDP (مناسب WireGuard, QUIC, OpenVPN)  
✅ **HTTP Mimicry** - شبیه‌سازی کامل ترافیک مرورگر برای دور زدن DPI  
✅ **Traffic Obfuscation** - مخفی‌سازی ترافیک با padding و timing randomization  
✅ **Auto-reconnect** - اتصال مجدد خودکار  
✅ **Connection Pooling** - چندین اتصال همزمان برای load balancing  
✅ **پروفایل‌های آماده** - Balanced, Aggressive, Latency, CPU-Efficient, Gaming  
✅ **تنظیمات پیشرفته** - SMUX, TCP, Advanced buffer tuning

---

## 🆕 ویژگی‌های جدید v1.1

### 🎭 HTTP/HTTPS Mimicry Transport

قابلیت جدیدی که ترافیک شما را **100% شبیه یک مرورگر واقعی** می‌کند:

- ✨ **Realistic Browser Simulation** - شبیه‌سازی دقیق Chrome, Firefox, Safari
- 🌐 **Host Header Spoofing** - استفاده از دامنه‌های معتبر (google.com, cloudflare.com)
- 🍪 **Cookie & Session Management** - مدیریت کوکی و session ID مثل مرورگر واقعی
- 📦 **Chunked Transfer Encoding** - مخفی کردن اندازه واقعی بسته‌ها
- 🔒 **TLS Support** - HTTPS با گواهی SSL
- 🎯 **Custom Headers** - امکان اضافه کردن هدرهای سفارشی

**نتیجه**: عبور از DPI (Deep Packet Inspection) و فیلترینگ‌های پیشرفته

### ⚙️ تنظیمات پیشرفته SMUX

- **KeepAlive Interval** - قابل تنظیم
- **Max Receive/Stream Buffer** - بهینه‌سازی برای هر شبکه
- **Frame Size** - کنترل دقیق اندازه frame

### 🔧 تنظیمات پیشرفته TCP/UDP

- **TCP NoDelay** - کاهش latency
- **TCP KeepAlive** - مدیریت connection timeout
- **Buffer Sizes** - تنظیم Read/Write buffer
- **Connection Limits** - کنترل تعداد اتصالات همزمان
- **UDP Flow Management** - بهینه‌سازی ترافیک UDP

### 📋 Port Mapping پیشرفته

- **Bind IP/Port جداگانه** - کنترل دقیق پورت باز شده
- **Target IP/Port جداگانه** - فوروارد به هر IP دلخواه
- **Multiple Protocols** - TCP, UDP یا هر دو همزمان

---

## ⚡ ویژگی‌ها

### 🌐 پروتکل‌های پشتیبانی شده

| پروتکل                | پورت | امنیت      | DPI Bypass | کاربرد                    |
| --------------------- | ---- | ---------- | ---------- | ------------------------- |
| **TCP** (tcpmux)      | Any  | ✅ AES-GCM | ⭐⭐       | استفاده عمومی، پایدار     |
| **KCP** (kcpmux)      | UDP  | ✅ AES     | ⭐⭐⭐     | شبکه‌های پرافت، سرعت بالا |
| **WebSocket** (wsmux) | 80   | ✅ AES-GCM | ⭐⭐⭐     | عبور از فایروال HTTP      |
| **WSS** (wssmux)      | 443  | ✅ TLS+AES | ⭐⭐⭐⭐   | امنیت بالا + Firewall     |
| **HTTP** (httpmux)    | 80   | ✅ AES-GCM | ⭐⭐⭐⭐⭐ | **DPI Bypass کامل** 🆕    |
| **HTTPS** (httpsmux)  | 443  | ✅ TLS+AES | ⭐⭐⭐⭐⭐ | **بهترین - DPI + TLS** 🆕 |

### 🎨 پروفایل‌های عملکرد

| پروفایل           | تاخیر      | CPU        | پهنای باند | کاربرد                 |
| ----------------- | ---------- | ---------- | ---------- | ---------------------- |
| **balanced**      | ⭐⭐⭐     | ⭐⭐⭐     | ⭐⭐⭐     | استفاده روزمره         |
| **aggressive**    | ⭐⭐⭐⭐   | ⭐⭐       | ⭐⭐⭐⭐⭐ | انتقال فایل، سرعت بالا |
| **latency**       | ⭐⭐⭐⭐⭐ | ⭐⭐       | ⭐⭐⭐⭐   | بازی، VoIP             |
| **cpu-efficient** | ⭐⭐       | ⭐⭐⭐⭐⭐ | ⭐⭐       | سرورهای ضعیف           |
| **gaming**        | ⭐⭐⭐⭐⭐ | ⭐⭐⭐     | ⭐⭐⭐⭐   | گیمینگ، Real-time      |

### 🎭 Traffic Obfuscation

- ✨ **Random Padding** - اضافه کردن padding تصادفی برای مخفی کردن اندازه بسته‌ها
- ⏱️ **Timing Randomization** - تاخیر تصادفی برای شبیه‌سازی ترافیک طبیعی
- 📦 **Packet Chunking** - تقسیم بسته‌ها به chunk های متغیر
- 🎯 **Burst Mode** - ارسال سریع گاه‌به‌گاه برای شبیه‌سازی رفتار کاربر واقعی

### 🔧 قابلیت‌های پیشرفته

- ✨ **Stream Multiplexing** - چندین stream روی یک اتصال
- 🔄 **Load Balancing** - توزیع بار بین session‌ها
- 🛡️ **PSK Encryption** - رمزنگاری AES-GCM با Pre-Shared Key
- 📊 **Connection Pooling** - بهینه‌سازی تعداد اتصالات
- 🎯 **UDP Flow Management** - مدیریت هوشمند جریان UDP
- 📈 **Auto Buffer Tuning** - تنظیم خودکار بافرها
- 🔁 **Graceful Restart** - راه‌اندازی مجدد بدون قطعی
- 🔒 **SSL/TLS Support** - پشتیبانی کامل از HTTPS
- 🎭 **User-Agent Spoofing** - شبیه‌سازی User-Agent واقعی

---

## 🚀 نصب سریع

### نصب خودکار با اسکریپت Installer (توصیه می‌شود)

```bash
curl -O https://raw.githubusercontent.com/hossein-m18/DaggerConnect/main/setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

### 📦 نصب دستی

```bash
# دانلود باینری
wget https://github.com/itsFLoKi/DaggerConnect/releases/latest/download/DaggerConnect
chmod +x DaggerConnect
sudo mv DaggerConnect /usr/local/bin/

# ایجاد دایرکتوری کانفیگ
sudo mkdir -p /etc/DaggerConnect

# تولید فایل کانفیگ
DaggerConnect -gen server  # برای سرور
DaggerConnect -gen client  # برای کلاینت
```

---

## 📚 راهنمای استفاده

### 🖥️ نصب سرور (ایران)

```bash
1. گزینه "1) Install Server" را انتخاب کنید

2. انتخاب Transport Type:
   1) tcpmux   - TCP Multiplexing (Simple & Fast)
   2) kcpmux   - KCP Multiplexing (UDP based, High Speed)
   3) wsmux    - WebSocket (HTTP compatible)
   4) wssmux   - WebSocket Secure (HTTPS with TLS)
   5) httpmux  - HTTP Mimicry (DPI bypass, Realistic) 🆕
   6) httpsmux - HTTPS Mimicry (TLS + DPI bypass) ⭐ توصیه می‌شود 🆕

3. پورت Tunnel را وارد کنید (مثال: 443 برای httpsmux)

4. PSK (رمز ارتباط) را وارد کنید - باید در client هم یکسان باشد

5. پروفایل عملکرد را انتخاب کنید:
   1) balanced      - پیش‌فرض، متعادل
   2) aggressive    - سرعت بالا
   3) latency       - کمترین تاخیر
   4) cpu-efficient - کم‌مصرف
   5) gaming        - مخصوص گیمینگ

6. تنظیم SSL (برای httpsmux/wssmux):
   1) Generate self-signed certificate (سریع و آسان) ✅
   2) Use existing certificate files

7. HTTP Mimicry Settings (برای httpmux/httpsmux): 🆕
   - Fake domain: www.google.com
   - Fake path: /search
   - User-Agent: Chrome/Firefox/Safari
   - Chunked encoding: Y
   - Session cookies: Y

8. فعال‌سازی Traffic Obfuscation (توصیه: Y)
   - Min/Max padding
   - Min/Max delay

9. Advanced Settings (اختیاری):
   - SMUX: KeepAlive, Buffers, Frame size
   - TCP: NoDelay, KeepAlive, Buffers
   - Connection Limits

10. Port Mappings: 🆕
    Protocol: tcp/udp/both

    Bind Settings (پورت روی این سرور):
    - Bind IP: 0.0.0.0
    - Bind Port: 443

    Target Settings (پورت مقصد):
    - Target IP: 127.0.0.1
    - Target Port: 443

    ✓ Mapping: 0.0.0.0:443 → 127.0.0.1:443

11. Verbose logging (اختیاری): y/N
```

### 💻 نصب کلاینت (سرور خارج)

```bash
1. گزینه "2) Install Client" را انتخاب کنید

2. همان PSK سرور را وارد کنید

3. همان پروفایل سرور را انتخاب کنید

4. فعال‌سازی Traffic Obfuscation (باید با سرور یکسان باشد)

5. Advanced Settings (باید با سرور هماهنگ باشد)

6. Connection Paths:
   - Transport: همان transport سرور (httpsmux توصیه می‌شود)
   - Server address: YOUR_SERVER_IP:443
   - Connection pool: 3 (برای HTTPS Mimicry)
   - Aggressive pool: Y
   - Retry interval: 5
   - Dial timeout: 20

   اگر httpmux/httpsmux انتخاب کردید:
   - HTTP Mimicry settings باید با سرور یکسان باشد

7. می‌توانید چند path اضافه کنید برای failover

8. Verbose logging (اختیاری)
```

### ⚙️ مدیریت سرویس‌ها

```bash
# ورود به منوی تنظیمات
گزینه "3) Settings" در منوی اصلی

# عملیات‌های موجود:
1) Start - راه‌اندازی سرویس
2) Stop - توقف سرویس
3) Restart - راه‌اندازی مجدد
4) Status - مشاهده وضعیت
5) View Logs - مشاهده لاگ‌های زنده
6) Enable Auto-start - فعال‌سازی اجرای خودکار
7) Disable Auto-start - غیرفعال‌سازی اجرای خودکار
8) View Config - مشاهده کانفیگ
9) Edit Config - ویرایش کانفیگ
10) Delete Config & Service - حذف کامل
```

---

## 💡 مثال‌ها

### مثال 1: V2Ray/Xray با HTTP Mimicry (بهترین برای دور زدن فیلترینگ) 🆕

#### سرور ایران (Server)

```yaml
mode: "server"
listen: "0.0.0.0:443"
transport: "httpsmux" # HTTPS Mimicry
psk: "my-super-secret-key-12345"
profile: "aggressive"
verbose: true

cert_file: "/etc/DaggerConnect/certs/cert.pem"
key_file: "/etc/DaggerConnect/certs/key.pem"

maps:
  - type: tcp
    bind: "0.0.0.0:8443"
    target: "127.0.0.1:443"

obfuscation:
  enabled: true
  min_padding: 32
  max_padding: 1024
  min_delay_ms: 10
  max_delay_ms: 100
  burst_chance: 0.2

http_mimic:
  fake_domain: "www.google.com"
  fake_path: "/search"
  user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
  chunked_encoding: true
  session_cookie: true
  custom_headers:
    - "X-Requested-With: XMLHttpRequest"
    - "Referer: https://www.google.com/"

smux:
  keepalive: 5
  max_recv: 16777216
  max_stream: 16777216
  frame_size: 32768
  version: 2

advanced:
  tcp_nodelay: true
  tcp_keepalive: 15
  tcp_read_buffer: 8388608
  tcp_write_buffer: 8388608
  max_connections: 5000
```

#### سرور خارج (Client)

```yaml
mode: "client"
psk: "my-super-secret-key-12345"
profile: "aggressive"
verbose: true

paths:
  - transport: "httpsmux"
    addr: "IRAN_SERVER_IP:443"
    connection_pool: 3
    aggressive_pool: true
    retry_interval: 5
    dial_timeout: 20

obfuscation:
  enabled: true
  min_padding: 32
  max_padding: 1024
  min_delay_ms: 10
  max_delay_ms: 100
  burst_chance: 0.2

http_mimic:
  fake_domain: "www.google.com"
  fake_path: "/search"
  user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
  chunked_encoding: true
  session_cookie: true
  custom_headers:
    - "X-Requested-With: XMLHttpRequest"
    - "Referer: https://www.google.com/"

smux:
  keepalive: 5
  max_recv: 16777216
  max_stream: 16777216
  frame_size: 32768
  version: 2

advanced:
  tcp_nodelay: true
  tcp_keepalive: 15
  tcp_read_buffer: 8388608
  tcp_write_buffer: 8388608
  connection_timeout: 60
```

```bash
# V2Ray/Xray روی سرور خارج باید روی 127.0.0.1:443 listen کند
# کاربران به IRAN_SERVER_IP:8443 متصل می‌شوند
# ترافیک 100% شبیه HTTPS به google.com است!
```

---

### مثال 2: WireGuard Tunnel با KCP

#### سرور ایران

```yaml
mode: "server"
listen: "0.0.0.0:4000"
transport: "kcpmux" # KCP برای UDP بهتره
psk: "wireguard-tunnel-key"
profile: "latency"
verbose: false

maps:
  - type: udp
    bind: "0.0.0.0:51820"
    target: "127.0.0.1:51820"

obfuscation:
  enabled: false # برای WireGuard بهتره خاموش باشه

kcp:
  nodelay: 1
  interval: 5
  resend: 2
  nc: 1
  sndwnd: 2048
  rcvwnd: 2048
  mtu: 1200
```

#### سرور خارج

```yaml
mode: "client"
psk: "wireguard-tunnel-key"
profile: "latency"
verbose: false

paths:
  - transport: "kcpmux"
    addr: "IRAN_SERVER_IP:4000"
    connection_pool: 3
    aggressive_pool: false
    retry_interval: 3
    dial_timeout: 10

obfuscation:
  enabled: false
```

---

### مثال 3: SSH Reverse Tunnel با Port Forwarding به سرور دیگر 🆕

```yaml
# server.yaml (سرور ایران)
mode: "server"
listen: "0.0.0.0:4000"
transport: "tcpmux"
psk: "ssh-secure-key"
profile: "balanced"

maps:
  # SSH به localhost
  - type: tcp
    bind: "0.0.0.0:2222"
    target: "127.0.0.1:22"

  # SSH به سرور دیگر در شبکه داخلی
  - type: tcp
    bind: "0.0.0.0:2223"
    target: "192.168.1.100:22"

  # RDP به ویندوز سرور
  - type: tcp
    bind: "0.0.0.0:3389"
    target: "192.168.1.50:3389"

obfuscation:
  enabled: true
```

```bash
# اتصال از کلاینت:
ssh -p 2222 user@IRAN_SERVER_IP  # به localhost
ssh -p 2223 user@IRAN_SERVER_IP  # به 192.168.1.100
mstsc /v:IRAN_SERVER_IP:3389     # RDP
```

---

### مثال 4: Multi-Service با HTTP Mimicry

```yaml
# server.yaml
mode: "server"
listen: "0.0.0.0:443"
transport: "httpsmux"
psk: "multi-service-key"
profile: "balanced"

cert_file: "/etc/DaggerConnect/certs/cert.pem"
key_file: "/etc/DaggerConnect/certs/key.pem"

maps:
  # V2Ray/Xray
  - type: tcp
    bind: "0.0.0.0:8443"
    target: "127.0.0.1:443"

  # Shadowsocks
  - type: tcp
    bind: "0.0.0.0:8388"
    target: "127.0.0.1:8388"

  # SSH
  - type: tcp
    bind: "0.0.0.0:2222"
    target: "127.0.0.1:22"

  # WireGuard
  - type: udp
    bind: "0.0.0.0:51820"
    target: "127.0.0.1:51820"

obfuscation:
  enabled: true
  min_padding: 64
  max_padding: 2048
  min_delay_ms: 15
  max_delay_ms: 150
  burst_chance: 0.3

http_mimic:
  fake_domain: "www.cloudflare.com"
  fake_path: "/api/v1/data"
  user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
  chunked_encoding: true
  session_cookie: true
  custom_headers:
    - "Accept: application/json"
    - "X-Requested-With: XMLHttpRequest"
```

---

### مثال 5: Gaming Server (Low Latency)

```yaml
# server.yaml
mode: "server"
listen: "0.0.0.0:4000"
transport: "kcpmux"
psk: "gaming-server-key"
profile: "gaming" # پروفایل gaming
verbose: false

maps:
  # Minecraft
  - type: tcp
    bind: "0.0.0.0:25565"
    target: "127.0.0.1:25565"
  - type: udp
    bind: "0.0.0.0:25565"
    target: "127.0.0.1:25565"

  # CS:GO
  - type: udp
    bind: "0.0.0.0:27015"
    target: "127.0.0.1:27015"
  - type: tcp
    bind: "0.0.0.0:27015"
    target: "127.0.0.1:27015"

  # Rust
  - type: tcp
    bind: "0.0.0.0:28015"
    target: "127.0.0.1:28015"
  - type: udp
    bind: "0.0.0.0:28016"
    target: "127.0.0.1:28016"

obfuscation:
  enabled: false # برای گیمینگ بهتره خاموش باشه

kcp:
  nodelay: 1
  interval: 5
  resend: 2
  nc: 1
  sndwnd: 2048
  rcvwnd: 2048
  mtu: 1200

smux:
  keepalive: 2
  max_recv: 16777216
  max_stream: 16777216
  frame_size: 32768
```

---

### مثال 6: Multi-Path با HTTP Mimicry Failover

```yaml
# client.yaml
mode: "client"
psk: "load-balance-key"
profile: "aggressive"

paths:
  # Path 1: HTTPS Mimicry (اصلی)
  - transport: "httpsmux"
    addr: "server1.example.com:443"
    connection_pool: 3
    aggressive_pool: true
    retry_interval: 5
    dial_timeout: 20

  # Path 2: HTTP Mimicry (backup)
  - transport: "httpmux"
    addr: "server2.example.com:80"
    connection_pool: 2
    aggressive_pool: true
    retry_interval: 5
    dial_timeout: 15

  # Path 3: KCP (fallback سریع)
  - transport: "kcpmux"
    addr: "server3.example.com:4000"
    connection_pool: 2
    aggressive_pool: true
    retry_interval: 3
    dial_timeout: 10

obfuscation:
  enabled: true
  min_padding: 32
  max_padding: 1024
  min_delay_ms: 10
  max_delay_ms: 100

http_mimic:
  fake_domain: "www.google.com"
  fake_path: "/search"
  user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
  chunked_encoding: true
  session_cookie: true
```

---

## ⚙️ پیکربندی پیشرفته

### 🎭 HTTP Mimicry Configuration (جدید!) 🆕

```yaml
http_mimic:
  fake_domain: "www.google.com" # دامنه جعلی در Host header
  fake_path: "/search" # مسیر جعلی
  user_agent: "Mozilla/5.0..." # User-Agent واقعی
  chunked_encoding: true # استفاده از chunked transfer
  session_cookie: true # ارسال cookie و session ID
  custom_headers: # هدرهای اضافی
    - "X-Requested-With: XMLHttpRequest"
    - "Referer: https://www.google.com/"
    - "Accept-Language: en-US,en;q=0.9"
```

#### 🌐 توصیه‌های Domain:

| Domain               | کاربرد     | توضیح                   |
| -------------------- | ---------- | ----------------------- |
| `www.google.com`     | عمومی      | پرترافیک‌ترین سایت      |
| `www.cloudflare.com` | CDN/API    | شبیه‌ترین به ترافیک CDN |
| `api.github.com`     | Developer  | برای ترافیک API         |
| `www.microsoft.com`  | Enterprise | برای محیط‌های کاری      |

#### 👤 User-Agent های پیشنهادی:

```yaml
# Chrome Windows (محبوب‌ترین)
user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# Firefox Windows
user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0"

# Chrome macOS
user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# Safari macOS
user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15"

# Chrome Android
user_agent: "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.144 Mobile Safari/537.36"
```

---

### 🎭 Traffic Obfuscation Settings

```yaml
obfuscation:
  enabled: true # فعال/غیرفعال سازی obfuscation
  min_padding: 16 # حداقل padding (بایت)
  max_padding: 512 # حداکثر padding (بایت)
  min_delay_ms: 5 # حداقل تاخیر (میلی‌ثانیه)
  max_delay_ms: 50 # حداکثر تاخیر (میلی‌ثانیه)
  burst_chance: 0.15 # احتمال burst mode (0.0-1.0)
```

#### 🎯 توصیه‌های Obfuscation:

| سناریو              | enabled | padding  | delay  | burst | کاربرد        |
| ------------------- | ------- | -------- | ------ | ----- | ------------- |
| **Maximum Stealth** | true    | 128-2048 | 15-150 | 0.3   | فیلترینگ شدید |
| **Balanced**        | true    | 32-1024  | 10-100 | 0.2   | استفاده عمومی |
| **Performance**     | true    | 16-512   | 5-50   | 0.15  | سرعت+امنیت    |
| **Light**           | true    | 8-256    | 2-20   | 0.1   | سرعت بالا     |
| **Gaming/VoIP**     | false   | -        | -      | -     | کمترین تاخیر  |

---

### ⚙️ SMUX Configuration (جدید!) 🆕

```yaml
smux:
  keepalive: 5 # KeepAlive interval (ثانیه)
  max_recv: 16777216 # Max receive buffer (16 MB)
  max_stream: 16777216 # Max stream buffer (16 MB)
  frame_size: 32768 # Frame size (32 KB)
  version: 2 # SMUX protocol version
```

#### 📊 توصیه‌های SMUX:

| پروفایل           | keepalive | max_recv | max_stream | کاربرد      |
| ----------------- | --------- | -------- | ---------- | ----------- |
| **Gaming**        | 2         | 16777216 | 16777216   | Low latency |
| **Aggressive**    | 5         | 16777216 | 16777216   | High speed  |
| **Balanced**      | 8         | 8388608  | 8388608    | Normal use  |
| **CPU-Efficient** | 10        | 8388608  | 8388608    | Low CPU     |

---

### 🔧 Advanced TCP/UDP Settings (جدید!) 🆕

```yaml
advanced:
  tcp_nodelay: true # TCP NoDelay (کاهش latency)
  tcp_keepalive: 15 # TCP KeepAlive (ثانیه)
  tcp_read_buffer: 8388608 # TCP Read Buffer (8 MB)
  tcp_write_buffer: 8388608 # TCP Write Buffer (8 MB)
  max_connections: 5000 # حداکثر اتصالات همزمان
  connection_timeout: 60 # Timeout اتصال (ثانیه)
  stream_timeout: 120 # Timeout stream (ثانیه)
  udp_buffer_size: 4194304 # UDP Buffer (4 MB)
  cleanup_interval: 3 # Cleanup interval (ثانیه)
```

---

### 🔧 Path Configuration (Client)

```yaml
paths:
  - transport: "httpsmux" # نوع transport
    addr: "server.example.com:443" # آدرس و پورت سرور
    connection_pool: 3 # تعداد اتصالات همزمان
    aggressive_pool: true # حالت aggressive pooling
    retry_interval: 5 # فاصله retry (ثانیه)
    dial_timeout: 20 # timeout اتصال (ثانیه)
```

#### 📊 Connection Pool Guidelines:

| شرایط شبکه                | Transport     | Pool Size | Aggressive |
| ------------------------- | ------------- | --------- | ---------- |
| **HTTP Mimicry Stable**   | httpsmux      | 2-3       | false      |
| **HTTP Mimicry Normal**   | httpsmux      | 3-4       | true       |
| **HTTP Mimicry Unstable** | httpsmux      | 4-6       | true       |
| **TCP/KCP Stable**        | tcpmux/kcpmux | 2         | false      |
| **TCP/KCP Normal**        | tcpmux/kcpmux | 3-4       | false      |
| **TCP/KCP Unstable**      | tcpmux/kcpmux | 5-6       | true       |
| **High Load**             | any           | 6-8       | true       |

---

## 📋 Port Mapping Guide (جدید!) 🆕

### نحوه تنظیم Bind و Target:

```yaml
maps:
  - type: tcp
    bind: "BIND_IP:BIND_PORT" # پورت باز شده روی سرور
    target: "TARGET_IP:TARGET_PORT" # مقصد فوروارد
```

### مثال‌های کاربردی:

```yaml
# SSH: پورت 2222 به localhost:22
- type: tcp
  bind: "0.0.0.0:2222"
  target: "127.0.0.1:22"

# Web: پورت 8080 به Apache داخلی
- type: tcp
  bind: "0.0.0.0:8080"
  target: "127.0.0.1:80"

# Forward به سرور دیگر در شبکه
- type: tcp
  bind: "0.0.0.0:3389"
  target: "192.168.1.100:3389"

# MySQL فقط برای localhost (امن‌تر)
- type: tcp
  bind: "127.0.0.1:3307"
  target: "127.0.0.1:3306"
```

---

## 🎮 مدیریت Systemd Service

### Server Service

```bash
# شروع
sudo systemctl start DaggerConnect-server

# توقف
sudo systemctl stop DaggerConnect-server

# راه‌اندازی مجدد
sudo systemctl restart DaggerConnect-server

# فعال‌سازی auto-start
sudo systemctl enable DaggerConnect-server

# وضعیت
sudo systemctl status DaggerConnect-server
```

### Client Service

```bash
# شروع
sudo systemctl start DaggerConnect-client

# توقف
sudo systemctl stop DaggerConnect-client

# راه‌اندازی مجدد
sudo systemctl restart DaggerConnect-client

# فعال‌سازی auto-start
sudo systemctl enable DaggerConnect-client

# وضعیت
sudo systemctl status DaggerConnect-client
```

### 📋 مشاهده Logs

```bash
# Server logs (زنده)
journalctl -u DaggerConnect-server -f

# Client logs (زنده)
journalctl -u DaggerConnect-client -f

# آخرین 100 خط
journalctl -u DaggerConnect-server -n 100

# لاگ‌های امروز
journalctl -u DaggerConnect-server --since today

# لاگ‌های یک ساعت گذشته
journalctl -u DaggerConnect-client --since "1 hour ago"

# جستجو در لاگ‌ها
journalctl -u DaggerConnect-server | grep ERROR
```

---

## 📊 بنچمارک و عملکرد

### مقایسه پروتکل‌ها (با Obfuscation)

| پروتکل          | تاخیر (ms) | پهنای باند (Mbps) | CPU (%) | حافظه (MB) | DPI Bypass |
| --------------- | ---------- | ----------------- | ------- | ---------- | ---------- |
| **tcpmux**      | 15         | 850               | 8       | 45         | ⭐⭐       |
| **kcpmux**      | 12         | 920               | 15      | 65         | ⭐⭐⭐     |
| **wsmux**       | 18         | 780               | 10      | 50         | ⭐⭐⭐     |
| **wssmux**      | 20         | 750               | 12      | 55         | ⭐⭐⭐⭐   |
| **httpmux** 🆕  | 22         | 720               | 13      | 58         | ⭐⭐⭐⭐⭐ |
| **httpsmux** 🆕 | 25         | 700               | 15      | 62         | ⭐⭐⭐⭐⭐ |

_تست شده با connection pool=4, profile=balanced, obfuscation=enabled, شبکه 1Gbps_

### مقایسه پروفایل‌ها (با KCP)

| پروفایل           | تاخیر (ms) | Throughput (Mbps) | CPU (%) | RAM (MB) |
| ----------------- | ---------- | ----------------- | ------- | -------- |
| **cpu-efficient** | 25         | 450               | 5       | 40       |
| **balanced**      | 15         | 750               | 10      | 50       |
| **latency**       | 8          | 900               | 18      | 60       |
| **aggressive**    | 10         | 950               | 22      | 70       |
| **gaming**        | 7          | 920               | 20      | 65       |

### تأثیر Obfuscation بر عملکرد

| حالت                   | تاخیر اضافه (ms) | CPU اضافه (%) | Throughput (%) |
| ---------------------- | ---------------- | ------------- | -------------- |
| **Disabled**           | 0                | 0             | 100%           |
| **Light (8-256)**      | 2-5              | 2-3           | 95%            |
| **Balanced (16-512)**  | 5-15             | 5-8           | 90%            |
| **Heavy (64-2048)**    | 15-50            | 10-18         | 85%            |
| **Maximum (128-2048)** | 30-80            | 15-25         | 75%            |

### تأثیر HTTP Mimicry 🆕

| Transport    | Overhead | DPI Detection | توضیح                   |
| ------------ | -------- | ------------- | ----------------------- |
| **tcpmux**   | 5%       | 95%           | قابل شناسایی            |
| **httpmux**  | 15%      | 10%           | تقریباً غیرقابل شناسایی |
| **httpsmux** | 18%      | 5%            | بهترین - TLS + Mimicry  |

---

## 🔒 امنیت

### 1️⃣ تولید PSK قوی

```bash
# روش 1: OpenSSL (توصیه می‌شود)
openssl rand -base64 32

# روش 2: /dev/urandom
head -c 32 /dev/urandom | base64

# روش 3: pwgen
pwgen -s 64 1

# روش 4: از داخل installer
# PSK به صورت خودکار ایمن تولید می‌شود
```

### 2️⃣ استفاده از TLS (WSS/HTTPS Mimicry) 🆕

```bash
# تولید self-signed certificate
openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout /etc/DaggerConnect/certs/key.pem \
  -out /etc/DaggerConnect/certs/cert.pem \
  -days 365 -subj "/CN=www.google.com"

# یا از داخل installer:
# گزینه "1) Generate self-signed certificate" را انتخاب کنید
```

```yaml
# server.yaml
transport: "httpsmux" # یا wssmux
cert_file: "/etc/DaggerConnect/certs/cert.pem"
key_file: "/etc/DaggerConnect/certs/key.pem"
```

### 3️⃣ فایروال و محدودیت دسترسی

```bash
# فقط IP مشخص
sudo ufw allow from 1.2.3.4 to any port 443

# محدود کردن rate
sudo ufw limit 443/tcp

# چک وضعیت
sudo ufw status numbered

# حذف قانون
sudo ufw delete [number]
```

### 4️⃣ Obfuscation برای مخفی‌سازی ترافیک

```yaml
# Maximum Stealth (بیشترین امنیت)
obfuscation:
  enabled: true
  min_padding: 128
  max_padding: 2048
  min_delay_ms: 15
  max_delay_ms: 150
  burst_chance: 0.3
```

### 5️⃣ HTTP Mimicry برای دور زدن DPI 🆕

```yaml
# استفاده از HTTPS Mimicry
transport: "httpsmux"

http_mimic:
  fake_domain: "www.cloudflare.com"
  fake_path: "/api/v1/data"
  user_agent: "Mozilla/5.0..."
  chunked_encoding: true
  session_cookie: true
```

---

## 🛠️ عیب‌یابی (Troubleshooting)

### ❌ سرور اجرا نمیشه

```bash
# چک کردن پورت
sudo netstat -tlnp | grep 443
sudo ss -tulpn | grep 443

# چک کردن سرویس
sudo systemctl status DaggerConnect-server

# مشاهده لاگ‌های خطا
journalctl -u DaggerConnect-server -n 50

# چک کردن فایل کانفیگ
cat /etc/DaggerConnect/server.yaml
```

### ❌ کلاینت متصل نمیشه

```bash
# تست اتصال به سرور
telnet SERVER_IP 443
nc -zv SERVER_IP 443

# چک کردن PSK
# PSK باید در هر دو سرور یکسان باشد

# چک کردن Transport
# Transport باید در client و server یکسان باشد

# چک کردن فایروال
sudo ufw status

# چک کردن لاگ‌های کلاینت
journalctl -u DaggerConnect-client -n 50
```

### ❌ SSL/TLS Error (برای httpsmux/wssmux)

```bash
# چک کردن گواهی
openssl x509 -in /etc/DaggerConnect/certs/cert.pem -text -noout

# تولید مجدد گواهی
cd /etc/DaggerConnect/certs
rm cert.pem key.pem
openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout key.pem -out cert.pem -days 365 \
  -subj "/CN=www.google.com"

# راه‌اندازی مجدد سرویس
sudo systemctl restart DaggerConnect-server
```

### ❌ سرعت کمه

```bash
# افزایش Connection Pool
paths:
  - connection_pool: 6  # به جای 2

# تغییر پروفایل به aggressive
profile: "aggressive"

# استفاده از KCP
transport: "kcpmux"

# افزایش SMUX buffers
smux:
  max_recv: 16777216
  max_stream: 16777216

# افزایش TCP buffers
advanced:
  tcp_read_buffer: 16777216
  tcp_write_buffer: 16777216
```

### ❌ تاخیر زیاده

```bash
# تغییر پروفایل
profile: "latency"  # یا gaming

# غیرفعال کردن Obfuscation
obfuscation:
  enabled: false

# کاهش padding (اگر Obfuscation لازمه)
obfuscation:
  enabled: true
  min_padding: 8
  max_padding: 128
  min_delay_ms: 2
  max_delay_ms: 10

# استفاده از KCP با تنظیمات gaming
transport: "kcpmux"
profile: "gaming"
```

### ❌ HTTP Mimicry کار نمی‌کنه 🆕

```bash
# چک کردن که Transport درست انتخاب شده
# باید httpmux یا httpsmux باشد

# چک کردن تنظیمات HTTP Mimicry
# باید در client و server یکسان باشد

# مشاهده لاگ‌های دقیق
journalctl -u DaggerConnect-server -f | grep -i "http\|mimic"

# تست با curl
curl -v https://SERVER_IP:443
# باید پاسخ HTTP دریافت کنید
```

---

## 📈 ابزارهای نظارت

### تست سرعت با iperf3

```bash
# نصب iperf3
sudo apt install iperf3

# سرور (روی سرور خارج)
iperf3 -s -p 5201

# کلاینت (از سرور ایران یا کامپیوتر شخصی)
iperf3 -c IRAN_SERVER_IP -p 5201 -t 30 -P 4

# تست UDP
iperf3 -c IRAN_SERVER_IP -p 5201 -u -b 100M
```

### نظارت بر ترافیک

```bash
# نصب iftop
sudo apt install iftop

# مشاهده ترافیک لحظه‌ای
sudo iftop -i eth0

# نمایش آمار
vnstat -l

# نمایش آمار روزانه
vnstat -d
```

### نظارت بر منابع سیستم

```bash
# CPU و RAM
htop

# فقط DaggerConnect
ps aux | grep DaggerConnect

# استفاده از منابع
pidstat -p $(pgrep DaggerConnect) 1

# تعداد اتصالات
netstat -an | grep :443 | wc -l
```

### نظارت بر Connection Pool

```bash
# تعداد session های فعال
journalctl -u DaggerConnect-client -n 100 | grep "Session Added"

# تعداد stream های فعال
netstat -tn | grep ESTABLISHED | grep :443
```

---

## 🔄 آپدیت

### آپدیت از طریق Installer

```bash
sudo bash setup.sh.sh
# گزینه 4) Update Core را انتخاب کنید
```

### آپدیت دستی

```bash
# دانلود نسخه جدید
wget https://github.com/itsFLoKi/DaggerConnect/releases/latest/download/DaggerConnect

# توقف سرویس‌ها
sudo systemctl stop DaggerConnect-server
sudo systemctl stop DaggerConnect-client

# backup قبلی
sudo cp /usr/local/bin/DaggerConnect /usr/local/bin/DaggerConnect.backup

# جایگزینی باینری
chmod +x DaggerConnect
sudo mv DaggerConnect /usr/local/bin/

# چک کردن نسخه
/usr/local/bin/DaggerConnect -v

# راه‌اندازی مجدد
sudo systemctl start DaggerConnect-server
sudo systemctl start DaggerConnect-client

# چک کردن وضعیت
sudo systemctl status DaggerConnect-server
sudo systemctl status DaggerConnect-client
```

---

## 📝 سوالات متداول (FAQ)

### ❓ چه تفاوتی بین TCP و KCP هست؟

- **TCP (tcpmux)**: پایدار، کمترین CPU، مناسب شبکه‌های باثبات
- **KCP (kcpmux)**: سریع‌تر، مناسب شبکه‌های پرافت، CPU بیشتر، مناسب UDP protocols

### ❓ HTTP Mimicry چیه و کی باید ازش استفاده کنم؟ 🆕

HTTP Mimicry ترافیک شما رو دقیقاً شبیه یک مرورگر واقعی می‌کنه. استفاده کن اگر:

- ✅ فیلترینگ DPI (Deep Packet Inspection) وجود داره
- ✅ ترافیک VPN/Proxy شما block می‌شه
- ✅ میخوای ترافیکت 100% طبیعی به نظر برسه
- ✅ از پورت 80 یا 443 استفاده می‌کنی

استفاده نکن اگر:

- ❌ سرعت اولویت مطلق است (overhead حدود 15-20%)
- ❌ برای gaming/VoIP (latency اضافی)
- ❌ فیلترینگ خاصی وجود ندارهnpm install

### ❓ چه زمانی Obfuscation رو فعال کنم؟

فعال کنید اگر:

- DPI/Filtering وجود داره
- ترافیک شما تحت نظارته
- میخواید pattern های ترافیک رو مخفی کنید
- از HTTP Mimicry استفاده می‌کنید (توصیه می‌شود)

غیرفعال کنید اگر:

- سرعت و تاخیر اولویت اوله
- برای gaming/VoIP استفاده میکنید
- شبکه محلی (LAN) استفاده می‌کنید

### ❓ Connection Pool چقدر باید باشه؟

| شرایط             | TCP/KCP | HTTP Mimicry |
| ----------------- | ------- | ------------ |
| **شبکه پایدار**   | 2-3     | 2-3          |
| **شبکه معمولی**   | 3-4     | 3-4          |
| **شبکه ناپایدار** | 5-6     | 4-6          |
| **بار بالا**      | 6-8     | 6-8          |

### ❓ بهترین Transport برای دور زدن فیلترینگ؟ 🆕

**توصیه: `httpsmux`** (HTTPS Mimicry)

مزایا:

- ✅ بالاترین سطح DPI bypass
- ✅ ترافیک 100% شبیه HTTPS
- ✅ TLS encryption
- ✅ قابل اعتماد

جایگزین‌ها:

- `httpmux` - اگر TLS نمی‌خواید
- `wssmux` - اگه WebSocket ترجیح می‌دید
- `kcpmux` - برای سرعت بالا (بدون DPI bypass قوی)

### ❓ چطور امنیت رو بالا ببرم؟

1. از PSK قوی استفاده کنید (32+ کاراکتر)
2. **`httpsmux` را فعال کنید** 🆕
3. Obfuscation را روشن کنید
4. فقط IP مشخص رو allow کنید
5. فایروال را درست تنظیم کنید
6. گواهی SSL معتبر استفاده کنید (نه self-signed)
7. PSK را مرتب عوض کنید

### ❓ چطور SMUX رو تنظیم کنم؟ 🆕

برای اکثر کاربران، پیش‌فرض‌ها کافیه. ولی برای بهینه‌سازی:

```yaml
# سرعت بالا
smux:
  keepalive: 5
  max_recv: 16777216
  max_stream: 16777216

# کم‌مصرف
smux:
  keepalive: 10
  max_recv: 8388608
  max_stream: 8388608

# Gaming
smux:
  keepalive: 2
  max_recv: 16777216
  max_stream: 16777216
```

### ❓ Bind و Target چه فرقی دارن؟ 🆕

- **Bind**: پورتی که روی **این سرور** باز می‌شه (کاربران به اینجا متصل می‌شن)
- **Target**: پورتی که ترافیک به اونجا **فوروارد** می‌شه

مثال:

```yaml
bind: "0.0.0.0:2222" # پورت 2222 باز می‌شه
target: "127.0.0.1:22" # ترافیک به SSH فوروارد می‌شه
```

---

## 📞 پشتیبانی

- 🐛 [گزارش باگ](https://github.com/itsFLoKi/DaggerConnect/issues)
- 💬 [بحث و گفتگو](https://github.com/itsFLoKi/DaggerConnect/discussions)
- 📧 **Telegram**: [Support](https://t.me/DDDDDTRIPLE)
- 📖 **Documentation**: [Wiki](https://github.com/itsFLoKi/DaggerConnect/wiki)

---

## 🙏 تشکر

- [xtaci/smux](https://github.com/xtaci/smux) - Stream multiplexing library
- [xtaci/kcp-go](https://github.com/xtaci/kcp-go) - KCP protocol implementation
- [gorilla/websocket](https://github.com/gorilla/websocket) - WebSocket library
- تمام کاربران و Contributors

---

## 📝 لایسنس

این پروژه تحت لایسنس اختصاصی منتشر شده و open-source نیست. تمامی حقوق محفوظ است.

---

## 🗓️ Changelog

### v1.1 (جدید!) 🆕

- ➕ اضافه شدن HTTP/HTTPS Mimicry Transport
- ➕ تنظیمات پیشرفته SMUX
- ➕ تنظیمات پیشرفته TCP/UDP
- ➕ Port Mapping پیشرفته (Bind/Target جداگانه)
- ➕ User-Agent Spoofing
- ➕ Cookie & Session Management
- ➕ Chunked Transfer Encoding
- ➕ Custom Headers Support
- ⚡ بهبود عملکرد Connection Pooling
- 🔧 بهبود Obfuscation Algorithm

### v1.0

- 🎉 انتشار اولیه
- ✨ پشتیبانی از TCP, KCP, WS, WSS
- 🎭 Traffic Obfuscation
- 📊 Connection Pooling
- 🔒 PSK Encryption

---

<div align="center">

⭐ **اگه مفید بود یه ستاره بدید!** ⭐

Made with ❤️ by [itsFLoKi](https://github.com/itsFLoKi)

**نسخه 1.1 - با HTTP Mimicry و Traffic Obfuscation پیشرفته**

[⬆ برگشت به بالا](#-daggerconnect)

</div>
