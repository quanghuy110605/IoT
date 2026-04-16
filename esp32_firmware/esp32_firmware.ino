#include <Arduino.h>
#include <WiFi.h>
#include <WiFiManager.h> 
#include <FirebaseESP32.h>
#include <Wire.h>
#include <Adafruit_AHTX0.h> 
#include "DFRobot_ENS160.h" 

#define RAW_BUFFER_LENGTH 1000  
#define RECORD_GAP_MICROS 50000 
#define IR_RECEIVE_PIN 27       
#define IR_SEND_PIN 4           
#include <IRremote.hpp> 

#define FIREBASE_HOST "fir-1esp-default-rtdb.firebaseio.com" 
#define FIREBASE_AUTH "JdfPW1FHbYxHj5s6zjPOAqvk9dNT287RzkQAtJEf" 

#define MQ2_PIN 34       
#define LDR_PIN 32       
#define LIGHT_PIN 16     
#define FAN_PIN 18       
#define SERVO_PIN 19     
#define BUZZER_PIN 33  // 33  
#define BUTTON_PIN 14    
#define LED_WIFI_PIN 2   // Đèn LED báo trạng thái mạng
#define BUZZER_VOLUME 5

Adafruit_AHTX0 aht;                     
DFRobot_ENS160_I2C ens160(&Wire, 0x53); 

FirebaseData streamFBDO; 
FirebaseData dataFBDO;   
FirebaseAuth auth;
FirebaseConfig config;
WiFiManager wm;          // Khởi tạo WiFiManager toàn cục

// --- BIẾN TOÀN CỤC ---
unsigned long lastSensorUpdate = 0;   
unsigned long lastHistoryUpdate = 0;  
unsigned long lastStreamWatchdog = 0; 
unsigned long lastGasChangeTime = 0;  
unsigned long lastDebounceTime = 0;   
unsigned long lastCheckLDR = 0;       
unsigned long lastLedBlink = 0;
unsigned long buttonPressTime = 0;
unsigned long wifiConnectedTime = 0; // Biến đếm thời gian tắt LED
unsigned long lastWiFiReconnect = 0;

bool isButtonPressed = false;
bool firebaseStarted = false; // Cờ chống đơ Firebase
bool isLearning = false;  
String learnTarget = "";  

int currentLight = -1, currentFan = -1, currentBuzzer = -1;
int currentAcOn = -1, currentAcTemp = -1;
int lastGasState = 1;     
bool isDark = false;      

// Các biến cho chức năng Auto & IR từ App
int currentIrFreq = 38;   
int autoMode = 0;         
float triggerTemp = 30.0; 
int targetTemp = 25;      
bool autoFired = false;   

// --- CÁC HÀM HỖ TRỢ ---
void setServoAngle(int angle) {
  int duty = map(angle, 0, 180, 102, 512); 
  ledcWrite(SERVO_PIN, duty);
}

void initFirebaseStream() {
  if (!Firebase.ready()) return; 
  if (Firebase.beginStream(streamFBDO, "/Huy_Project/Control")) {
    Serial.println("[SYSTEM] Stream ket noi THANH CONG!");
  }
}

void transmitIRCode(String targetNode) {
  if (!Firebase.ready()) return;
  if (Firebase.getString(dataFBDO, "/Huy_Project/IR_Dictionary/" + targetNode)) {
    String rawDataStr = dataFBDO.stringData();
    if (rawDataStr == "" || rawDataStr == "null") return;
    
    int commaCount = 0;
    for (int i = 0; i < rawDataStr.length(); i++) if (rawDataStr.charAt(i) == ',') commaCount++;
    int rawLength = commaCount + 1;
    
    uint16_t* rawArray = new uint16_t[rawLength]; 
    int arrayIndex = 0, startIndex = 0;
    for (int i = 0; i <= rawDataStr.length(); i++) {
      if (i == rawDataStr.length() || rawDataStr.charAt(i) == ',') {
        rawArray[arrayIndex++] = rawDataStr.substring(startIndex, i).toInt();
        startIndex = i + 1;
      }
    }
    // Phát theo tần số nhận từ App (currentIrFreq)
    IrSender.sendRaw(rawArray, rawLength, currentIrFreq);
    delete[] rawArray; 
    Serial.println("[IR] Da phat ma: " + targetNode);
  }
}

// --- SETUP ---
void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n--- KHOI DONG HE THONG ---");
  
  pinMode(LIGHT_PIN, OUTPUT); pinMode(FAN_PIN, OUTPUT); pinMode(LED_WIFI_PIN, OUTPUT);
  pinMode(MQ2_PIN, INPUT); pinMode(BUTTON_PIN, INPUT); pinMode(LDR_PIN, INPUT); 

  ledcAttach(BUZZER_PIN, 2500, 8); ledcWrite(BUZZER_PIN, 0); 
  ledcAttach(SERVO_PIN, 50, 12); setServoAngle(0);           

  IrReceiver.begin(IR_RECEIVE_PIN, DISABLE_LED_FEEDBACK); 
  IrSender.begin(IR_SEND_PIN); 

  Wire.begin(21, 22); 
  aht.begin();
  if (ens160.begin() == 0) ens160.setPWRMode(ENS160_STANDARD_MODE);

  // --- CẤU HÌNH WIFI CHỐNG ĐƠ ---
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.persistent(true);
  wm.setConfigPortalBlocking(false); 
  wm.setConfigPortalTimeout(180); 
  
  if (WiFi.SSID() != "") {
    WiFi.begin();
    Serial.println("[WIFI] Dang thu ket noi mang cu...");
  }
}

// --- LOOP CHÍNH ---
void loop() {
  wm.process(); // Luôn chạy nền để xử lý nút nhấn và WiFi Portal

  
  // 1. QUẢN LÝ WIFI & FIREBASE
  if (WiFi.status() != WL_CONNECTED) {
  firebaseStarted = false; 
  
  if (millis() - lastLedBlink > 500) { 
    lastLedBlink = millis();
    digitalWrite(LED_WIFI_PIN, !digitalRead(LED_WIFI_PIN));
  }

  if (millis() - lastWiFiReconnect > 10000) { 
    lastWiFiReconnect = millis();
    WiFi.reconnect(); 
  }
  } 
  else {
    // KHI CÓ MẠNG
    if (!firebaseStarted) {
      Serial.println("[WIFI] Da ket noi! Khoi tao Firebase...");
      digitalWrite(LED_WIFI_PIN, HIGH); // Sáng đèn báo hiệu vừa kết nối xong
      wifiConnectedTime = millis();     // Bắt đầu bấm giờ
      
      config.host = FIREBASE_HOST;
      config.signer.tokens.legacy_token = FIREBASE_AUTH;
      config.timeout.serverResponse = 10 * 1000; // Timeout tránh treo
      
      Firebase.begin(&config, &auth);
      Firebase.reconnectWiFi(true); 
      initFirebaseStream();
      firebaseStarted = true;
    } else {
      // Nếu đã kết nối thành công quá 10 giây (10000ms) -> Tắt LED D2 đi
      if (millis() - wifiConnectedTime > 10000) {
        digitalWrite(LED_WIFI_PIN, LOW);
      } else {
        // Trong 10 giây đầu tiên, vẫn giữ đèn sáng
        digitalWrite(LED_WIFI_PIN, HIGH);
      }
    }
  }

  // 2. XỬ LÝ NÚT NHẤN (CHỐNG TREO)
  int btnState = digitalRead(BUTTON_PIN);
  if (btnState == HIGH) {
    if (!isButtonPressed) {
      buttonPressTime = millis();
      isButtonPressed = true;
    }
    // Nhấn giữ 3 giây -> Mở cài đặt WiFi
    if (isButtonPressed && (millis() - buttonPressTime >= 3000)) {
      isButtonPressed = false; 
      Serial.println("[WIFI] Mo cong cau hinh...");
      ledcWrite(BUZZER_PIN, BUZZER_VOLUME); delay(150); ledcWrite(BUZZER_PIN, 0); delay(150);
      ledcWrite(BUZZER_PIN, BUZZER_VOLUME); delay(150); ledcWrite(BUZZER_PIN, 0);
      wm.startConfigPortal("ESP_SMARTHOME_SETUP");
      buttonPressTime = millis() + 5000; // Tránh lặp lệnh
    }
  } else {
    // Nhấn nhả nhanh (<3s) -> Tắt còi báo động
    if (isButtonPressed) {
      if (millis() - buttonPressTime < 3000) {
        if (millis() - lastDebounceTime > 250) { 
          lastDebounceTime = millis(); 
          ledcWrite(BUZZER_PIN, 0); currentBuzzer = 0; 
          if (firebaseStarted && Firebase.ready()) Firebase.setInt(dataFBDO, "/Huy_Project/Control/Buzzer", 0); 
        }
      }
      isButtonPressed = false;
    }
  }

  // 3. LOGIC OFFLINE (CẢM BIẾN GAS) - LUÔN CHẠY DÙ MẤT MẠNG
  int gasVal = digitalRead(MQ2_PIN);
  if (gasVal == 0 && lastGasState == 1 && (millis() - lastGasChangeTime > 2000)) { 
    lastGasChangeTime = millis(); lastGasState = 0;
    
    ledcWrite(BUZZER_PIN, BUZZER_VOLUME); digitalWrite(FAN_PIN, HIGH); setServoAngle(90);
    currentBuzzer = 1; currentFan = 1;
    
    if (firebaseStarted && Firebase.ready()) {
      Firebase.setInt(dataFBDO, "/Huy_Project/Control/Buzzer", 1);
      Firebase.setInt(dataFBDO, "/Huy_Project/Control/Fan", 1);
      Firebase.setString(dataFBDO, "/Huy_Project/Current/Alert/Smoke", "DANGER");
    }
  } else if (gasVal == 1 && lastGasState == 0 && (millis() - lastGasChangeTime > 2000)) { 
    lastGasChangeTime = millis(); lastGasState = 1;
    
    ledcWrite(BUZZER_PIN, 0); digitalWrite(FAN_PIN, LOW); setServoAngle(0);
    currentBuzzer = 0; currentFan = 0;
    
    if (firebaseStarted && Firebase.ready()) {
      Firebase.setInt(dataFBDO, "/Huy_Project/Control/Buzzer", 0);
      Firebase.setInt(dataFBDO, "/Huy_Project/Control/Fan", 0);
      Firebase.setString(dataFBDO, "/Huy_Project/Current/Alert/Smoke", "SAFE");
    }
  }

  // 4. ÁNH SÁNG TỰ ĐỘNG (LDR)
  if (millis() - lastCheckLDR > 1000) {
    lastCheckLDR = millis();
    bool currentDark = (analogRead(LDR_PIN) < 150); 
    
    if (currentDark != isDark) { 
      isDark = currentDark; 
      if (autoMode == 1) { // Chỉ tự động bật nếu AutoMode đang ON trên App
        currentLight = isDark ? 1 : 0;
        digitalWrite(LIGHT_PIN, currentLight ? HIGH : LOW); 
        if (firebaseStarted && Firebase.ready()) Firebase.setInt(dataFBDO, "/Huy_Project/Control/Light", currentLight);
      }
    }
  }

  // ====================================================================
  // PHẦN LOGIC ONLINE: CHỈ CHẠY KHI FIREBASE SẴN SÀNG
  // ====================================================================
  if (firebaseStarted && Firebase.ready()) {
    
    // 5.1 BẢO VỆ STREAM
    if (millis() - lastStreamWatchdog > 10000) { 
      lastStreamWatchdog = millis();
      if (!streamFBDO.httpConnected() || streamFBDO.streamTimeout()) {
        streamFBDO.clear(); initFirebaseStream();
      }
    }

    // 5.2 NHẬN LỆNH TỪ APP (STREAM)
    if (Firebase.readStream(streamFBDO)) {
      if (streamFBDO.streamAvailable()) {
        String path = streamFBDO.dataPath();
        String type = streamFBDO.dataType();
        
        if (type == "json") {
          FirebaseJson* json = streamFBDO.jsonObjectPtr(); FirebaseJsonData jd;

          json->get(jd, "Light");  if (jd.success) { digitalWrite(LIGHT_PIN, jd.intValue); currentLight = jd.intValue; }
          json->get(jd, "Fan");    if (jd.success) { digitalWrite(FAN_PIN, jd.intValue); currentFan = jd.intValue; }
          json->get(jd, "Buzzer"); if (jd.success) { ledcWrite(BUZZER_PIN, jd.intValue ? BUZZER_VOLUME : 0); currentBuzzer = jd.intValue; }
          
          json->get(jd, "LearnTarget");
          if (jd.success && jd.stringValue != "IDLE" && jd.stringValue != "DONE") {
             isLearning = true; learnTarget = jd.stringValue; IrReceiver.resume();
          } else if (jd.success && jd.stringValue == "IDLE") { isLearning = false; }

          int tmpAcOn = currentAcOn; int tmpAcTemp = currentAcTemp;
          json->get(jd, "AcOn");   if (jd.success) tmpAcOn = jd.intValue;
          json->get(jd, "AcTemp"); if (jd.success) tmpAcTemp = jd.intValue;

          if (tmpAcOn != currentAcOn) {
            if (tmpAcOn == 1) { transmitIRCode("ON"); } 
            else { transmitIRCode("OFF"); autoFired = false; }
          }
          currentAcOn = tmpAcOn; currentAcTemp = tmpAcTemp;

          json->get(jd, "IrFreq");      if (jd.success) currentIrFreq = jd.intValue;
          json->get(jd, "AutoMode");    if (jd.success) autoMode = jd.intValue;
          json->get(jd, "TriggerTemp"); if (jd.success) triggerTemp = jd.floatValue;
          json->get(jd, "TargetTemp");  if (jd.success) targetTemp = jd.intValue;
        } 
        else {
          if (path.indexOf("Light") != -1) { currentLight = streamFBDO.intData(); digitalWrite(LIGHT_PIN, currentLight); }
          else if (path.indexOf("Fan") != -1) { currentFan = streamFBDO.intData(); digitalWrite(FAN_PIN, currentFan); }
          else if (path.indexOf("Buzzer") != -1) { currentBuzzer = streamFBDO.intData(); ledcWrite(BUZZER_PIN, currentBuzzer ? BUZZER_VOLUME : 0); }
          else if (path.indexOf("LearnTarget") != -1) {
            String val = streamFBDO.stringData();
            if (val != "IDLE" && val != "DONE" && val != "") {
               isLearning = true; learnTarget = val; IrReceiver.resume();
            } else if (val == "IDLE") { isLearning = false; }
          }
          else if (path.indexOf("AcOn") != -1) {
            int val = streamFBDO.intData();
            if (val != currentAcOn && currentAcOn != -1) { 
                if (val == 1) { transmitIRCode("ON"); } 
                else { transmitIRCode("OFF"); autoFired = false; }
            }
            currentAcOn = val;
          }
          else if (path.indexOf("AcTemp") != -1) {
            int val = streamFBDO.intData();
            if (val != currentAcTemp && currentAcOn == 1) transmitIRCode(String(val));
            currentAcTemp = val;
          }
          else if (path.indexOf("IrFreq") != -1) currentIrFreq = streamFBDO.intData();
          else if (path.indexOf("AutoMode") != -1) autoMode = streamFBDO.intData();
          else if (path.indexOf("TriggerTemp") != -1) triggerTemp = streamFBDO.floatData();
          else if (path.indexOf("TargetTemp") != -1) targetTemp = streamFBDO.intData();
        }
      }
    }

    // 5.3 HỌC MÃ HỒNG NGOẠI
    if (IrReceiver.decode()) {
      int len = IrReceiver.irparams.rawlen;
      if (isLearning && len > 50) { 
        String dataStr = ""; dataStr.reserve(2000);
        for (int i = 1; i < len; i++) {
          dataStr += String(IrReceiver.irparams.rawbuf[i] * MICROS_PER_TICK) + (i < len - 1 ? "," : "");
        }
        if (Firebase.setString(dataFBDO, "/Huy_Project/IR_Dictionary/" + learnTarget, dataStr)) {
          Firebase.setString(dataFBDO, "/Huy_Project/Control/LearnTarget", "DONE");
          isLearning = false;
        }
      }
      IrReceiver.resume(); 
    }

    // 5.4 CẬP NHẬT CẢM BIẾN & ĐIỀU HÒA TỰ ĐỘNG
    if (millis() - lastSensorUpdate > 8000) {
      lastSensorUpdate = millis();
      
      sensors_event_t h, t; aht.getEvent(&h, &t);
      ens160.setTempAndHum(t.temperature, h.relative_humidity);
      
      // Auto Điều hòa (Chạy khi có mạng)
      if (autoMode == 1) {
        if (t.temperature >= triggerTemp && !autoFired) {
          autoFired = true; 
          if (currentAcOn != 1) { transmitIRCode("ON"); delay(1000); }
          transmitIRCode(String(targetTemp));
          
          currentAcOn = 1; currentAcTemp = targetTemp;
          Firebase.setInt(dataFBDO, "/Huy_Project/Control/AcOn", 1);
          Firebase.setInt(dataFBDO, "/Huy_Project/Control/AcTemp", targetTemp);
        } 
        else if (t.temperature < (triggerTemp - 1.0)) { 
          autoFired = false; 
        }
      }
      
      // Đẩy dữ liệu lên Cloud
      FirebaseJson j;
      j.set("Environment/Temp", t.temperature); 
      j.set("Environment/Humi", h.relative_humidity);
      j.set("Air/eCO2", ens160.getECO2()); 
      j.set("Air/TVOC", ens160.getTVOC());
      j.set("Air/AQI", ens160.getAQI()); 
      
      Firebase.setJSON(dataFBDO, "/Huy_Project/Current", j);
      
      if (millis() - lastHistoryUpdate > 8000) { 
        lastHistoryUpdate = millis();
        Firebase.pushJSON(dataFBDO, "/Huy_Project/History", j);
      }
    }
  }
}
