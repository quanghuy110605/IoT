#include <WiFi.h>
#include <FirebaseESP32.h>
#include <Wire.h>
#include <Adafruit_AHTX0.h>
#include "DFRobot_ENS160.h"

#define RAW_BUFFER_LENGTH 1000 
#include <IRremote.hpp> 

// --- CẤU HÌNH WIFI & FIREBASE ---
#define WIFI_SSID "Hoai Trang"
#define WIFI_PASSWORD "hoaitrang"
#define FIREBASE_HOST "fir-1esp-default-rtdb.firebaseio.com"
#define FIREBASE_AUTH "AIzaSyAMqDt8myAePFpsqbw3zh2ItzPAV8VPrK4"

// --- KHAI BÁO CHÂN CHUẨN ---
#define MQ2_PIN 34
#define LDR_PIN 32       
#define LIGHT_PIN 16     
#define FAN_PIN 18       
#define SERVO_PIN 19     
#define BUZZER_PIN 33    
#define BUTTON_PIN 14    
#define IR_RECEIVE_PIN 27 
#define IR_SEND_PIN 4    

Adafruit_AHTX0 aht;
DFRobot_ENS160_I2C ens160(&Wire, 0x53);

FirebaseData fbdoRead;   
FirebaseData fbdoWrite;  
FirebaseAuth auth;
FirebaseConfig config;

// Các biến đếm thời gian
unsigned long lastUpdateCurrent = 0;
unsigned long lastUpdateHistory = 0;
unsigned long lastCheckLDR = 0;
unsigned long lastDebounceTime = 0;     
unsigned long lastStreamReconnect = 0;  
unsigned long lastGasChangeTime = 0; // Thêm biến chống dội (debounce) cho MQ2

bool isLearning = false;
String learnTarget = ""; 
bool streamCrashed = false; 

int lastWebLight = -1;
int lastWebFan = -1;
int lastWebBuzzer = -1;
int lastAcOn = -1;
int lastAcTemp = -1;

int lastGasState = 1;     
bool lastBtnState = LOW;  
bool isDark = false;      

// ====================================================================
void setServoAngle(int angle) {
  int duty = map(angle, 0, 180, 102, 512); 
  ledcWrite(SERVO_PIN, duty);
}

void transmitIRCode(String targetNode) {
  Serial.println("\n[DEBUG-TRANSMIT] === CHUAN BI PHAT HONG NGOAI ===");
  if (Firebase.getString(fbdoWrite, "/Huy_Project/IR_Dictionary/" + targetNode)) {
    String rawDataStr = fbdoWrite.stringData();
    fbdoWrite.clear(); 
    
    if (rawDataStr == "" || rawDataStr == "null") {
      Serial.println("[LỖI] Nut nay chua duoc hoc ma!"); return;
    }
    
    int commaCount = 0;
    for (int i = 0; i < rawDataStr.length(); i++) {
      if (rawDataStr.charAt(i) == ',') commaCount++;
    }
    int rawLength = commaCount + 1;
    uint16_t rawArray[rawLength];
    int arrayIndex = 0, startIndex = 0;
    for (int i = 0; i <= rawDataStr.length(); i++) {
      if (i == rawDataStr.length() || rawDataStr.charAt(i) == ',') {
        rawArray[arrayIndex++] = rawDataStr.substring(startIndex, i).toInt();
        startIndex = i + 1;
      }
    }
    IrSender.sendRaw(rawArray, rawLength, 38);
    Serial.println("[DEBUG-TRANSMIT] DA PHAT XONG!");
  }
}

// ====================================================================
void setup() {
  Serial.begin(115200);
  Serial.println("\n\n[DEBUG] === BAT DAU KHOI DONG ESP32 ===");

  pinMode(LIGHT_PIN, OUTPUT);
  pinMode(FAN_PIN, OUTPUT);
  pinMode(MQ2_PIN, INPUT);
  pinMode(BUTTON_PIN, INPUT); 
  pinMode(LDR_PIN, INPUT); 

  digitalWrite(LIGHT_PIN, LOW);
  digitalWrite(FAN_PIN, LOW);

  ledcAttach(BUZZER_PIN, 2500, 8); 
  ledcWrite(BUZZER_PIN, 0); 
  
  ledcAttach(SERVO_PIN, 50, 12); 
  setServoAngle(0);              

  IrReceiver.begin(IR_RECEIVE_PIN, DISABLE_LED_FEEDBACK);
  IrSender.begin(IR_SEND_PIN); 

  Wire.begin(21, 22);
  if (!aht.begin()) Serial.println("[LỖI] Khong tim thay AHT21!");
  while (ens160.begin() != 0) { Serial.println("[DEBUG] Doi ENS160..."); delay(1000); }
  ens160.setPWRMode(ENS160_STANDARD_MODE);

  Serial.print("[DEBUG] Dang ket noi WiFi");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) { delay(500); Serial.print("."); }
  Serial.println("\n[DEBUG] WiFi OK!");

  config.host = FIREBASE_HOST;
  config.signer.tokens.legacy_token = FIREBASE_AUTH;
  
  fbdoRead.setBSSLBufferSize(4096, 1024); 
  fbdoWrite.setBSSLBufferSize(4096, 1024); 

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  if (!Firebase.beginStream(fbdoRead, "/Huy_Project/Control")) {
    Serial.println("[LỖI] Khong the mo luong Stream: " + fbdoRead.errorReason());
    streamCrashed = true; 
  } else {
    Serial.println("[DEBUG] Kich hoat Stream thanh cong! Do tre = 0.");
  }
}

// ====================================================================
void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[LỖI WIFI] Mat ket noi mang! Dang thu lai...");
    WiFi.disconnect(); WiFi.reconnect(); delay(3000); return;
  }

  // ----------------------------------------------------
  // 1. XỬ LÝ NÚT NHẤN TẮT CÒI 
  // ----------------------------------------------------
  bool btnState = digitalRead(BUTTON_PIN);
  if (btnState == HIGH && lastBtnState == LOW) { 
    if (millis() - lastDebounceTime > 250) { 
      lastDebounceTime = millis();
      Serial.println("\n[DEBUG-ALARM] Da bam nut tat coi tren mach!");
      ledcWrite(BUZZER_PIN, 0); lastWebBuzzer = 0; 
      Firebase.setInt(fbdoWrite, "/Huy_Project/Control/Buzzer", 0); 
      fbdoWrite.clear(); 
    }
  }
  lastBtnState = btnState;

  // ----------------------------------------------------
  // 2. CẢM BIẾN GAS (Đã xử lý dội tín hiệu để không văng WiFi)
  // ----------------------------------------------------
  int gasValue = digitalRead(MQ2_PIN);
  if (gasValue == 0 && lastGasState == 1 && (millis() - lastGasChangeTime > 2000)) { 
    lastGasChangeTime = millis();
    lastGasState = 0;
    ledcWrite(BUZZER_PIN, 128); digitalWrite(FAN_PIN, HIGH); setServoAngle(90); 
    lastWebBuzzer = 1; lastWebFan = 1;
    FirebaseJson alarmJson; alarmJson.set("Buzzer", 1); alarmJson.set("Fan", 1);
    Firebase.updateNode(fbdoWrite, "/Huy_Project/Control", alarmJson); fbdoWrite.clear();
    Firebase.setString(fbdoWrite, "/Huy_Project/Current/Alert/Smoke", "DANGER"); fbdoWrite.clear();
  } 
  else if (gasValue == 1 && lastGasState == 0 && (millis() - lastGasChangeTime > 2000)) {
    lastGasChangeTime = millis();
    lastGasState = 1;
    ledcWrite(BUZZER_PIN, 0); digitalWrite(FAN_PIN, LOW); setServoAngle(0); 
    lastWebBuzzer = 0; lastWebFan = 0;
    FirebaseJson alarmJson; alarmJson.set("Buzzer", 0); alarmJson.set("Fan", 0);
    Firebase.updateNode(fbdoWrite, "/Huy_Project/Control", alarmJson); fbdoWrite.clear();
    Firebase.setString(fbdoWrite, "/Huy_Project/Current/Alert/Smoke", "SAFE"); fbdoWrite.clear();
  }

  // ----------------------------------------------------
  // 3. CẢM BIẾN ÁNH SÁNG LDR (Lọc 2 giây/lần giảm tải stream)
  // ----------------------------------------------------
  if (millis() - lastCheckLDR > 2000) {
    lastCheckLDR = millis();
    int ldrValue = analogRead(LDR_PIN); 
    bool currentDark = (ldrValue < 100); 
    if (currentDark != isDark) {
      isDark = currentDark;
      digitalWrite(LIGHT_PIN, isDark ? HIGH : LOW); lastWebLight = (isDark ? 1 : 0);
      Firebase.setInt(fbdoWrite, "/Huy_Project/Control/Light", isDark ? 1 : 0);
      fbdoWrite.clear(); 
    }
  }

  // ----------------------------------------------------
  // 4. ĐỌC STREAM FIREBASE (Đã sửa chuẩn theo Mobizt)
  // ----------------------------------------------------
  if (Firebase.ready()) {
    if (!Firebase.readStream(fbdoRead)) {
      // In ra lỗi cụ thể
      Serial.println("[LỖI STREAM] Đứt luồng, nguyên nhân: " + fbdoRead.errorReason());
      
      // Cơ chế tự phục hồi stream nếu đứt quá lâu (5s)
      if (millis() - lastStreamReconnect > 5000) {
        lastStreamReconnect = millis();
        Serial.println("[DEBUG-STREAM] Đang thử khôi phục lại luồng Stream...");
        Firebase.beginStream(fbdoRead, "/Huy_Project/Control");
      }
    } else {
      lastStreamReconnect = millis(); // Stream còn bám sóng thì cập nhật mốc
    }

    if (fbdoRead.streamTimeout()) {
       Serial.println("[DEBUG-STREAM] Stream timeout, đang tự reconnect...");
    }
    
    if (fbdoRead.streamAvailable()) {
      String path = fbdoRead.dataPath(); 
      String type = fbdoRead.dataType();

      if (type == "int" || type == "double") {
        int val = fbdoRead.intData();
        if (path == "/Light" && val != lastWebLight) { digitalWrite(LIGHT_PIN, val == 1 ? HIGH : LOW); lastWebLight = val; } 
        else if (path == "/Fan" && val != lastWebFan) { digitalWrite(FAN_PIN, val == 1 ? HIGH : LOW); lastWebFan = val; } 
        else if (path == "/Buzzer" && val != lastWebBuzzer) { ledcWrite(BUZZER_PIN, val == 1 ? 128 : 0); lastWebBuzzer = val; } 
        else if (path == "/AcOn") {
          if (val != lastAcOn && lastAcOn != -1) { transmitIRCode(val == 1 ? "ON" : "OFF"); } lastAcOn = val;
        } 
        else if (path == "/AcTemp") {
          if (val != lastAcTemp && lastAcTemp != -1 && lastAcOn == 1) { transmitIRCode(String(val)); } lastAcTemp = val;
        }
      } 
      else if (type == "json") {
        FirebaseJson *json = fbdoRead.jsonObjectPtr();
        FirebaseJsonData jsonData;
        if (json->get(jsonData, "Light")) {
             int val = jsonData.intValue;
             if (val != lastWebLight) { digitalWrite(LIGHT_PIN, val == 1 ? HIGH : LOW); lastWebLight = val; }
        }
        if (json->get(jsonData, "Fan")) {
             int val = jsonData.intValue;
             if (val != lastWebFan) { digitalWrite(FAN_PIN, val == 1 ? HIGH : LOW); lastWebFan = val; }
        }
        if (json->get(jsonData, "Buzzer")) {
             int val = jsonData.intValue;
             if (val != lastWebBuzzer) { ledcWrite(BUZZER_PIN, val == 1 ? 128 : 0); lastWebBuzzer = val; }
        }
        if (json->get(jsonData, "AcOn")) {
             int val = jsonData.intValue;
             if (val != lastAcOn && lastAcOn != -1) { transmitIRCode(val == 1 ? "ON" : "OFF"); } lastAcOn = val;
        }
        if (json->get(jsonData, "AcTemp")) {
             int val = jsonData.intValue;
             if (val != lastAcTemp && lastAcTemp != -1 && lastAcOn == 1) { transmitIRCode(String(val)); } lastAcTemp = val;
        }
      } 
      else if (type == "string" && path == "/LearnTarget") {
        String val = fbdoRead.stringData();
        if (val != "IDLE" && val != "DONE" && val != "") {
          if (!isLearning || learnTarget != val) { 
             isLearning = true; 
             learnTarget = val; 
             IrReceiver.resume(); // Reset lại mắt thu để vứt bỏ các tín hiệu cũ/rác trước đó
             Serial.println("\n[DEBUG] BAT DAU HOC LENH: " + val);
          }
        } else if (val == "IDLE" && isLearning) { 
          isLearning = false; 
          learnTarget = ""; 
          Serial.println("[DEBUG] Dung hoc lenh (Ve IDLE)");
        }
      }
      fbdoRead.clear(); 
    }
  }

  // ----------------------------------------------------
  // 5. CHẾ ĐỘ THU HỌC IR (Log toàn bộ để bắt bệnh nhiễu)
  // ----------------------------------------------------
  if (IrReceiver.decode()) {
    int rawLength = IrReceiver.irparams.rawlen;
    
    // In ra Serial xem mắt hồng ngoại bắt được cái gì
    if (rawLength > 10) { 
      Serial.print("[DEBUG-IR] Mat thu bat duoc tia sang! Do dai = ");
      Serial.println(rawLength);
    }

    if (isLearning) {
      if (rawLength > 100) {  // Chỉnh siêu cao lên 100 để không thể nào là nhiễu được nữa
        Serial.println("[DEBUG-IR] -> DAY DUNG LA MA REMOTE THUC SU! Dang luu len Firebase...");
        String rawDataStr = ""; rawDataStr.reserve(4000); 
        for (int i = 1; i < rawLength; i++) {
          rawDataStr += String(IrReceiver.irparams.rawbuf[i] * MICROS_PER_TICK);
          if (i < rawLength - 1) rawDataStr += ",";
        }
        if (Firebase.setString(fbdoWrite, "/Huy_Project/IR_Dictionary/" + learnTarget, rawDataStr)) {
          if (Firebase.setString(fbdoWrite, "/Huy_Project/Control/LearnTarget", "DONE")) {
             Serial.println("[DEBUG-IR] -> LUONG HOC HOI TAT, DA BAO 'DONE' LEN APP FLUTTER!");
             isLearning = false; learnTarget = "";
          }
        }
        fbdoWrite.clear();
      } else {
        Serial.println("[DEBUG-IR] -> Ma qua ngan (nhiễu thạch anh/đèn). Da tu dong vut bo!");
      }
    }
    IrReceiver.resume(); 
  }

  // ----------------------------------------------------
  // 6. ĐỌC CẢM BIẾN VÀ ĐỒNG BỘ LÊN FIREBASE
  // ----------------------------------------------------
  if (millis() - lastUpdateCurrent > 5000) {
    lastUpdateCurrent = millis();
    sensors_event_t humidity, temp;
    aht.getEvent(&humidity, &temp);
    ens160.setTempAndHum(temp.temperature, humidity.relative_humidity);
    int gasVal = digitalRead(MQ2_PIN); 

    FirebaseJson json;
    json.set("Environment/Temp", temp.temperature);
    json.set("Environment/Humi", humidity.relative_humidity);
    json.set("Air/eCO2", ens160.getECO2());
    json.set("Air/TVOC", ens160.getTVOC());
    json.set("Air/AQI", ens160.getAQI());
    json.set("Alert/Smoke", gasVal == 0 ? "DANGER" : "SAFE");
    
    Firebase.updateNode(fbdoWrite, "/Huy_Project/Current", json);
    fbdoWrite.clear(); 

    if (millis() - lastUpdateHistory > 30000) {
      lastUpdateHistory = millis();
      Firebase.pushJSON(fbdoWrite, "/Huy_Project/History", json);
      fbdoWrite.clear();
    }
  }
  
  delay(1); 
}