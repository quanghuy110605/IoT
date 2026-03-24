#include <Arduino.h>
#include <WiFi.h>
#include <FirebaseESP32.h>
#include <Wire.h>
#include <Adafruit_AHTX0.h>
#include "DFRobot_ENS160.h"

#define RAW_BUFFER_LENGTH 1000 
#define RECORD_GAP_MICROS 50000 
#define IR_RECEIVE_PIN 27 
#define IR_SEND_PIN 4    
#include <IRremote.hpp> 

#define WIFI_SSID "Hoai Trang"
#define WIFI_PASSWORD "hoaitrang"
#define FIREBASE_HOST "fir-1esp-default-rtdb.firebaseio.com"
#define FIREBASE_AUTH "JdfPW1FHbYxHj5s6zjPOAqvk9dNT287RzkQAtJEf" 

#define MQ2_PIN 34
#define LDR_PIN 32       
#define LIGHT_PIN 16     
#define FAN_PIN 18       
#define SERVO_PIN 19     
#define BUZZER_PIN 33    
#define BUTTON_PIN 14    

Adafruit_AHTX0 aht;
DFRobot_ENS160_I2C ens160(&Wire, 0x53);

FirebaseData streamFBDO; 
FirebaseData dataFBDO;   
FirebaseAuth auth;
FirebaseConfig config;

unsigned long lastSensorUpdate = 0;
unsigned long lastHistoryUpdate = 0;
unsigned long lastStreamWatchdog = 0;
unsigned long lastGasChangeTime = 0;
unsigned long lastDebounceTime = 0;
unsigned long lastCheckLDR = 0;

bool isLearning = false;
String learnTarget = ""; 

int currentLight = -1, currentFan = -1, currentBuzzer = -1;
int currentAcOn = -1, currentAcTemp = -1;
int lastGasState = 1;     
bool lastBtnState = LOW, isDark = false;

void setServoAngle(int angle) {
  int duty = map(angle, 0, 180, 102, 512); 
  ledcWrite(SERVO_PIN, duty);
}

void initFirebaseStream() {
  Serial.println("\n[SYSTEM] Khoi tao luong Stream...");
  if (!Firebase.beginStream(streamFBDO, "/Huy_Project/Control")) {
    Serial.printf("[SYSTEM] Loi Stream: %s\n", streamFBDO.errorReason().c_str());
  } else {
    Serial.println("[SYSTEM] Stream ket noi THANH CONG!");
  }
}

void transmitIRCode(String targetNode) {
  Serial.printf("\n[IR-ACTION] Yeu cau phat ma: %s\n", targetNode.c_str());
  
  if (Firebase.getString(dataFBDO, "/Huy_Project/IR_Dictionary/" + targetNode)) {
    String rawDataStr = dataFBDO.stringData();
    if (rawDataStr == "" || rawDataStr == "null") {
      Serial.println("[IR-ACTION] -> LOI: Nut nay chua duoc hoc ma!"); return;
    }
    
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
    IrSender.sendRaw(rawArray, rawLength, 38);
    delete[] rawArray;
    Serial.println("[IR-ACTION] -> Phat tia Hong ngoai THANH CONG!");
  } else {
    Serial.printf("[IR-ACTION] -> Khong lay duoc ma: %s\n", dataFBDO.errorReason().c_str());
  }
}

void setup() {
  Serial.begin(115200);
  
  pinMode(LIGHT_PIN, OUTPUT); pinMode(FAN_PIN, OUTPUT);
  pinMode(MQ2_PIN, INPUT); pinMode(BUTTON_PIN, INPUT); pinMode(LDR_PIN, INPUT); 

  ledcAttach(BUZZER_PIN, 2500, 8); ledcWrite(BUZZER_PIN, 0); 
  ledcAttach(SERVO_PIN, 50, 12); setServoAngle(0);

  IrReceiver.begin(IR_RECEIVE_PIN, DISABLE_LED_FEEDBACK);
  IrSender.begin(IR_SEND_PIN); 

  Wire.begin(21, 22);
  aht.begin();
  if (ens160.begin() == 0) ens160.setPWRMode(ENS160_STANDARD_MODE);

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) { delay(500); }

  config.host = FIREBASE_HOST;
  config.signer.tokens.legacy_token = FIREBASE_AUTH;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  initFirebaseStream();
}

void loop() {
  if (millis() - lastStreamWatchdog > 10000) { 
    lastStreamWatchdog = millis();
    if (!Firebase.ready() || !streamFBDO.httpConnected() || streamFBDO.streamTimeout()) {
      streamFBDO.clear();
      initFirebaseStream();
    }
  }

  if (Firebase.readStream(streamFBDO)) {
    if (streamFBDO.streamAvailable()) {
      String path = streamFBDO.dataPath();
      String type = streamFBDO.dataType();
      
      if (type == "json") {
        FirebaseJson* json = streamFBDO.jsonObjectPtr();
        FirebaseJsonData jd;

        json->get(jd, "Light");  if (jd.success) { digitalWrite(LIGHT_PIN, jd.intValue); currentLight = jd.intValue; }
        json->get(jd, "Fan");    if (jd.success) { digitalWrite(FAN_PIN, jd.intValue); currentFan = jd.intValue; }
        json->get(jd, "Buzzer"); if (jd.success) { ledcWrite(BUZZER_PIN, jd.intValue ? 128 : 0); currentBuzzer = jd.intValue; }
        
        json->get(jd, "LearnTarget");
        if (jd.success && jd.stringValue != "IDLE" && jd.stringValue != "DONE") {
           isLearning = true; learnTarget = jd.stringValue; IrReceiver.resume();
        } else if (jd.success && jd.stringValue == "IDLE") { isLearning = false; }

        int tmpAcOn = currentAcOn; int tmpAcTemp = currentAcTemp;
        json->get(jd, "AcOn");   if (jd.success) tmpAcOn = jd.intValue;
        json->get(jd, "AcTemp"); if (jd.success) tmpAcTemp = jd.intValue;

        if (tmpAcOn != currentAcOn) {
          if (tmpAcOn == 1) transmitIRCode("ON"); 
          else transmitIRCode("OFF");
        }
        currentAcOn = tmpAcOn; currentAcTemp = tmpAcTemp;
      } 
      else {
        if (path.indexOf("Light") != -1) { 
          currentLight = streamFBDO.intData(); digitalWrite(LIGHT_PIN, currentLight); 
        }
        else if (path.indexOf("Fan") != -1) { 
          currentFan = streamFBDO.intData(); digitalWrite(FAN_PIN, currentFan); 
        }
        else if (path.indexOf("Buzzer") != -1) { 
          currentBuzzer = streamFBDO.intData(); ledcWrite(BUZZER_PIN, currentBuzzer ? 128 : 0); 
        }
        else if (path.indexOf("LearnTarget") != -1) {
          String val = streamFBDO.stringData();
          if (val != "IDLE" && val != "DONE" && val != "") {
             isLearning = true; learnTarget = val; IrReceiver.resume();
          } else if (val == "IDLE") { isLearning = false; }
        }
        else if (path.indexOf("AcOn") != -1) {
          int val = streamFBDO.intData();
          if (val != currentAcOn && currentAcOn != -1) {
             if (val == 1) transmitIRCode("ON"); 
             else transmitIRCode("OFF");
          }
          currentAcOn = val;
        }
        else if (path.indexOf("AcTemp") != -1) {
          int val = streamFBDO.intData();
          if (val != currentAcTemp && currentAcOn == 1) transmitIRCode(String(val));
          currentAcTemp = val;
        }
      }
    }
  }

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

  if (digitalRead(BUTTON_PIN) == HIGH && lastBtnState == LOW) {
    if (millis() - lastDebounceTime > 250) {
      lastDebounceTime = millis(); ledcWrite(BUZZER_PIN, 0); currentBuzzer = 0;
      Firebase.setInt(dataFBDO, "/Huy_Project/Control/Buzzer", 0);
    }
  }
  lastBtnState = digitalRead(BUTTON_PIN);

  int gasVal = digitalRead(MQ2_PIN);
  if (gasVal == 0 && lastGasState == 1 && (millis() - lastGasChangeTime > 2000)) {
    lastGasChangeTime = millis(); lastGasState = 0;
    ledcWrite(BUZZER_PIN, 128); digitalWrite(FAN_PIN, HIGH); setServoAngle(90);
    FirebaseJson alert; alert.set("Buzzer", 1); alert.set("Fan", 1);
    Firebase.updateNode(dataFBDO, "/Huy_Project/Control", alert);
    Firebase.setString(dataFBDO, "/Huy_Project/Current/Alert/Smoke", "DANGER");
  } else if (gasVal == 1 && lastGasState == 0 && (millis() - lastGasChangeTime > 2000)) {
    lastGasChangeTime = millis(); lastGasState = 1;
    ledcWrite(BUZZER_PIN, 0); digitalWrite(FAN_PIN, LOW); setServoAngle(0);
    FirebaseJson alert; alert.set("Buzzer", 0); alert.set("Fan", 0);
    Firebase.updateNode(dataFBDO, "/Huy_Project/Control", alert);
    Firebase.setString(dataFBDO, "/Huy_Project/Current/Alert/Smoke", "SAFE");
  }

  if (millis() - lastCheckLDR > 2000) {
    lastCheckLDR = millis();
    bool currentDark = (analogRead(LDR_PIN) < 150); 
    if (currentDark != isDark) {
      isDark = currentDark; digitalWrite(LIGHT_PIN, isDark ? HIGH : LOW); currentLight = isDark ? 1 : 0;
      Firebase.setInt(dataFBDO, "/Huy_Project/Control/Light", currentLight);
    }
  }

  if (millis() - lastSensorUpdate > 8000) {
    lastSensorUpdate = millis();
    sensors_event_t h, t; aht.getEvent(&h, &t);
    ens160.setTempAndHum(t.temperature, h.relative_humidity);
    
    FirebaseJson j;
    j.set("Environment/Temp", t.temperature); j.set("Environment/Humi", h.relative_humidity);
    j.set("Air/eCO2", ens160.getECO2()); j.set("Air/TVOC", ens160.getTVOC());
    j.set("Air/AQI", ens160.getAQI()); 
    
    Firebase.setJSON(dataFBDO, "/Huy_Project/Current", j);
    
    if (millis() - lastHistoryUpdate > 60000) { 
      lastHistoryUpdate = millis();
      Firebase.pushJSON(dataFBDO, "/Huy_Project/History", j);
    }
  }
}