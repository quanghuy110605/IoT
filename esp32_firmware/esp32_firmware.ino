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

FirebaseData fbdoRead;   // LUỒNG 1: Chuyên Stream siêu tốc từ Web về
FirebaseData fbdoWrite;  // LUỒNG 2: Chuyên đẩy Cảm biến lên Web
FirebaseAuth auth;
FirebaseConfig config;

unsigned long lastUpdateCurrent = 0;
unsigned long lastUpdateHistory = 0;
unsigned long lastCheckLDR = 0;

bool isLearning = false;
String learnTarget = ""; 

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
  Serial.println("[DEBUG-TRANSMIT] Dang lay ma phat IR cho nut: " + targetNode);
  
  // Dùng fbdoWrite để không làm đứt luồng Stream của fbdoRead
  if (Firebase.getString(fbdoWrite, "/Huy_Project/IR_Dictionary/" + targetNode)) {
    String rawDataStr = fbdoWrite.stringData();
    if (rawDataStr == "" || rawDataStr == "null") {
      Serial.println("[LỖI] Nut nay chua duoc hoc ma! Vui long hoc tren Web.");
      return;
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
    Serial.println("[DEBUG-TRANSMIT] DA PHAT XONG TIA HONG NGOAI THANH CONG!");
  } else {
    Serial.println("[LỖI] Khong doc duoc ma tu Firebase!");
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

  Serial.print("[DEBUG] Dang ket noi WiFi: ");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) { delay(500); Serial.print("."); }
  Serial.println("\n[DEBUG] WiFi OK!");

  config.host = FIREBASE_HOST;
  config.signer.tokens.legacy_token = FIREBASE_AUTH;
  fbdoRead.setBSSLBufferSize(2048, 1024); 
  fbdoWrite.setBSSLBufferSize(2048, 1024); 

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  // MỞ KẾT NỐI STREAM SIÊU TỐC TRÊN NHÁNH CONTROL
  if (!Firebase.beginStream(fbdoRead, "/Huy_Project/Control")) {
    Serial.println("[LỖI] Khong the mo luong Stream: " + fbdoRead.errorReason());
  } else {
    Serial.println("[DEBUG] Kich hoat Stream thanh cong! Do tre = 0.");
  }

  Serial.println("[DEBUG] He thong san sang!");
}

// ====================================================================
void loop() {
  // ----------------------------------------------------
  // 0. XỬ LÝ NÚT NHẤN TẮT CÒI 
  // ----------------------------------------------------
  bool btnState = digitalRead(BUTTON_PIN);
  if (btnState == HIGH && lastBtnState == LOW) { 
    Serial.println("\n[DEBUG-ALARM] Da bam nut tat coi tren mach!");
    ledcWrite(BUZZER_PIN, 0); 
    lastWebBuzzer = 0; 
    Firebase.setInt(fbdoWrite, "/Huy_Project/Control/Buzzer", 0); 
    delay(200); 
  }
  lastBtnState = btnState;

  // ----------------------------------------------------
  // 1. CẢM BIẾN GAS -> ĐỒNG BỘ JSON LÊN WEB (REAL-TIME)
  // ----------------------------------------------------
  int gasValue = digitalRead(MQ2_PIN);
  if (gasValue == 0 && lastGasState == 1) { 
    Serial.println("\n[DEBUG-ALARM] CO KHI GAS! BAT COI, QUAT VA MO CUA!");
    ledcWrite(BUZZER_PIN, 128); 
    digitalWrite(FAN_PIN, HIGH);
    setServoAngle(90); 
    lastWebBuzzer = 1; lastWebFan = 1;
    
    FirebaseJson alarmJson;
    alarmJson.set("Buzzer", 1);
    alarmJson.set("Fan", 1);
    Firebase.updateNode(fbdoWrite, "/Huy_Project/Control", alarmJson);
    Firebase.setString(fbdoWrite, "/Huy_Project/Current/Alert/Smoke", "DANGER");
  } 
  else if (gasValue == 1 && lastGasState == 0) {
    Serial.println("\n[DEBUG-ALARM] DA HET KHI GAS! TAT BAO DONG, DONG CUA.");
    ledcWrite(BUZZER_PIN, 0); 
    digitalWrite(FAN_PIN, LOW);
    setServoAngle(0); 
    lastWebBuzzer = 0; lastWebFan = 0;

    FirebaseJson alarmJson;
    alarmJson.set("Buzzer", 0);
    alarmJson.set("Fan", 0);
    Firebase.updateNode(fbdoWrite, "/Huy_Project/Control", alarmJson);
    Firebase.setString(fbdoWrite, "/Huy_Project/Current/Alert/Smoke", "SAFE");
  }
  lastGasState = gasValue;

  // ----------------------------------------------------
  // 2. CẢM BIẾN ÁNH SÁNG LDR
  // ----------------------------------------------------
  if (millis() - lastCheckLDR > 2000) {
    lastCheckLDR = millis();
    int ldrValue = analogRead(LDR_PIN); 
    bool currentDark = (ldrValue < 100); 

    if (currentDark != isDark) {
      isDark = currentDark;
      Serial.println(isDark ? "[DEBUG-LDR] Troi TOI -> BAT DEN!" : "[DEBUG-LDR] Troi SANG -> TAT DEN!");
      digitalWrite(LIGHT_PIN, isDark ? HIGH : LOW);
      lastWebLight = (isDark ? 1 : 0);
      Firebase.setInt(fbdoWrite, "/Huy_Project/Control/Light", isDark ? 1 : 0);
    }
  }

  // ----------------------------------------------------
  // 3. ĐỌC LỆNH TỪ WEB BẰNG STREAM (SIÊU NHANH, ĐỘ TRỄ ~0.05s)
  // ----------------------------------------------------
  if (!Firebase.readStream(fbdoRead)) {
    Serial.println("[LỖI STREAM] Dang ket noi lai...");
    Firebase.beginStream(fbdoRead, "/Huy_Project/Control");
  }

  if (fbdoRead.streamAvailable()) {
    String path = fbdoRead.dataPath(); // Trả về dạng "/Light" hoặc "/Fan"
    String type = fbdoRead.dataType();

    // Nếu thay đổi từng biến lẻ (Kiểu INT)
    if (type == "int" || type == "double") {
      int val = fbdoRead.intData();
      
      if (path == "/Light" && val != lastWebLight) {
        digitalWrite(LIGHT_PIN, val == 1 ? HIGH : LOW);
        lastWebLight = val;
      } 
      else if (path == "/Fan" && val != lastWebFan) {
        digitalWrite(FAN_PIN, val == 1 ? HIGH : LOW);
        lastWebFan = val;
      } 
      else if (path == "/Buzzer" && val != lastWebBuzzer) {
        ledcWrite(BUZZER_PIN, val == 1 ? 128 : 0);
        lastWebBuzzer = val;
      } 
      else if (path == "/AcOn") {
        if (val != lastAcOn && lastAcOn != -1) {
          Serial.println("\n[DEBUG-AC] WEB yeu cau BAT/TAT Dieu hoa!");
          transmitIRCode(val == 1 ? "ON" : "OFF");
        }
        lastAcOn = val;
      } 
      else if (path == "/AcTemp") {
        if (val != lastAcTemp && lastAcTemp != -1) {
          if (lastAcOn == 1) { // Chỉ chỉnh nhiệt độ khi ĐH đang bật
            Serial.println("\n[DEBUG-AC] WEB yeu cau DOI NHIET DO: " + String(val));
            transmitIRCode(String(val));
          }
        }
        lastAcTemp = val;
      }
    } 
    // Xử lý lệnh Học mã IR (Kiểu STRING)
    else if (type == "string" && path == "/LearnTarget") {
      String val = fbdoRead.stringData();
      if (val != "IDLE" && val != "DONE" && val != "") {
        if (!isLearning || learnTarget != val) {
          isLearning = true; learnTarget = val;
          Serial.println("\n[DEBUG-IR] *** WEB YEU CAU HOC MA ***");
        }
      } else if (val == "IDLE" && isLearning) {
        isLearning = false; learnTarget = "";
      }
    }
    // Xử lý lúc ESP32 vừa khởi động (Tải cả cục JSON về để nạp trạng thái ban đầu)
    else if (type == "json") {
      FirebaseJsonData jsonData;
      fbdoRead.jsonObject().get(jsonData, "Light"); if (jsonData.success) { digitalWrite(LIGHT_PIN, jsonData.intValue == 1 ? HIGH : LOW); lastWebLight = jsonData.intValue; }
      fbdoRead.jsonObject().get(jsonData, "Fan");   if (jsonData.success) { digitalWrite(FAN_PIN, jsonData.intValue == 1 ? HIGH : LOW); lastWebFan = jsonData.intValue; }
      fbdoRead.jsonObject().get(jsonData, "Buzzer");if (jsonData.success) { ledcWrite(BUZZER_PIN, jsonData.intValue == 1 ? 128 : 0); lastWebBuzzer = jsonData.intValue; }
      fbdoRead.jsonObject().get(jsonData, "AcOn");  if (jsonData.success) lastAcOn = jsonData.intValue;
      fbdoRead.jsonObject().get(jsonData, "AcTemp");if (jsonData.success) lastAcTemp = jsonData.intValue;
    }
  }

  // ----------------------------------------------------
  // 4. CHẾ ĐỘ THU/HỌC IR
  // ----------------------------------------------------
  if (IrReceiver.decode()) {
    if (isLearning) {
      Serial.println("\n[DEBUG-IR] === DANG HOC MA TỪ REMOTE ===");
      int rawLength = IrReceiver.irparams.rawlen;
      if (rawLength > 5) { 
        String rawDataStr = ""; rawDataStr.reserve(4000); 
        for (int i = 1; i < rawLength; i++) {
          rawDataStr += String(IrReceiver.irparams.rawbuf[i] * MICROS_PER_TICK);
          if (i < rawLength - 1) rawDataStr += ",";
        }
        Serial.println("[DEBUG-IR] CHUOI MA VUA HOC DUOC:\n" + rawDataStr);
        if (Firebase.setString(fbdoWrite, "/Huy_Project/IR_Dictionary/" + learnTarget, rawDataStr)) {
          if (Firebase.setString(fbdoWrite, "/Huy_Project/Control/LearnTarget", "DONE")) {
             Serial.println("[DEBUG-FIREBASE] Da bao cho Web: DONE thanh cong!");
             isLearning = false; learnTarget = "";
          }
        }
      }
    }
    IrReceiver.resume(); 
  }

  // ----------------------------------------------------
  // 5. ĐỌC CẢM BIẾN VÀ ĐỒNG BỘ LÊN FIREBASE (Mỗi 2 giây)
  // ----------------------------------------------------
  if (millis() - lastUpdateCurrent > 2000) {
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
    
    // Đẩy Cảm biến lên bằng fbdoWrite, không ảnh hưởng đến luồng nghe Web!
    Firebase.updateNode(fbdoWrite, "/Huy_Project/Current", json);

    if (millis() - lastUpdateHistory > 30000) {
      lastUpdateHistory = millis();
      Firebase.pushJSON(fbdoWrite, "/Huy_Project/History", json);
    }
  }
}