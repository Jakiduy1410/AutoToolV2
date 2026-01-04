import json
import time
from core.watchdog import Watchdog
from core.device import DeviceManager # <-- Import thêm cánh tay

# Load cấu hình
try:
    with open('config.json', 'r') as f:
        config = json.load(f)
except FileNotFoundError:
    print("❌ Lỗi: Không thấy file config.json đâu cả!")
    exit()

dog = Watchdog()
print("🐕 Watchdog đã được lắp tay chân, bắt đầu canh gác...")

while True:
    for clone in config['clones']:
        pkg = clone['package']
        name = clone['name']
        
        alive, score = dog.is_app_running(pkg)
        
        if not alive:
            print(f"❌ {name} (Chết) -> Đang hồi sinh...")
            DeviceManager.start_app(pkg)
            
        elif score > 200: # Score > 200 là đang ẩn nền
            print(f"⚠️ {name} (Ẩn nền) -> Đang lôi lên...")
            DeviceManager.bring_to_front(pkg)
            
        else:
            print(f"✅ {name} đang sống khỏe (Score: {score}).")
    
    # Nghỉ 5 giây rồi check tiếp cho đỡ spam
    time.sleep(config['check_interval'])