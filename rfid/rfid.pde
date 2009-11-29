/* RFID ID12
 */

const byte ASCII_STX = 0x02; // Start of text
const byte ASCII_ETX = 0x03; // End of text
const byte ASCII_CR  = 0x0D; // Carriage Return
const byte ASCII_LF  = 0x0A; // Line feed

// Size of an RFID number in bytes.
const size_t RFID_BYTES = 5;

// Size of character array of ASCII string representation of an RFID with 1 byte checksum.
const size_t RFID_LENGTH = (RFID_BYTES + 1) * 2;

void setup() {
  Serial.begin(9600);
}

void loop() {
  byte cardId = 0;
  
  if (Serial.available() > 0) {
    processSerialData(Serial.read());
  }
  
  // Card present
  if (cardId > 0) {
    processCardArrival(cardId);
  }
}

void processSerialData(byte value) {
  static byte started = 0;
  static byte bytesRead = 0;
  static char rfid[RFID_LENGTH+1] = "";
   
  /*
  Serial.print("DEBUG: ");
  Serial.print(value, HEX);
  Serial.print(" ");
  Serial.print(started, DEC);
  Serial.print(" ");
  Serial.print(bytesRead, DEC);
  Serial.print(" ");
  Serial.println(rfid);
  */
  
  if (ASCII_STX == value) {
      started = 1;
      bytesRead = 0;
      return;
  }

  // Throw away data until we get a START TEXT indicator.
  if (!started) {
    return;
  }

  if (ASCII_ETX == value) {
    started = 0;
    if (RFID_LENGTH == bytesRead) {
      rfid[bytesRead] = '\0';
      Serial.print("RFID: ");
      Serial.println(rfid);
      determineCardId(rfid);
    }
    return;
  }

  // Ignore carriage returns and line feeds.
  if ((ASCII_CR == value) || (ASCII_LF == value)) {
    return;
  }

  bytesRead++;
  if (bytesRead > RFID_LENGTH) {
    started = 0;
    return;
  }
  rfid[bytesRead-1] = value;
}

byte determineCardId(char* uniqueHexName) {
  size_t nameLength = strlen(uniqueHexName);
  if (nameLength != RFID_LENGTH) {
    return 0;
  }
  
  byte uniqueId[RFID_BYTES];
  byte recordedChecksum = 0;
  byte calculatedChecksum = 0;

  for(int i = 0; i <= RFID_BYTES; i++) {
    char byteStr[3] = {*uniqueHexName, *(uniqueHexName + sizeof(char)), '\0'};
    Serial.println(byteStr);
    uniqueId[i] = (byte)strtoul(byteStr, NULL, 16);
    uniqueHexName += (2 * sizeof(char));
    calculatedChecksum = calculatedChecksum ^ uniqueId[i];
  }
  recordedChecksum = (byte)strtoul(uniqueHexName, NULL, 16);
  
  if (recordedChecksum != calculatedChecksum) {
    // checksum mismatch - so reject
    return 0;
  }
  
  //TODO: Store unique names in EEPROM
  return uniqueId[RFID_BYTES-1];
}

void processCardArrival(byte cardId) {
  return;
}
