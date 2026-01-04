import os
import time
import subprocess

class Watchdog:
    def is_app_running(self, package_name):
        try:
            # Cách mới: Tìm PID nhanh gọn bằng pgrep
            pid = subprocess.check_output(['pgrep', '-f', package_name]).strip().decode()

            # Check độ ưu tiên (OOM Score)
            # Score <= 0: App đang hiện trên màn hình (Foreground)
            # Score > 200: App đang ẩn (Background)
            with open(f"/proc/{pid}/oom_score_adj", "r") as f:
                score = int(f.read().strip())

            return True, score
        except Exception:
            return False, -1  # Không tìm thấy PID hoặc lỗi