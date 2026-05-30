"""
main.py — Chạy DUY NHẤT 1 file này.
Gộp reminder.py + interaction.py chạy đồng thời bằng asyncio:
  - reminder_loop: kiểm tra và nhắc uống thuốc mỗi 3 giây
  - interaction_loop: lắng nghe câu hỏi và trả lời bằng AI
"""

import asyncio
import requests
import sounddevice as sd
import wave
import speech_recognition as sr
import time
import subprocess
import threading
import socket
from datetime import datetime, timedelta, timezone
from collections import deque
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn

from mini import mini_sdk as MiniSdk
from mini.dns.dns_browser import WiFiDevice
from mini.apis.api_sound import PlayAudio
from mini.apis.api_action import PlayAction

# ===== CONFIG =====
ROBOT_IP = "172.20.10.2"
ROBOT_PORT = 20008

ELDERLY_ID = 41
ROBOT_ID = 1
ELDERLY_IDS = [41, 4, 24]

BASE_URL = "https://sep490-be-3.onrender.com"
LOGIN_API = f"{BASE_URL}/api/login"
INTERACTION_API = f"{BASE_URL}/api/interaction-logs"
REMINDER_API = f"{BASE_URL}/api/reminders/elderly"
DONE_API = f"{BASE_URL}/api/reminders"
LOG_API = f"{BASE_URL}/api/reminder-logs"
ALERT_API = f"{BASE_URL}/api/alerts"
ACTION_API      = f"{BASE_URL}/api/robot-action/latest"
ACTION_DONE_API = f"{BASE_URL}/api/robot-action"
TTS_PREFIX      = "TTS:"   # Flutter gửi "TTS:nội dung" → robot nói

EMAIL = "duynnse171414@fpt.edu.vn"
PASSWORD = "12345678"

GEMINI_API_KEY = "AIzaSyCSZCn9WKb-iDKt6HUDDzZs-PXfAOOhb3M"
FPT_API_KEY = "LF6t9859CSmqpf0M5ZN07jpbubo7Zyay"
FPT_TTS_URL = "https://api.fpt.ai/hmi/tts/v5"

# ── Camera / Live Stream ──────────────────────────────────────────
CAM_HTTP_PORT  = 8080
CAM_TARGET_FPS = 25
CAM_WIDTH      = 480
CAM_QUALITY    = 3          # ffmpeg JPEG quality (1=best, 31=worst)
CAM_BITRATE    = '2000000'  # 2 Mbps H264
SCRCPY_DIR     = r'C:\Users\Dell\Downloads\scrcpy-win64-v3.3.4\scrcpy-win64-v3.3.4'
ADB_PATH       = rf'{SCRCPY_DIR}\adb.exe'
FFMPEG_PATH    = rf'{SCRCPY_DIR}\ffmpeg.exe'
CAM_DEVICE_ID  = '010058YUD18112301945'

# ===== GLOBAL =====
TOKEN = None
connected = False

# Lock chung: robot chỉ nói 1 việc tại 1 thời điểm
robot_lock = asyncio.Lock()

# Mic lock: chỉ 1 loop được thu âm tại 1 thời điểm
mic_lock = asyncio.Lock()

# Flag: reminder đang chờ xác nhận → interaction phải nhường mic
reminder_active = asyncio.Event()

# Reminder state
reminder_queue = deque()
processing_keys = set()
last_reset_date = None
tts_cache = {}

# Action state
last_action_id = None

# Camera state
_cam_frame: bytes = b""
_cam_lock  = threading.Lock()
_cam_running = True
_cam_stats   = {'frames': 0, 'fps': 0.0, 'last': time.time()}

# Cache action library từ API — tự động cập nhật khi fetch
# Mỗi entry: {"code": "012", "name": "Hít đất", "duration": 6, ...}
action_library_cache = []

# ===== LOGIN =====
def login():
    global TOKEN
    res = requests.post(LOGIN_API, json={"email": EMAIL, "password": PASSWORD})
    print("🔑 Login:", res.status_code)
    if res.status_code != 200:
        return False
    TOKEN = res.json().get("token")
    if not TOKEN:
        return False
    print("✅ Token OK")
    return True


def get_headers():
    return {"Authorization": f"Bearer {TOKEN}"}


# ===== ROBOT CONNECT =====
async def ensure_connection():
    global connected
    if connected:
        return
    try:
        MiniSdk.set_robot_type(MiniSdk.RobotType.EDU)
        device = WiFiDevice(name="AlphaMini", address=ROBOT_IP, port=ROBOT_PORT)
        await MiniSdk.connect(device)
        await asyncio.sleep(2)
        connected = True
        print("✅ Robot connected")
    except Exception as e:
        print("❌ Connect lỗi:", e)
        connected = False


# ===== TTS =====
def text_to_speech(text):
    if text in tts_cache:
        return tts_cache[text]
    try:
        res = requests.post(
            FPT_TTS_URL,
            data=text.encode("utf-8"),
            headers={"api-key": FPT_API_KEY, "voice": "banmai"}
        )
        url = res.json().get("async")
        if not url:
            return None
        for _ in range(15):
            r = requests.get(url)
            if r.status_code == 200:
                tts_cache[text] = url
                return url
            time.sleep(0.2)
        return url
    except:
        return None


# ===== ROBOT SPEAK (dùng lock chung) =====
async def robot_speak(text):
    global connected
    async with robot_lock:
        try:
            await ensure_connection()
            url = text_to_speech(text)
            if not url:
                print("❌ TTS lỗi")
                return
            print("🤖:", text)
            block = PlayAudio(url=url)
            await block.execute()
            await asyncio.sleep(2)
        except Exception as e:
            print("⚠️ Robot lỗi → reconnect:", e)
            connected = False
            try:
                await ensure_connection()
                block = PlayAudio(url=url)
                await block.execute()
            except:
                print("❌ Robot vẫn lỗi, bỏ qua")


# ================================================================
# ROBOT ACTION
# ================================================================

def fetch_action_library():
    """
    Lấy danh sách động tác từ API và lưu vào cache.
    Gọi lúc khởi động và định kỳ mỗi 5 phút trong action_poll_loop.
    """
    global action_library_cache
    try:
        res = requests.get(
            f"{BASE_URL}/api/action-library",
            headers=get_headers(),
            timeout=10
        )
        if res.status_code == 200:
            data = res.json()
            if isinstance(data, list):
                action_library_cache = data
                names = [a.get("name", "") for a in data]
                print(f"✅ Action library: {len(data)} động tác — {names}")
    except Exception as e:
        print(f"❌ Fetch action library lỗi: {e}")


def get_action_duration(code: str) -> int:
    """Lấy duration từ cache, fallback 5 giây nếu NULL."""
    for action in action_library_cache:
        if action.get("code") == code:
            d = action.get("duration")
            if d and int(d) > 0:
                return int(d)
    return 5


def map_voice_to_action(text: str):
    """
    So khớp giọng nói với action library từ API.
    Chỉ những động tác có trong DB mới được thực hiện.
    Khi thêm động tác mới vào DB → tự động nhận diện, không cần sửa code.
    """
    lower = text.lower().strip()

    for action in action_library_cache:
        code = action.get("code", "").strip()
        name = action.get("name", "").lower().strip()
        description = action.get("description", "").lower().strip()

        if not code:
            continue

        # Khớp nếu tên động tác xuất hiện trong câu nói (hoặc ngược lại)
        if name and (name in lower or lower in name):
            return code

        # Khớp thêm theo description (vd: "robot chống đẩy" → "hít đất")
        if description and description in lower:
            return code

    return None


# Từ khoá cho thấy người dùng đang yêu cầu thực hiện một động tác
_ACTION_INTENT_KEYWORDS = [
    "động tác", "bài tập", "tập", "thực hiện", "làm động tác",
    "vận động", "múa", "nhảy", "hít", "yoga", "cúi", "vỗ tay",
    "đứng", "ngồi xuống", "đi bộ", "chạy bộ", "giãn cơ", "khởi động",
]

def is_action_request(text: str) -> bool:
    """
    Trả về True nếu câu nói có ý định yêu cầu động tác.
    Dùng để phân biệt "nói động tác không có trong DB" vs "câu hỏi bình thường".
    """
    lower = text.lower()
    return any(kw in lower for kw in _ACTION_INTENT_KEYWORDS)


async def play_action(action_code: str):
    """Thực hiện động tác robot. Dùng robot_lock để không xung đột với robot_speak."""
    global connected
    duration = get_action_duration(action_code)
    async with robot_lock:
        try:
            await ensure_connection()
            print(f"🤸 Thực hiện động tác: {action_code} ({duration}s)")
            block = PlayAction(action_name=action_code)
            await block.execute()
            await asyncio.sleep(duration)
            print(f"✅ Xong động tác: {action_code}")
        except Exception as e:
            print(f"⚠️ Action lỗi → reconnect: {e}")
            connected = False
            try:
                await ensure_connection()
                block = PlayAction(action_name=action_code)
                await block.execute()
                await asyncio.sleep(duration)
            except Exception as e2:
                print(f"❌ Action retry fail: {e2}")


def fetch_latest_web_action():
    """Lấy action mới nhất được gửi từ web app."""
    try:
        res = requests.get(ACTION_API, headers=get_headers(), timeout=10)
        if res.status_code == 200:
            data = res.json()
            if data and data.get("action") and not data.get("executed", True):
                return data
    except Exception as e:
        print(f"❌ Fetch action lỗi: {e}")
    return None


def mark_action_done(action_id: int):
    try:
        requests.post(
            f"{ACTION_DONE_API}/{action_id}/done",
            headers=get_headers(),
            timeout=10
        )
    except:
        pass


# ================================================================
# ACTION POLL LOOP — nhận lệnh động tác từ web app
# ================================================================

async def action_poll_loop():
    """
    Kiểm tra API mỗi 3 giây xem có action mới từ web không.
    Refresh action library mỗi 5 phút để tự động nhận diện động tác mới.
    """
    global last_action_id
    print("🎮 Action poll loop started")

    last_library_refresh = 0

    while True:
        try:
            now = time.time()

            # Refresh action library mỗi 5 phút
            if now - last_library_refresh > 300:
                await asyncio.to_thread(fetch_action_library)
                last_library_refresh = now

            # Nhường khi reminder đang chờ xác nhận
            if not reminder_active.is_set():
                data = fetch_latest_web_action()
                if data:
                    action_id   = data.get("id")
                    action_code = data.get("action", "")

                    if action_id != last_action_id and action_code:
                        last_action_id = action_id

                        if action_code.startswith(TTS_PREFIX):
                            # Flutter gửi tin nhắn thoại → robot nói
                            text = action_code[len(TTS_PREFIX):].strip()
                            print(f"💬 TTS từ app: '{text}'")
                            await robot_speak(text)
                        else:
                            # Lệnh động tác từ web
                            print(f"🌐 Action từ web: {action_code}")
                            await play_action(action_code)

                        mark_action_done(action_id)

        except Exception as e:
            print(f"❌ Action poll lỗi: {e}")

        await asyncio.sleep(3)


# ================================================================
# REMINDER LOOP
# ================================================================

def fetch_all_reminders():
    all_reminders = []
    for elderly_id in ELDERLY_IDS:
        try:
            res = requests.get(
                f"{REMINDER_API}/{elderly_id}",
                headers=get_headers()
            )
            if res.status_code != 200:
                continue
            data = res.json()
            for r in data:
                r["elderlyId"] = elderly_id
            all_reminders.extend(data)
        except Exception as e:
            print("❌ Fetch reminder lỗi:", e)
    return all_reminders


def is_time_to_remind(schedule_time_str):
    try:
        utc = datetime.fromisoformat(schedule_time_str.replace("Z", "+00:00"))
        vn = utc + timedelta(hours=7)
        now = datetime.now()
        return vn <= now <= vn + timedelta(minutes=2)
    except:
        return False


def mark_reminder_done(reminder_id):
    try:
        requests.post(f"{DONE_API}/{reminder_id}/done", headers=get_headers())
        print("✅ DONE REMINDER")
    except:
        pass


def create_reminder_log(reminder_id, elderly_id):
    try:
        data = {
            "reminderId": reminder_id,
            "elderlyId": elderly_id,
            "robotId": ROBOT_ID,
            "triggeredTime": datetime.now().isoformat()
        }
        res = requests.post(LOG_API, json=data, headers=get_headers())
        if res.status_code == 200:
            return res.json().get("id")
    except:
        pass
    return None


def confirm_reminder_log(log_id):
    try:
        requests.post(f"{LOG_API}/{log_id}/confirm", headers=get_headers())
    except:
        pass


def create_alert(elderly_id, name, title):
    try:
        data = {
            "elderlyId": elderly_id,
            "elderlyName": name,
            "alertType": "MEDICATION_MISSED",
            "message": f"{name} chưa xác nhận: {title}",
            "resolved": False,
            "createdAt": datetime.now(timezone.utc).isoformat()
        }
        requests.post(ALERT_API, json=data, headers=get_headers())
    except:
        pass


def record_audio(duration=3):
    fs = 16000
    print("🎤 Nói đi...")
    recording = sd.rec(int(duration * fs), samplerate=fs, channels=1, dtype='int16')
    sd.wait()
    with wave.open("voice.wav", 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(fs)
        wf.writeframes(recording.tobytes())


def speech_to_text():
    r = sr.Recognizer()
    try:
        with sr.AudioFile("voice.wav") as source:
            audio = r.record(source)
        text = r.recognize_google(audio, language="vi-VN")
        print("🧠:", text)
        return text.lower()
    except:
        return ""


def is_confirmed(text):
    return any(p in text for p in ["đã", "rồi", "ok", "xong", "ăn rồi", "uống rồi"])


async def process_reminder(r):
    reminder_id = r["id"]
    elderly_id = r["elderlyId"]
    name = r.get("elderlyName", "bạn")
    title = r["title"]
    key = f"{elderly_id}_{reminder_id}"

    if key in processing_keys:
        return
    processing_keys.add(key)

    print(f"⏰ Nhắc: {name} - {title}")
    log_id = create_reminder_log(reminder_id, elderly_id)

    # Báo interaction_loop biết: reminder đang chiếm mic, không được thu âm
    reminder_active.set()
    try:
        for attempt in range(3):
            await robot_speak(f"{name}, đã đến giờ {title}")

            # Chiếm mic lock rồi mới thu âm
            async with mic_lock:
                await asyncio.to_thread(record_audio, 3)
                text = await asyncio.to_thread(speech_to_text)

            if is_confirmed(text):
                await robot_speak("Tôi đã ghi nhận")
                if log_id:
                    confirm_reminder_log(log_id)
                mark_reminder_done(reminder_id)
                print(f"✅ {name} xác nhận {title}")
                return

            if attempt < 2:
                await robot_speak("Bạn cần xác nhận")
            await asyncio.sleep(1)

        # Quá 3 lần không xác nhận → tạo alert
        create_alert(elderly_id, name, title)
        print(f"🚨 Alert: {name} không xác nhận {title}")

    finally:
        # Dù thành công hay thất bại đều trả mic lại cho interaction
        reminder_active.clear()
        print("🟢 Reminder xong, interaction_loop tiếp tục")


async def reminder_loop():
    """Chạy nền: kiểm tra reminder mỗi 3 giây."""
    global last_reset_date
    print("🔔 Reminder loop started")

    while True:
        try:
            now = datetime.now()

            # Reset processing_keys mỗi ngày mới
            if last_reset_date != now.date():
                processing_keys.clear()
                last_reset_date = now.date()
                print("🧹 Reset ngày mới")

            reminders = fetch_all_reminders()

            for r in reminders:
                if not r.get("active"):
                    continue
                if is_time_to_remind(r["scheduleTime"]):
                    reminder_queue.append(r)

            if reminder_queue:
                await process_reminder(reminder_queue.popleft())

        except Exception as e:
            print("❌ Reminder loop lỗi:", e)

        await asyncio.sleep(3)


# ================================================================
# MEDICATION CONTEXT (nội dung của shared_context.py gộp vào đây)
# ================================================================

def is_medication_question(text: str) -> bool:
    keywords = [
        "thuốc", "uống thuốc", "nhắc thuốc", "lịch uống",
        "mấy lần", "bao nhiêu lần", "còn lại", "nhắc nhở",
        "uống chưa", "quên uống", "đã uống", "còn mấy", "còn bao",
    ]
    return any(k in text.lower() for k in keywords)


def get_today_medication_summary() -> dict:
    """
    Query API để biết hôm nay còn bao nhiêu lần uống thuốc chưa xác nhận.
    - reminder_loop đã gọi confirm_reminder_log() khi người dùng xác nhận
    - Hàm này đọc lại từ backend → luôn chính xác theo thời gian thực
    """
    headers = get_headers()
    today_vn = datetime.now().date()

    # 1. Lấy tất cả reminders của người cao tuổi hôm nay
    try:
        res = requests.get(
            f"{REMINDER_API}/{ELDERLY_ID}",
            headers=headers,
            timeout=10
        )
        reminders = res.json() if res.status_code == 200 else []
        if not isinstance(reminders, list):
            reminders = []
    except Exception as e:
        print(f"[medication] Lỗi fetch reminders: {e}")
        reminders = []

    # Lọc những reminder có scheduleTime rơi vào hôm nay (UTC → VN +7h)
    today_reminders = []
    for r in reminders:
        schedule_str = r.get("scheduleTime", "")
        if not schedule_str:
            continue
        try:
            utc = datetime.fromisoformat(schedule_str.replace("Z", "+00:00"))
            vn_time = utc + timedelta(hours=7)
            if vn_time.date() == today_vn:
                today_reminders.append({**r, "_vn_time": vn_time})
        except Exception:
            pass

    total = len(today_reminders)
    if total == 0:
        return {"total": 0, "done": 0, "remaining": 0,
                "remaining_times": [], "remaining_titles": []}

    # 2. Lấy reminder-logs hôm nay → tìm những cái đã confirmed
    try:
        log_res = requests.get(
            f"{BASE_URL}/api/reminder-logs/elderly/{ELDERLY_ID}",
            headers=headers,
            timeout=10
        )
        logs = log_res.json() if log_res.status_code == 200 else []
        if not isinstance(logs, list):
            logs = []
    except Exception as e:
        print(f"[medication] Lỗi fetch logs: {e}")
        logs = []

    # reminderId nào đã confirmed hôm nay
    confirmed_ids = set()
    for log in logs:
        triggered = log.get("triggeredTime", log.get("createdAt", ""))
        try:
            lt = datetime.fromisoformat(triggered.replace("Z", "+00:00"))
            lt_vn = lt + timedelta(hours=7)
            if lt_vn.date() == today_vn and log.get("confirmed", False):
                confirmed_ids.add(log.get("reminderId"))
        except Exception:
            pass

    remaining = [r for r in today_reminders if r["id"] not in confirmed_ids]
    done_count = total - len(remaining)

    return {
        "total": total,
        "done": done_count,
        "remaining": len(remaining),
        "remaining_times": [r["_vn_time"].strftime("%H:%M") for r in remaining],
        "remaining_titles": [r.get("title", "") for r in remaining],
    }


def build_medication_answer(summary: dict) -> str:
    total = summary["total"]
    if total == 0:
        return "Hôm nay không có lịch uống thuốc nào."

    remaining = summary["remaining"]
    done = summary["done"]

    if remaining == 0:
        return f"Hôm nay bạn đã uống thuốc đủ {total} lần rồi, không còn lần nào nữa."

    times = summary["remaining_times"]
    times_str = " và ".join(times) if len(times) > 1 else (times[0] if times else "")

    answer = f"Hôm nay có {total} lần uống thuốc, đã uống {done} lần, còn {remaining} lần chưa uống."
    if times_str:
        answer += f" Lần còn lại vào lúc {times_str}."
    if summary["remaining_titles"]:
        answer += f" Nội dung: {', '.join(summary['remaining_titles'])}."
    return answer


# ================================================================
# INTERACTION LOOP
# ================================================================

def handle_special_question(text):
    lower = text.lower()

    if "mấy giờ" in lower or "bây giờ" in lower:
        now = datetime.now()
        return f"Bây giờ là {now.strftime('%H:%M')} ngày {now.strftime('%d/%m/%Y')}"

    # Câu hỏi về thuốc → query backend (reminder_loop đã confirm lên đó)
    if is_medication_question(lower):
        print("[interaction] Câu hỏi thuốc → query backend...")
        summary = get_today_medication_summary()
        return build_medication_answer(summary)

    return None


def ask_gemini(user_text):
    MODELS = ["models/gemini-flash-latest", "models/gemini-2.0-flash"]
    now_str = datetime.now().strftime("%H:%M ngày %d/%m/%Y")

    # Inject medication context nếu câu hỏi phức hợp lọt xuống đây
    med_context = ""
    if is_medication_question(user_text.lower()):
        summary = get_today_medication_summary()
        med_context = (
            f"\n[Lịch thuốc hôm nay: tổng {summary['total']} lần, "
            f"đã uống {summary['done']}, còn lại {summary['remaining']} lần"
            + (f" vào lúc {', '.join(summary['remaining_times'])}" if summary["remaining_times"] else "")
            + "]\n"
        )

    prompt = (
        f"Hiện tại là {now_str} (giờ Việt Nam).{med_context}\n"
        "Bạn là robot chăm sóc người già. Trả lời NGẮN, dễ hiểu, không markdown.\n\n"
        f"Người dùng hỏi: {user_text}"
    )

    for model in MODELS:
        try:
            url = (
                f"https://generativelanguage.googleapis.com/v1beta/"
                f"{model}:generateContent?key={GEMINI_API_KEY}"
            )
            body = {"contents": [{"parts": [{"text": prompt}]}]}

            for attempt in range(3):
                res = requests.post(url, json=body)
                if res.status_code == 200:
                    return res.json()["candidates"][0]["content"]["parts"][0]["text"]
                elif res.status_code == 503:
                    print(f"⚠️ {model} quá tải, retry {attempt+1}")
                    time.sleep(2)
                else:
                    print("❌ Gemini lỗi:", res.status_code)
                    break
        except Exception as e:
            print("❌ Exception:", e)

    return "Xin lỗi, hệ thống đang bận"


def save_interaction(user_text, bot_text):
    try:
        res = requests.post(INTERACTION_API, json={
            "elderlyId": ELDERLY_ID,
            "robotId": ROBOT_ID,
            "interactionType": "CHAT",
            "userInputText": user_text,
            "robotResponseText": bot_text,
            "emotionDetected": "NORMAL"
        }, headers=get_headers())
        print("💾 SAVE:", res.status_code)
    except Exception as e:
        print("❌ Save lỗi:", e)


async def interaction_loop():
    """Chạy nền: lắng nghe và trả lời câu hỏi / thực hiện động tác."""
    print("🟢 Interaction loop started")

    while True:
        try:
            # Chờ khi:
            #  - reminder đang chờ xác nhận (reminder_active)
            #  - robot đang nói / làm động tác / phát TTS (robot_lock.locked())
            # → tránh mic thu âm trong lúc robot đang phát ra tiếng
            while reminder_active.is_set() or robot_lock.locked():
                await asyncio.sleep(0.3)

            # Thu âm (mic_lock đảm bảo không tranh với reminder)
            async with mic_lock:
                await asyncio.to_thread(record_audio, 4)
                user_text = await asyncio.to_thread(speech_to_text)

            if not user_text:
                continue

            # 1. Ưu tiên: khớp động tác trong DB → thực hiện
            action_code = map_voice_to_action(user_text)
            if action_code:
                print(f"🎯 Voice action: '{user_text}' → {action_code}")
                await play_action(action_code)
                await asyncio.to_thread(
                    save_interaction, user_text, f"[ACTION:{action_code}]"
                )
                continue

            # 2. Có intent động tác nhưng không khớp DB → báo không có
            if is_action_request(user_text):
                bot_text = "Xin lỗi, tôi không có động tác này."
                print(f"❓ Action không tồn tại: '{user_text}'")
                await robot_speak(bot_text)
                await asyncio.to_thread(save_interaction, user_text, bot_text)
                continue

            # 3. Câu hỏi đặc biệt (giờ, thuốc) → trả lời trực tiếp
            bot_text = handle_special_question(user_text)

            # 4. Còn lại → Gemini AI
            if not bot_text:
                bot_text = await asyncio.to_thread(ask_gemini, user_text)

            await robot_speak(bot_text)
            await asyncio.to_thread(save_interaction, user_text, bot_text)

        except Exception as e:
            print("❌ Interaction loop lỗi:", e)


# ================================================================
# CAMERA — Live Stream (H264 → ffmpeg → MJPEG HTTP)
# Chạy trong background thread riêng, độc lập với asyncio
# ================================================================

def _get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except:
        return "127.0.0.1"


def _read_jpeg_frames(ffmpeg_proc):
    """Đọc JPEG frames từ ffmpeg stdout, tách bằng marker FF D8 FF … FF D9."""
    global _cam_frame
    buf = b""

    while _cam_running:
        chunk = ffmpeg_proc.stdout.read(32768)
        if not chunk:
            break
        buf += chunk

        while True:
            start = buf.find(b'\xff\xd8\xff')
            if start == -1:
                buf = b""
                break
            end = buf.find(b'\xff\xd9', start + 2)
            if end == -1:
                buf = buf[start:]
                break

            frame = buf[start:end + 2]
            buf   = buf[end + 2:]

            if len(frame) < 500:
                continue

            with _cam_lock:
                _cam_frame = frame

            _cam_stats['frames'] += 1
            now = time.time()
            if now - _cam_stats['last'] >= 3:
                _cam_stats['fps'] = _cam_stats['frames'] / (now - _cam_stats['last'])
                print(f"  📷 Camera FPS: {_cam_stats['fps']:.1f} | "
                      f"{len(frame)//1024}KB/frame")
                _cam_stats['frames'] = 0
                _cam_stats['last']   = now


def _camera_capture_loop():
    """
    Pipeline: adb screenrecord (H264) → ffmpeg → JPEG frames.
    screenrecord giới hạn 180s → vòng while tự restart.
    """
    global _cam_running
    height = int(CAM_WIDTH * 16 / 9)

    adb_cmd = [
        ADB_PATH, '-s', CAM_DEVICE_ID,
        'exec-out', 'screenrecord',
        '--output-format=h264',
        '--size', f'{CAM_WIDTH}x{height}',
        '--bit-rate', CAM_BITRATE,
        '-',
    ]
    ffmpeg_cmd = [
        FFMPEG_PATH, '-loglevel', 'quiet',
        '-f', 'h264', '-i', 'pipe:0',
        '-vf', f'fps={CAM_TARGET_FPS},scale={CAM_WIDTH}:-1',
        '-f', 'image2pipe', '-vcodec', 'mjpeg',
        '-q:v', str(CAM_QUALITY), 'pipe:1',
    ]

    print("📷 Camera pipeline starting...")
    while _cam_running:
        adb_proc = ffmpeg_proc = None
        try:
            adb_proc = subprocess.Popen(
                adb_cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
            ffmpeg_proc = subprocess.Popen(
                ffmpeg_cmd, stdin=adb_proc.stdout,
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
            adb_proc.stdout.close()   # parent đóng để child nhận EOF

            print("✅ Camera pipeline running")
            _read_jpeg_frames(ffmpeg_proc)

        except Exception as e:
            print(f"⚠️  Camera pipeline lỗi: {e}")
        finally:
            for p in (ffmpeg_proc, adb_proc):
                if p:
                    try: p.kill()
                    except: pass

        if _cam_running:
            print("🔄 Camera restart...")
            time.sleep(1)


class _CamThreadedServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True


class _CamHandler(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def do_GET(self):
        path = self.path.split('?')[0]
        if path in ('/stream', '/mjpeg', '/video'):
            self._mjpeg()
        elif path == '/snapshot':
            self._snapshot()
        elif path == '/':
            self._index()
        else:
            self.send_response(404); self.end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()

    def _mjpeg(self):
        self.send_response(200)
        self.send_header('Content-Type',
                         'multipart/x-mixed-replace; boundary=--boundary')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Cache-Control', 'no-cache')
        self.send_header('Connection', 'close')
        self.end_headers()

        last = None
        try:
            while _cam_running:
                with _cam_lock:
                    frame = _cam_frame
                if not frame:
                    time.sleep(0.02); continue
                if frame == last:
                    time.sleep(0.01); continue
                last = frame
                try:
                    msg = (b'----boundary\r\nContent-Type: image/jpeg\r\n'
                           + f'Content-Length: {len(frame)}\r\n\r\n'.encode()
                           + frame + b'\r\n')
                    self.wfile.write(msg)
                    self.wfile.flush()
                except (BrokenPipeError, ConnectionResetError, OSError):
                    break
        except Exception:
            pass

    def _snapshot(self):
        with _cam_lock: frame = _cam_frame
        if frame:
            self.send_response(200)
            self.send_header('Content-Type', 'image/jpeg')
            self.send_header('Content-Length', str(len(frame)))
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(frame)
        else:
            self.send_response(503); self.end_headers()
            self.wfile.write(b'No frame yet')

    def _index(self):
        ip  = _get_local_ip()
        fps = _cam_stats.get('fps', 0.0)
        html = (
            f'<!DOCTYPE html><html><head><meta charset="utf-8">'
            f'<title>Alpha Mini Live</title>'
            f'<style>body{{background:#000;display:flex;flex-direction:column;'
            f'align-items:center;justify-content:center;min-height:100vh;'
            f'color:#fff;font-family:sans-serif;gap:12px}}'
            f'img{{max-width:95vw;max-height:82vh;border:2px solid #2196F3;'
            f'border-radius:8px}}</style></head><body>'
            f'<span style="color:#2196F3;font-size:20px">📷 Alpha Mini Live '
            f'<span style="background:#e53935;padding:2px 10px;border-radius:4px;'
            f'font-size:11px">● LIVE {fps:.0f}fps</span></span>'
            f'<img src="/stream">'
            f'<code style="color:#2196F3">Flutter: '
            f'http://{ip}:{CAM_HTTP_PORT}/stream</code>'
            f'</body></html>'
        ).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', str(len(html)))
        self.end_headers()
        self.wfile.write(html)


def start_camera_server():
    """Khởi động camera pipeline + HTTP server trong background threads."""
    threading.Thread(target=_camera_capture_loop, daemon=True).start()

    def _run_server():
        server = _CamThreadedServer(('0.0.0.0', CAM_HTTP_PORT), _CamHandler)
        server.serve_forever()

    threading.Thread(target=_run_server, daemon=True).start()
    ip = _get_local_ip()
    print(f"📷 Camera stream: http://{ip}:{CAM_HTTP_PORT}/stream")


# ================================================================
# MAIN — chạy cả 2 loop đồng thời
# ================================================================

async def main():
    if not login():
        print("❌ Đăng nhập thất bại")
        return

    await ensure_connection()
    fetch_action_library()
    start_camera_server()          # background thread, không block asyncio

    ip = _get_local_ip()
    print("=" * 52)
    print("🚀 HỆ THỐNG KHỞI ĐỘNG TOÀN BỘ")
    print("  • reminder_loop   : nhắc uống thuốc, ưu tiên mic")
    print("  • interaction_loop: hội thoại AI + động tác giọng nói")
    print("  • action_poll_loop: lệnh động tác + TTS từ Flutter app")
    print("  • camera stream   : "
          f"http://{ip}:{CAM_HTTP_PORT}/stream")
    print("  • robot_lock      : robot chỉ làm 1 việc tại 1 thời điểm")
    print("  • mic_lock        : mic chỉ 1 loop dùng 1 lúc")
    print("=" * 52)

    await asyncio.gather(
        reminder_loop(),
        interaction_loop(),
        action_poll_loop(),
    )


if __name__ == "__main__":
    asyncio.run(main())
