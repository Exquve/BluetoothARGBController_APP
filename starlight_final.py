#!/usr/bin/env python3
"""
STARLIGHT ARGB LED Kontrolcü - Final Versiyon
==============================================

Bluetooth üzerinden STARLIGHT ARGB LED şerit kontrolörünü kontrol eder.
Protokol: STAR_LIGHTING APK'sından tersine mühendislik ile çıkarıldı.

Özellikler:
- Bluetooth Low Energy (BLE) bağlantısı
- RGB renk kontrolü (tüm LEDler)
- HSV renk çarkı kontrolü (H:0-360, S:0-997)
- Renk sıcaklığı ayarı (sıcak/soğuk beyaz)
- RGB↔HSV dönüştürücü
- Parlaklık ayarı (0-1000)
- 117+ hazır animasyon modu
- Animasyon hızı ve yön kontrolü
- İnteraktif komut satırı arayüzü

Not: Bu cihaz bireysel LED kontrolünü desteklemiyor.
Sadece tüm LED'lere renk veya hazır animasyon modları kullanılabilir.

Gereksinimler:
- Python 3.7+
- bleak kütüphanesi (pip install bleak)

Kullanım:
    python3 starlight_final.py

Yazar: Yusuf Kara
Tarih: Ekim 2025
"""

import asyncio
from bleak import BleakScanner, BleakClient
import colorsys

class STARLIGHTController:
    def __init__(self):
        self.client = None
        self.write_char = "0000fff3-0000-1000-8000-00805f9b34fb"
        
        # Protokol sabitler (APK'dan çıkarıldı)
        self.HEADER = 0xBC  # -68 = 0xBC
        self.FOOTER = 0x55  # 85 = 0x55
        
    async def connect(self):
        """STARLIGHT'a bağlanır"""
        print("STARLIGHT aranıyor...")
        devices = await BleakScanner.discover(timeout=10)
        
        starlight = None
        for device in devices:
            if device.name and "STARLIGHT" in device.name.upper():
                starlight = device
                break
        
        if not starlight:
            print("❌ STARLIGHT bulunamadı!")
            return False
        
        print(f"✅ STARLIGHT bulundu: {starlight.address}")
        self.client = BleakClient(starlight.address)
        await self.client.connect()
        
        if self.client.is_connected:
            print("✅ Bağlantı başarılı!")
            return True
        return False
    
    def _send_command(self, command):
        """Komut gönderir (non-async wrapper)"""
        if not self.client or not self.client.is_connected:
            print("❌ Cihaza bağlı değil!")
            return False
        
        try:
            # asyncio.create_task kullanarak asenkron gönder
            asyncio.create_task(self.client.write_gatt_char(
                self.write_char, 
                bytes(command), 
                response=False
            ))
            return True
        except Exception as e:
            print(f"❌ Komut gönderme hatası: {e}")
            return False
    
    async def send_command_async(self, command):
        """Asenkron komut gönder"""
        if not self.client or not self.client.is_connected:
            print("❌ Cihaza bağlı değil!")
            return False
        
        try:
            await self.client.write_gatt_char(
                self.write_char, 
                bytes(command), 
                response=False
            )
            return True
        except Exception as e:
            print(f"❌ Komut gönderme hatası: {e}")
            return False
    
    def rgb_to_hsv(self, r, g, b):
        """RGB'yi HSV'ye çevirir"""
        r_norm = r / 255.0
        g_norm = g / 255.0
        b_norm = b / 255.0
        
        h, s, v = colorsys.rgb_to_hsv(r_norm, g_norm, b_norm)
        
        # APK formatına çevir
        hue = int(h * 360)  # 0-360
        sat = int(s * 1000)  # 0-1000
        val = int(v * 1000)  # 0-1000
        
        return hue, sat, val
    
    # ============ AÇMA/KAPAMA KOMUTLARI ============
    
    async def power_off(self):
        """LED'leri AÇAR (isChecked=true -> 0)"""
        # APK: isChecked ? write({-68, 1, 1, 0, 85}) : write({-68, 1, 1, 1, 85})
        command = [0xBC, 0x01, 0x01, 0x00, 0x55]
        print(f"💡 Açılıyor: {' '.join(f'{b:02X}' for b in command)}")
        return await self.send_command_async(command)
    
    async def power_on(self):
        """LED'leri KAPATIR (isChecked=false -> 1)"""
        command = [0xBC, 0x01, 0x01, 0x01, 0x55]
        print(f"🌑 Kapatılıyor: {' '.join(f'{b:02X}' for b in command)}")
        return await self.send_command_async(command)
    
    # ============ RENK KOMUTLARI ============
    
    async def set_color_rgb(self, r, g, b, brightness=1000):
        """
        TÜM LED'lerin rengini ayarlar
        APK'dan: write({-68, 4, 6, (byte)(hue/255), (byte)(hue%255), 3, -24, 0, 0, (byte)r, (byte)g, (byte)b, 85})
        
        Parametreler:
        - r, g, b: 0-255 arası RGB değerleri
        - brightness: Parlaklık (varsayılan 1000, 0-1000 arası)
        """
        # RGB'den HSV'ye dönüştürme (colorsys kullanarak)
        hue, sat, val = self.rgb_to_hsv(r, g, b)
        
        # Beyaz kontrolü (APK'da özel durum)
        if r == g == b == 255:
            # Beyaz için farklı protokol
            command = [
                0xBC, 0x04, 0x06,
                hue // 255, hue % 255,
                0x00, 0x00,  # Beyaz için 0, 0
                0x00, 0x00,
                r & 0xFF, g & 0xFF, b & 0xFF,
                0x55
            ]
        else:
            # Normal renkler
            command = [
                0xBC, 0x04, 0x06,
                hue // 255, hue % 255,
                0x03, 0xE8,  # 3, -24 (1000 = 0x03E8 parlaklık)
                0x00, 0x00,
                r & 0xFF, g & 0xFF, b & 0xFF,
                0x55
            ]
        
        print(f"🎨 Renk: RGB({r},{g},{b}) -> {' '.join(f'{b:02X}' for b in command)}")
        return await self.send_command_async(command)
    
    async def set_brightness(self, brightness):
        """
        Parlaklık ayarlar (0-1000 arası)
        APK'dan: write({-68, 5, 6, (byte)(progress/256), (byte)(progress%256), 0, 0, 0, 0, 85})
        """
        command = [
            0xBC, 0x05, 0x06,
            brightness // 256, brightness % 256,
            0x00, 0x00, 0x00, 0x00,
            0x55
        ]
        print(f"💡 Parlaklık: {brightness} -> {' '.join(f'{b:02X}' for b in command)}")
        return await self.send_command_async(command)
    
    async def set_color_wheel(self, hue, saturation):
        """
        Renk çarkı kontrolü (HSV)
        HSV'den RGB'ye çevirip komut 0x04 kullanır
        
        Parametreler:
        - hue: 0-360 arası (renk tonu)
        - saturation: 0-997 arası (doygunluk, 997=tam doygun, MAX değer)
        
        Örnekler:
        - hsv 0 997   → Kırmızı (max)
        - hsv 120 997 → Yeşil (max)
        - hsv 240 997 → Mavi (max)
        - hsv 180 997 → Cyan (max)
        - hsv 60 997  → Sarı (max)
        - hsv 300 997 → Magenta (max)
        """
        # Saturation değerini sınırla
        saturation = min(saturation, 997)
        
        # HSV'den RGB'ye çevir
        h_norm = hue / 360.0
        s_norm = saturation / 997.0  # MAX = 997
        v_norm = 1.0  # Tam parlaklık
        
        r_norm, g_norm, b_norm = colorsys.hsv_to_rgb(h_norm, s_norm, v_norm)
        r = int(r_norm * 255)
        g = int(g_norm * 255)
        b = int(b_norm * 255)
        
        # RGB komutunu gönder
        command = [
            0xBC, 0x04, 0x06,
            hue // 255, hue % 255,
            saturation // 255, saturation % 255,
            0x00, 0x00,
            r & 0xFF, g & 0xFF, b & 0xFF,
            0x55
        ]
        hex_str = ' '.join(f'{b:02X}' for b in command)
        print(f"🎨 HSV: H={hue}° S={saturation}/997 → RGB({r},{g},{b}) -> [{hex_str}]")
        return await self.send_command_async(command)
    
    async def set_color_temperature(self, theta):
        """
        Renk sıcaklığı ayarlar (sıcak/soğuk beyaz)
        APK'dan: write({-68, 19, 2, (byte)(theta/256), (byte)(theta%256), 85})
        Komut 0x13 (19) - Sıcaklık modu
        
        Parametreler:
        - theta: 0-360 arası (MIN=0, MAX=360)
          * 0 → En sıcak beyaz (sarımsı)
          * 360 → En soğuk beyaz (mavimsi)
        
        Örnekler:
        - temp 0   → Sıcak beyaz (max sıcak)
        - temp 180 → Nötr beyaz
        - temp 360 → Soğuk beyaz (max soğuk)
        """
        # Theta değerini sınırla
        theta = max(0, min(theta, 360))
        
        command = [
            0xBC, 0x13, 0x02,
            theta // 256, theta % 256,
            0x55
        ]
        temp_desc = "Sıcak" if theta < 120 else ("Nötr" if theta < 240 else "Soğuk")
        print(f"🌡️ Renk sıcaklığı: {theta}/360 ({temp_desc}) -> {' '.join(f'{b:02X}' for b in command)}")
        return await self.send_command_async(command)
    
    # ============ ANIMASYON MODLARI ============
    
    async def set_mode(self, mode_index):
        """
        Animasyon modunu ayarlar
        APK'dan: write({-68, 6, 2, (byte)(index/255), (byte)(index%255), 85})
        
        Örnek modlar:
        1-4: 7 renk gradient, fade vb.
        35-44: Farklı animasyonlar
        96-117: Nokta animasyonları (dots running)
        """
        # APK'daki özel durum
        if mode_index == 112:
            mode_index = 113
        elif mode_index >= 113:
            mode_index += 2
            
        command = [
            0xBC, 0x06, 0x02,
            mode_index // 255, mode_index % 255,
            0x55
        ]
        print(f"🎬 Mod {mode_index}: {' '.join(f'{b:02X}' for b in command)}")
        return await self.send_command_async(command)
    
    async def set_speed(self, speed):
        """
        Animasyon hızını ayarlar (0-255)
        APK'dan: write({-68, 8, 1, (byte)progress, 85})
        """
        command = [0xBC, 0x08, 0x01, speed & 0xFF, 0x55]
        print(f"⚡ Hız: {speed} -> {' '.join(f'{b:02X}' for b in command)}")
        return await self.send_command_async(command)
    
    async def set_direction(self, reverse=False):
        """
        Animasyon yönünü ayarlar
        APK'dan: write({-68, 7, 1, 0/1, 85})
        reverse=False: Normal (0)
        reverse=True: Ters (1)
        """
        command = [0xBC, 0x07, 0x01, 0x01 if reverse else 0x00, 0x55]
        print(f"↔️ Yön: {'Ters' if reverse else 'Normal'} -> {' '.join(f'{b:02X}' for b in command)}")
        return await self.send_command_async(command)
    
    # ============ HAZIR RENKLER ============
    
    async def red(self):
        """Kırmızı"""
        return await self.set_color_rgb(255, 0, 0)
    
    async def green(self):
        """Yeşil"""
        return await self.set_color_rgb(0, 255, 0)
    
    async def blue(self):
        """Mavi"""
        return await self.set_color_rgb(0, 0, 255)
    
    async def white(self):
        """Beyaz"""
        return await self.set_color_rgb(255, 255, 255)
    
    async def yellow(self):
        """Sarı"""
        return await self.set_color_rgb(255, 255, 0)
    
    async def cyan(self):
        """Cyan"""
        return await self.set_color_rgb(0, 255, 255)
    
    async def magenta(self):
        """Magenta"""
        return await self.set_color_rgb(255, 0, 255)
    
    async def orange(self):
        """Turuncu"""
        return await self.set_color_rgb(255, 165, 0)
    
    async def purple(self):
        """Mor"""
        return await self.set_color_rgb(128, 0, 128)
    
    async def disconnect(self):
        """Bağlantıyı keser"""
        if self.client and self.client.is_connected:
            await self.client.disconnect()
            print("🔌 Bağlantı kesildi")


async def interactive_demo():
    """İnteraktif demo"""
    controller = STARLIGHTController()
    
    try:
        if not await controller.connect():
            return
        
        print("\n" + "="*60)
        print("🌟 STARLIGHT ARGB LED Kontrolcü")
        print("="*60)
        print("\nKomutlar:")
        print("  on     - LED'leri aç")
        print("  off    - LED'leri kapat")
        print("  r      - Kırmızı (tüm LEDler)")
        print("  g      - Yeşil (tüm LEDler)")
        print("  b      - Mavi (tüm LEDler)")
        print("  w      - Beyaz")
        print("  y      - Sarı")
        print("  c      - Cyan")
        print("  m      - Magenta")
        print("  o      - Turuncu")
        print("  p      - Mor")
        print("  rgb R G B      - Tüm LEDler için RGB (örnek: rgb 255 100 50)")
        print("  bright N       - Parlaklık (0-1000, örnek: bright 500)")
        print("  hsv H S        - Renk çarkı HSV (H:0-360, S:0-997, örnek: hsv 180 997)")
        print("  temp N         - Renk sıcaklığı (0-360, örnek: temp 180)")
        print("  mode N         - Animasyon modu (1-117)")
        print("  speed N        - Animasyon hızı (0-255)")
        print("  reverse        - Animasyon yönünü ters çevir")
        print("  normal         - Animasyon yönünü normale al")
        print("  test   - Renk testi")
        print("  q      - Çık")
        print("="*60)
        print("\n💡 İpucu: Farklı animasyonlar için mode 1-117 arası değerleri deneyin!")
        print("="*60)
        
        while True:
            try:
                cmd = input("\n> ").strip().lower()
                
                if cmd == 'q':
                    break
                elif cmd == 'on':
                    await controller.power_on()
                elif cmd == 'off':
                    await controller.power_off()
                elif cmd == 'r':
                    await controller.red()
                elif cmd == 'g':
                    await controller.green()
                elif cmd == 'b':
                    await controller.blue()
                elif cmd == 'w':
                    await controller.white()
                elif cmd == 'y':
                    await controller.yellow()
                elif cmd == 'c':
                    await controller.cyan()
                elif cmd == 'm':
                    await controller.magenta()
                elif cmd == 'o':
                    await controller.orange()
                elif cmd == 'p':
                    await controller.purple()
                elif cmd.startswith('rgb '):
                    parts = cmd.split()
                    if len(parts) == 4:
                        r, g, b = int(parts[1]), int(parts[2]), int(parts[3])
                        await controller.set_color_rgb(r, g, b)
                    else:
                        print("❌ Kullanım: rgb R G B")
                elif cmd.startswith('bright '):
                    parts = cmd.split()
                    if len(parts) == 2:
                        brightness = int(parts[1])
                        await controller.set_brightness(brightness)
                    else:
                        print("❌ Kullanım: bright N (0-1000)")
                elif cmd.startswith('hsv '):
                    parts = cmd.split()
                    if len(parts) == 3:
                        h, s = int(parts[1]), int(parts[2])
                        await controller.set_color_wheel(h, s)
                    else:
                        print("❌ Kullanım: hsv H S (H:0-360, S:0-997, örnek: hsv 0 997 → Kırmızı max)")
                elif cmd.startswith('temp '):
                    parts = cmd.split()
                    if len(parts) == 2:
                        temp = int(parts[1])
                        await controller.set_color_temperature(temp)
                    else:
                        print("❌ Kullanım: temp N (0-360, örnek: temp 0 → sıcak, temp 360 → soğuk)")
                elif cmd.startswith('mode '):
                    parts = cmd.split()
                    if len(parts) == 2:
                        mode = int(parts[1])
                        await controller.set_mode(mode)
                    else:
                        print("❌ Kullanım: mode N (1-117)")
                elif cmd.startswith('speed '):
                    parts = cmd.split()
                    if len(parts) == 2:
                        speed = int(parts[1])
                        await controller.set_speed(speed)
                    else:
                        print("❌ Kullanım: speed N (0-255)")
                elif cmd == 'reverse':
                    await controller.set_direction(reverse=True)
                elif cmd == 'normal':
                    await controller.set_direction(reverse=False)
                elif cmd == 'test':
                    print("\n🧪 Renk testi başlıyor...")
                    colors = [
                        ("Kırmızı", controller.red),
                        ("Yeşil", controller.green),
                        ("Mavi", controller.blue),
                        ("Sarı", controller.yellow),
                        ("Cyan", controller.cyan),
                        ("Magenta", controller.magenta),
                        ("Beyaz", controller.white),
                    ]
                    for name, func in colors:
                        print(f"  {name}...")
                        await func()
                        await asyncio.sleep(1)
                    print("✅ Test tamamlandı!")
                else:
                    print("❌ Geçersiz komut!")
                    
            except KeyboardInterrupt:
                break
            except Exception as e:
                print(f"❌ Hata: {e}")
        
    finally:
        await controller.disconnect()


if __name__ == "__main__":
    print("🌟 STARLIGHT ARGB LED Kontrolcü v2.0 - Final")
    print("Protokol: APK tersine mühendislik ile çıkarıldı")
    print("Özellikler: RGB/HSV Renk, Sıcaklık, Animasyonlar, Parlaklık, Hız/Yön")
    print("="*60)
    asyncio.run(interactive_demo())
