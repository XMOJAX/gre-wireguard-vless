<div align="center">

# ⚡ GRE + WireGuard + VLESS Tunnel Manager (Pro Edition)

### مدیریت خودکار و پایدار تانل‌های لینوکسی (ایران ⇄ خارج)

<p align="center">
  <img src="https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white" alt="Bash" />
  <img src="https://img.shields.io/badge/WireGuard-88171A?style=for-the-badge&logo=wireguard&logoColor=white" alt="WireGuard" />
  <img src="https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black" alt="Linux" />
  <img src="https://img.shields.io/badge/systemd-ready-007acc?style=for-the-badge" alt="systemd" />
  <img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="MIT License" />
</p>

<p align="center">
  <a href="#-quick-install--نصب-سریع"><b>Quick Install</b></a> •
  <a href="#-features--ویژگی‌ها"><b>Features</b></a> •
  <a href="#-architecture--معماری"><b>Architecture</b></a> •
  <a href="#-english-guide"><b>English Guide</b></a> •
  <a href="#-راهنمای-فارسی"><b>راهنمای فارسی</b></a> •
  <a href="#-xray--3x-ui-configuration"><b>Xray Setup</b></a>
</p>

---

</div>

## 🚀 Quick Install / نصب سریع

با اجرای یک خط دستور زیر در هر توزیع لینوکس (Ubuntu, Debian, ...)، اسکریپت به صورت یک دستور سیستمی همیشگی نصب می‌شود:

```bash
curl -fsSL https://raw.githubusercontent.com/XMOJAX/gre-wireguard-vless/main/install.sh | sudo bash
```

> [!TIP]
> پس از نصب، در هر زمان و از هر پوشه‌ای در ترمینال، تنها با تایپ دستور زیر برنامه اجرا می‌شود و دیگر نیازی به دانلود مجدد فایل نیست:
> ```bash
> sudo gwv
> ```

---

## ✨ Features / ویژگی‌ها

| قابلیت | توضیحات |
| :--- | :--- |
| **🛡️ تانل دو لایه پایدار (GRE + WG)** | کپسوله‌سازی ترافیک با تانل GRE همراه با شناسه کلید (Key) و رمزنگاری داده‌ها روی لایه WireGuard برای دور زدن محدودیت‌ها |
| **🔑 هماهنگی هوشمند با توکن (Token-Based)** | تولید خودکار توکن رمزشده‌ی Base64 حاوی تمام کلیدها و آی‌پی‌ها برای تنظیم سرور مقصد در کمتر از ۳ ثانیه |
| **⚙️ ماندگاری سیستمی (Auto Persistent)** | ساخت خودکار سرویس‌های `systemd` به طوری که حتی با ری‌استارت شدن سرور، ارتباط بدون قطعی وصل می‌ماند |
| **🔍 اسکنر هوشمند آی‌پی و پورت** | تشخیص خودکار پورت‌های باز UDP/TCP و آی‌پی‌های سرور برای جلوگیری از هرگونه تداخل |
| **📊 مدیریت چند تانل همزمان** | امکان ایجاد، مانیتور، تست اتصال (Ping) و حذف تمیز تانل‌ها بدون آسیب به سایر سرویس‌ها |
| **⚡ تنظیم داینامیک MTU** | بهینه‌سازی سایز پکت‌ها برای افزایش سرعت و پایداری شبکه با یک کلیک |
| **🔌 سازگار با پنل‌های Xray (3x-ui / Sanaei / Marzban)** | خروجی آماده برای تنظیم اینباند و اوت‌باند VLESS |

---

## 🏗️ Architecture / معماری

```
  [ کاربر / Client ]
          │
          ▼
┌──────────────────┐
│   Iran Server    │ (Source / Outbound)
│  (10.88.x.1)     │
└─────────┬────────┘
          │  ◄── [ GRE Tunnel (Key Protected) + WireGuard Encrypted ]
          │
┌─────────▼────────┐
│  Kharej Server   │ (Destination / Inbound)
│  (10.88.x.2)     │ ──► [ VLESS / Xray ] ──► [ اینترنت آزاد / Free Internet ]
└──────────────────┘
```

---

## 📖 English Guide

### 1. Requirements
- Linux Server (Ubuntu 20.04/22.04/24.04, Debian 11/12).
- Root privileges (`sudo -i`).

### 2. Setup Workflow
1. **On the Iran Server (Source):**
   - Run `sudo gwv` and choose option **`1) Source Server (Iran / Outbound)`**.
   - Enter a unique name for your tunnel (e.g. `germany`).
   - The script will generate a **`TOKEN`**. Copy this token.
2. **On the Kharej Server (Destination):**
   - Run `sudo gwv` and choose option **`2) Destination Server (Kharej / Inbound)`**.
   - Paste the **`TOKEN`** you copied from the Iran server.
   - The script will automatically link both servers and perform an automated connectivity ping test.
3. **Configure your Xray Panel (e.g. 3x-ui / Sanaei):**
   - Use the parameters printed on screen at the end of setup.

---

## 🇮🇷 راهنمای فارسی

### مرحله ۱: سرور ایران (مبدا / Outbound)
1. در ترمینال سرور ایران دستور `sudo gwv` را اجرا کنید.
2. گزینه **`1` (Source Server)** را انتخاب کنید.
3. یک نام دلخواه برای تانل بنویسید (مثلاً `de1`).
4. اسکریپت پورت‌ها و آی‌پی‌های آزاد را به صورت هوشمند پیدا می‌کند. می‌توانید با فشردن Enter مقادیر پیشنهادی را قبول کنید.
5. در پایان، یک **توکن طولانی (TOKEN)** به شما داده می‌شود؛ آن را کپی کنید.

### مرحله ۲: سرور خارج (مقصد / Inbound)
1. در ترمینال سرور خارج دستور `sudo gwv` را اجرا کنید.
2. گزینه **`2` (Destination Server)** را انتخاب کنید.
3. توکنی که از سرور ایران کپی کردید را پیست کرده و Enter بزنید.
4. تانل بلافاصله متصل شده و تست پینگ خودکار اجرا می‌شود.

### مرحله ۳: تنظیمات در پنل Sanaei / 3x-ui
در پایان عملیات، اطلاعات دقیق تنظیم پنل نمایش داده می‌شود:

- **در سرور خارج (Inbound):**
  - پروتکل: `VLESS`
  - آی‌پی گوش دادن (Listen IP): آی‌پی وایرگارد خارج (مثلاً `10.88.99.2`)
  - پورت: پورت اختصاص داده شده
  - آیدی (UUID): همان آیدی تولید شده توسط اسکریپت

- **در سرور ایران (Outbound):**
  - پروتکل: `VLESS`
  - آدرس (Address): آی‌پی وایرگارد خارج (`10.88.99.2`)
  - پورت و آیدی: مقادیر متناظر

---

## 🛠️ Management & Diagnostics / ابزارهای مدیریتی

در منوی اصلی برنامه گزینه‌های تکمیلی زیر در دسترس هستند:

```text
3) Manage / Delete Existing Tunnels   --> حذف تمیز سرویس‌های تانل بدون برجا ماندن فایل اضافه
4) View Setup History & Tokens        --> مشاهده تاریخچه تانل‌ها و توکن‌های ساخته‌شده
5) Test Tunnel Connections            --> تست زنده پینگ و پایداری به سرورهای مقابل
6) Change MTU of an Existing Tunnel   --> تغییر سریع سایز MTU برای بهبود پینگ و حل مشکل کاهش سرعت
0) Exit                               --> خروج
```

---

## 🗑️ Uninstallation / حذف برنامه

برای حذف کامل برنامه از سیستم:
```bash
sudo rm -f /usr/local/bin/gwv /usr/local/bin/gwv-tunnel
```

---

## 👨‍💻 Developer & Author

- **Author**: MOJA ([@XMOJAX](https://github.com/XMOJAX))
- **Role**: Web Developer • Network Engineer • Trader
- **Repository**: [https://github.com/XMOJAX/gre-wireguard-vless](https://github.com/XMOJAX/gre-wireguard-vless)

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.
