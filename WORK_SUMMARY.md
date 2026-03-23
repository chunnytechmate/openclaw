# OpenClaw Customization Summary

## Overview

เอกสารนี้สรุปการปรับแต่ง OpenClaw ตั้งแต่เริ่ม fork repo เมื่อ 17 มีนาคม 2026 ถึงปัจจุบัน

---

## Commit History

### 1. Initial Docker Setup (2026-03-17)

**Commit:** `adacd44502` - "check"

**วัตถุประสงค์:** เตรียม infrastructure พื้นฐานสำหรับการรัน OpenClaw บน Docker พร้อมรองรับ Python skills และ external services

**ไฟล์ที่เพิ่ม/แก้ไข:**

#### a) `.dockerignore` & `.gitignore`

- **ทำไม:** ลดขนาด Docker image โดยไม่รวมไฟล์ที่ไม่จำเป็น (node_modules, .git, etc.)
- **ประโยชน์:** เพิ่มความเร็วในการ build และลดขนาด image

#### b) `requirements.txt`

- **ทำไม:** ระบุ Python dependencies ที่ต้องใช้สำหรับ skills และ integrations
- **ประโยชน์:**
  - จัดการ Python dependencies อย่างเป็นระบบ
  - รองรับการเชื่อมต่อกับบริการต่างๆ:
    - Discord, LINE (messaging platforms)
    - Google AI, OpenAI, Anthropic (AI services)
    - Supabase (database)
    - Playwright (browser automation)
    - Typhoon ASR (Thai speech-to-text)

#### c) `supervisord.conf`

- **ทำไม:** จัดการหลายบริการใน container เดียว
- **ประโยชน์:**
  - รัน OpenClaw Gateway และ Typhoon API พร้อมกัน
  - Auto-restart หากบริการล้มเหลว
  - รวม logs ไว้ที่เดียว (stdout/stderr)
  - ส่ง environment variables ไปยังทุกบริการ

#### d) `docker-compose.yml` (Initial)

- **ทำไม:** จัดการ container และ environment variables อย่างเป็นระบบ
- **ประโยชน์:**
  - รองรับ environment variables จำนวนมากสำหรับ integrations
  - เตรียม volumes สำหรับ workspace และ config
  - แยก gateway service และ CLI service

#### e) `Dockerfile` (Initial)

- **ทำไม:** เพิ่ม Python runtime และ dependencies เข้าไปใน image
- **ประโยชน์:**
  - ติดตั้ง Python 3 และ pip
  - ติดตั้ง packages จาก requirements.txt
  - เตรียมไดเรกทอรีสำหรับ Typhoon models

---

### 2. Multi-Instance Support (2026-03-18)

**Commit:** `0adee06375` - "now openclaw work"

**วัตถุประสงค์:** แก้ปัญหาการรันหลาย OpenClaw instances บน host เดียวกันโดยไม่ชนพอร์ต

**ปัญหาเดิม:**

- Port mapping และ healthcheck ถูก hardcode ไว้ที่ port 18789
- Gateway bind อยู่ที่ loopback (127.0.0.1) ทำให้ไม่สามารถเข้าถึงจากภายนอก container ได้

**ไฟล์ที่เพิ่ม/แก้ไข:**

#### a) `DOCKER_SETUP_GUIDE.md`

- **ทำไม:** เอกสารอธิบายวิธีรันหลาย instances อย่างถูกต้อง
- **เนื้อหา:**
  - อธิบายปัญหาและ solution
  - วิธีสร้าง environment files สำหรับแต่ละ instance
  - วิธีเริ่มและจัดการหลาย instances
  - ตัวอย่างการแก้ไข gateway bind setting
  - Troubleshooting guide

#### b) `docker-compose.yml` (Updated)

**การแก้ไขสำคัญ:**

**Dynamic Port Mapping (lines 56-59):**

```yaml
ports:
  - "${OPENCLAW_GATEWAY_PORT:-18789}:${OPENCLAW_GATEWAY_PORT:-18789}"
  - "${OPENCLAW_BRIDGE_PORT:-18790}:${OPENCLAW_BRIDGE_PORT:-18790}"
```

- **ทำไม:** ทั้ง host port และ container port ใช้ environment variable เดียวกัน
- **ประโยชน์:** รัน instances หลายตัวด้วย ports ต่างกันได้

**Dynamic Healthcheck (lines 62-73):**

```yaml
healthcheck:
  test:
    - CMD
    - sh
    - -c
    - 'node -e "fetch(''http://127.0.0.1:${OPENCLAW_GATEWAY_PORT:-18789}/healthz'')..."'
```

- **ทำไม:** Healthcheck ต้องใช้ port เดียวกับ gateway ที่กำลังรันอยู่
- **ประโยชน์:** Container health status ถูกต้องแม้ใช้ custom ports

#### c) `Dockerfile` (Updated)

**การปรับปรุง:**

- เพิ่ม supervisor เข้าไปใน runtime image
- Copy supervisord.conf เข้าไปใน container
- เปลี่ยน CMD เป็น supervisord เพื่อรันหลายบริการ

**ทำไม:** เพื่อรันทั้ง OpenClaw Gateway และ Typhoon API ใน container เดียว

#### d) `package.json` & `pnpm-lock.yaml`

- **ทำไม:** เพิ่ม Node.js dependencies ที่จำเป็นสำหรับ project
- **ประโยชน์:** ระบุ versions ที่แน่นอนของแต่ละ package

---

## สถาปัตยกรรมที่ได้

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Host                               │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────┐  ┌─────────────────────┐          │
│  │  openclaw-chunny_1  │  │  openclaw-chunny_2  │          │
│  │  ┌─────────────────┐ │  │  ┌─────────────────┐ │          │
│  │  │    Supervisord  │ │  │  │    Supervisord  │ │          │
│  │  │  ┌───────────┐  │ │  │  │  ┌───────────┐  │ │          │
│  │  │  │  Gateway  │  │ │  │  │  │  Gateway  │  │ │          │
│  │  │  │  Port:19789│ │ │  │  │  │  Port:19799│ │ │          │
│  │  │  └───────────┘  │ │  │  │  └───────────┘  │ │          │
│  │  │  ┌───────────┐  │ │  │  │  ┌───────────┐  │ │          │
│  │  │  │  Typhoon  │  │ │  │  │  │  Typhoon  │  │ │          │
│  │  │  │  API:8000 │  │ │  │  │  │  API:8000 │  │ │          │
│  │  │  └───────────┘  │ │  │  │  └───────────┘  │ │          │
│  │  └─────────────────┘ │  │  └─────────────────┘ │          │
│  │    data/chunny_1/    │  │    data/chunny_2/    │          │
│  └─────────────────────┘  └─────────────────────┘          │
│                                                              │
│  typhoon/ (shared volume for Typhoon models)                │
└─────────────────────────────────────────────────────────────┘
```

---

## Environment Variables ที่รองรับ

| Category          | Variables                                                                           |
| ----------------- | ----------------------------------------------------------------------------------- |
| **OpenClaw Core** | OPENCLAW_GATEWAY_TOKEN, OPENCLAW_GATEWAY_PORT, OPENCLAW_BRIDGE_PORT                 |
| **Claude**        | CLAUDE_AI_SESSION_KEY, CLAUDE_WEB_SESSION_KEY, CLAUDE_WEB_COOKIE                    |
| **AI Services**   | ANTHROPIC_AUTH_TOKEN, ZAI_API_KEY, MINIMAX_API_KEY, OPENAI_API_KEY, GOOGLE_API_KEY  |
| **Discord**       | DISCORD_BOT_TOKEN, DISCORD_USER_ID, DISCORD_CHANNEL_ID, etc.                        |
| **LINE**          | LINE_CHANNEL_ACCESS_TOKEN, LINE_CHANNEL_SECRET, LINE_USER_PI_PRAO, LINE_USER_CHUNNY |
| **Other**         | NOTION_API_TOKEN, BRAVE_API_KEY, DEEPGRAM_API_KEY, SUPABASE_PROJECT_URL             |

---

## วิธีใช้งาน

### เริ่มต้น Instance ใหม่:

```bash
# 1. สร้าง environment file
cp .env.chunny_1 .env.my_instance

# 2. แก้ไข ports และ paths
# .env.my_instance
COMPOSE_PROJECT_NAME=openclaw-my_instance
OPENCLAW_GATEWAY_PORT=19889
OPENCLAW_CONFIG_DIR=./data/my_instance
OPENCLAW_WORKSPACE_DIR=./data/my_instance/workspace

# 3. เริ่ม container
docker compose -p openclaw-my_instance --env-file .env.my_instance up -d

# 4. แก้ไข gateway bind (ครั้งแรกเท่านั้น)
sed -i 's/"bind": "loopback"/"bind": "lan"/' data/my_instance/openclaw.json
docker compose -p openclaw-my_instance restart
```

---

## Files Changed Summary

| File                    | Status   | Purpose                                           |
| ----------------------- | -------- | ------------------------------------------------- |
| `.dockerignore`         | New      | Exclude unnecessary files from Docker build       |
| `.gitignore`            | New      | Exclude files from git tracking                   |
| `DOCKER_SETUP_GUIDE.md` | New      | Documentation for multi-instance setup            |
| `requirements.txt`      | New      | Python dependencies list                          |
| `supervisord.conf`      | New      | Process manager configuration                     |
| `Dockerfile`            | Modified | Added Python, supervisord, runtime improvements   |
| `docker-compose.yml`    | Modified | Dynamic ports, healthcheck, environment variables |
| `package.json`          | Modified | Updated Node.js dependencies                      |
| `pnpm-lock.yaml`        | New      | Locked dependency versions                        |

---

## Next Steps (Optional Improvements)

1. **Automation:** สร้าง script สำหรับสร้าง instance ใหม่อัตโนมัติ
2. **Monitoring:** เพิ่ม Prometheus metrics สำหรับ monitoring
3. **Security:** ใช้ Docker secrets แทน environment variables สำหรับ sensitive data
4. **Scaling:** ใช้ Docker Swarm หรือ Kubernetes สำหรับ production deployment
