# AutoToolV2 (Termux/Android)

AutoToolV2 là bộ tool chạy trong Termux để theo dõi (watchdog) trạng thái app/game, ghi log và tự recover (force-stop + relaunch) khi phát hiện lỗi như OFFLINE / rớt mạng / disconnect.

---

## 1) Yêu cầu (Prerequisites)

- Termux (khuyến nghị bản từ F-Droid)
- Quyền truy cập storage:
  ```bash
  termux-setup-storage
Các gói cơ bản:

bash
Sao chép mã
pkg update -y
pkg install -y git python iproute2 coreutils procps
Nếu workflow dùng su, máy cần có root (Magisk/SU).

Nếu dùng logcat nâng cao, có thể cần quyền/adb/root tùy ROM.

2) Cấu trúc thư mục
graphql
Sao chép mã
AutoToolV2/
├─ ui/
│  └─ menu.sh                 # Menu chính
├─ workflows/
│  ├─ watchdog_start.sh        # Start watchdog (background/log)
│  ├─ watchdog_stop.sh         # Stop watchdog
│  ├─ recover.sh               # Force-stop + relaunch app
│  ├─ setup_game_id.sh         # Set package/game id
│  ├─ check_user_setup.sh      # Check config cơ bản
│  ├─ auto_rejoin.sh           # Auto rejoin logic (nếu có)
│  └─ ...                      # Các workflow khác
├─ engine/
│  └─ watchdog.py              # Watchdog core
├─ logs/
│  ├─ watchdog.log             # Log watchdog
│  └─ recover.log              # Log recover
└─ runtime/state.<clone>.json  # trạng thái runtime (schema chuẩn bên dưới, clone mặc định = default)
3) Chạy nhanh (Quick start)
3.1 Mở menu
bash
Sao chép mã
cd /sdcard/Download/AutoToolV2
bash ui/menu.sh
3.2 Start watchdog (khuyến nghị chạy nền)
bash
Sao chép mã
bash workflows/watchdog_start.sh
3.3 Stop watchdog
bash
Sao chép mã
bash workflows/watchdog_stop.sh
3.4 Xem log bằng tail (hoặc ZArchiver)
bash
Sao chép mã
tail -n 120 logs/watchdog.log
tail -n 120 logs/recover.log
4) Watchdog hoạt động thế nào
Watchdog chạy loop theo chu kỳ, dựa trên các tín hiệu:

PID/Process check: app còn chạy hay đã OFFLINE

Network check: ping (có streak/debounce để tránh báo sai)

Logcat check (tuỳ bản): grep từ khóa disconnect/error

Các trạng thái hay gặp:

OFFLINE: app không chạy / bị văng hẳn

RUNNING_OK: app đang chạy bình thường

RUNNING_ISSUE=NET_DOWN: app chạy nhưng mạng rớt (ping fail streak)

Ghi chú: Phân biệt "sảnh" vs "in-game" rất khó nếu chỉ dùng dumpsys/activity và thường không cần thiết nếu mục tiêu chính là detect OFFLINE / disconnect / NET_DOWN.

5) Recover hoạt động thế nào
Mục tiêu recover: kill sạch + mở lại app.

Kill chuẩn:

am force-stop <package>

Relaunch:

dùng monkey / am start tùy workflow

Chạy tay để test:

bash
Sao chép mã
bash workflows/recover.sh com.zamdepzai.clienv
Không khuyến nghị dựa chính vào pkill vì có thể làm app “chết nửa vời” (service còn sống) khiến watchdog hiểu nhầm vẫn đang chạy.

6) Test ngắt mạng (NET_DOWN)
Tuỳ máy/ROM, svc wifi/data disable hoặc airplane mode có thể không ngắt thật.
Cách test nhanh:

Kiểm tra ping:

bash
Sao chép mã
ping -c 1 -W 1 1.1.1.1; echo $?
Nếu máy cho phép và bạn có root, có thể dùng iptables để drop:

bash
Sao chép mã
su -c 'iptables -I OUTPUT -j DROP; iptables -I INPUT -j DROP'
Khôi phục:

bash
Sao chép mã
su -c 'iptables -D OUTPUT 1; iptables -D INPUT 1'
Sau đó xem log:

bash
Sao chép mã
tail -n 120 logs/watchdog.log
Bạn sẽ thấy dòng kiểu RUNNING_ISSUE=NET_DOWN.

7) Đồng bộ lên GitHub (đúng cách trên Termux)
7.1 Vì sao lỗi “not a git repository”?
Thư mục /sdcard/Download/... thường không có .git.
Repo git chuẩn nên nằm trong HOME của Termux: ~/AutoToolV2.

7.2 Luồng sync chuẩn (khuyến nghị)
Clone repo vào HOME:

bash
Sao chép mã
cd ~
git clone https://github.com/<USER>/AutoToolV2.git
cd AutoToolV2
Copy code từ /sdcard vào repo (giữ nguyên .git):

bash
Sao chép mã
cp -rf /sdcard/Download/AutoToolV2/. .
Commit & push:

bash
Sao chép mã
git add -A
git commit -m "sync from /sdcard"
git push origin main
Nếu git push hỏi password: GitHub đã bỏ password auth, dùng PAT token hoặc SSH key.

8) Troubleshooting
8.1 Menu báo Missing workflow nhưng file có thật
Đảm bảo đang đứng đúng thư mục root:

bash
Sao chép mã
pwd
ls -la workflows
Chạy bằng bash workflows/<file>.sh để kiểm tra trực tiếp.

Nếu chạy ./workflows/<file>.sh bị Permission denied:

chạy:

bash
Sao chép mã
bash workflows/<file>.sh
hoặc cấp quyền:

bash
Sao chép mã
chmod +x workflows/*.sh ui/*.sh
8.2 Watchdog spam log/lag
Tăng sleep trong loop của watchdog.

Giảm log ra màn hình, ưu tiên log ra file (logs/watchdog.log).

9) Roadmap gợi ý
Chuẩn hoá state.json (nếu dùng) và format log gọn hơn

Trigger recover theo rule rõ ràng (OFFLINE, NET_DOWN streak, logcat disconnect)

Thêm README chi tiết cho từng workflow (inputs/outputs)

11) state.json: schema chuẩn + ví dụ
Nếu dùng state.json để các workflow giao tiếp, hãy giữ đúng schema sau:

```json
{
  "package": "com.example.game",          // tên package đang theo dõi
  "clone_id": "default",                  // id clone (AUTOTOOL_CLONE), để chạy nhiều instance độc lập
  "status": "RUNNING_OK",                 // RUNNING_OK | RUNNING_ISSUE | OFFLINE | STOPPED
  "issue": "OFFLINE",                     // (optional) issue đã xác nhận, có thể null
  "running_issue": "NET_DOWN"             // (optional) issue đang gặp khi RUNNING_ISSUE, có thể null
}
```

Log watchdog sẽ luôn đi kèm dòng `STATE pkg=<pkg> status=<status> issue=<issue|-> running_issue=<running_issue|->` để tiện grep/tail.

12) Kiểm thử thủ công (watchdog + auto_rejoin)
- Chuẩn bị: đặt package trong `config/game_package.txt` hoặc chạy `bash workflows/watchdog_start.sh <package>`.
- Mở 2 terminal:
  - Terminal 1: `bash workflows/watchdog_start.sh <package>` và xem log bằng `tail -f logs/watchdog.log`.
  - Terminal 2: `bash workflows/auto_rejoin.sh <package>` và xem log bằng `tail -f logs/auto_rejoin.log`.
- Kịch bản thử:
  1. App đang chạy bình thường: trong `logs/watchdog.log` có dòng `STATE ... status=RUNNING_OK ...` và `runtime/state.<clone>.json` phản ánh tương ứng.
  2. Tắt app (force-stop): watchdog log `STATE ... status=OFFLINE ...`, `runtime/state.<clone>.json` đổi sang OFFLINE, auto_rejoin log `status=STATUS OFFLINE ...` và gọi recover (xem thêm `logs/recover.log`).
  3. Ngắt mạng (ping fail): watchdog log `STATE ... status=RUNNING_ISSUE ... running_issue=NET_DOWN`, auto_rejoin thấy `running_issue=NET_DOWN` và bắn recover (sau cooldown).
- Sau khi thử xong, stop bằng `bash workflows/watchdog_stop.sh` hoặc `Ctrl+C` ở các terminal và kiểm tra `runtime/state.<clone>.json` cuối cùng có status `STOPPED` nếu watchdog dừng.

12.1) Chống spam restart + circuit breaker
- Watchdog chỉ recover khi PID mất thật (debounce) + kiểm tra network đa tín hiệu.
- Sau mỗi recover, có grace period (GRACE_PERIOD_SEC) không đánh offline ngay.
- Circuit breaker: nếu recover >=3 lần trong 5 phút sẽ “open”, chỉ log trạng thái và không tự kill/launch, chờ user can thiệp.
- Net flapping (NET_UNSTABLE) sẽ bật cooldown dài hơn (NET_UNSTABLE_COOLDOWN) để tránh loop.
- Các package được bảo vệ (com.termux, com.termux.x11) sẽ không bị recover/kill.

13) Debug/Test nhanh trên Termux
- Bật DEBUG log cho watchdog:
  ```bash
  AUTOTOOL_DEBUG=1 bash workflows/watchdog_start.sh <package>
  # hoặc chạy tay:
  AUTOTOOL_DEBUG=1 python engine/watchdog.py <package>
  ```
- Xem log tail kèm highlight:
  ```bash
  tail -f logs/watchdog.log | grep --line-buffered -E \"STATE|ERR|WARN\"
  tail -f logs/auto_rejoin.log
  ```
- Kiểm tra state.json theo schema chuẩn:
  ```bash
  cat state.json | jq .
  ```
- Dừng tiến trình khi test:
  ```bash
  bash workflows/watchdog_stop.sh
  pkill -f auto_rejoin.sh   # hoặc Ctrl+C tại terminal đang chạy auto_rejoin
  ```

14) Test plan gợi ý (quan sát logs/watchdog.log + logs/events.log + runtime/state.<clone>.json)
- Case 1: tắt mạng 60s -> watchdog báo NET_DOWN/NET_UNSTABLE, recover tối đa 1 lần, không loop do cooldown dài hơn.
- Case 2: giả lập Termux X crash -> circuit breaker không cho kill com.termux/com.termux.x11; app không bị spam restart.
- Case 3: mạng chập chờn -> chuyển NET_UNSTABLE, ghi cooldown dài và không recover liên tục.
- Case 4: nhiều clone -> đặt AUTOTOOL_CLONE khác nhau, mỗi clone ghi state/cooldown riêng (`runtime/state.<clone>.json`, `runtime/cooldown.<clone>.json`), log events kèm clone_id.

10) License
TBD

Sao chép mã
