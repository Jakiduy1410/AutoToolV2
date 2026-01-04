import subprocess
import time

class DeviceManager:
    @staticmethod
    def start_app(package_name):
        print(f"🚀 Đang khởi động: {package_name}")
        # Mẹo: Dùng lệnh monkey để tự tìm Activity khởi động, đỡ phải mò tên class
        cmd = f"monkey -p {package_name} -c android.intent.category.LAUNCHER 1"
        subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    @staticmethod
    def force_stop(package_name):
        print(f"💀 Đang tắt nóng: {package_name}")
        cmd = f"am force-stop {package_name}"
        subprocess.run(cmd, shell=True)
        
    @staticmethod
    def bring_to_front(package_name):
        print(f"🔄 Đang lôi lên màn hình: {package_name}")
        # Dùng lại lệnh start, Android sẽ tự lôi nó lên trên cùng
        DeviceManager.start_app(package_name)