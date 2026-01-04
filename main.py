import json
import time
from core.watchdog import Watchdog

# Load cấu hình
with open('config.json', 'r') as f:
    config = json.load(f)

dog = Watchdog()
print("🐕 Watchdog đang canh gác...")

while True:
    for clone in config['clones']:
        alive, score = dog.is_app_running(clone['package'])

        if not alive:
            print(f"❌ {clone['name']} đã chết! -> Cần hồi sinh ngay.")
            # Chỗ này sẽ thêm code Start App sau
        elif score > 200:
            print(f"⚠️ {clone['name']} đang ẩn nền -> Cần lôi lên.")
            # Chỗ này sẽ thêm code Bring to Front sau
        else:
            print(f"✅ {clone['name']} đang chạy ngon.")

    time.sleep(config['check_interval'])