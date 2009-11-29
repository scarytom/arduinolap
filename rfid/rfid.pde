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

// Maximum number of cards that the system can track.
const size_t MAX_CARDS = 2;

void setup() {
  Serial.begin(9600);
}

void loop() {
  int cardId = -1;
  unsigned long currentTime = millis();

  if (Serial.available() > 0) {
    cardId = processSerialData(Serial.read());
  }
  
  // Card present
  if (cardId >= 0) {
    processCardArrival((byte)cardId, currentTime);
  }
}

int processSerialData(byte value) {
  static byte started = 0;
  static byte bytesRead = 0;
  static char rfid[RFID_LENGTH+1] = "";
  
  if (ASCII_STX == value) {
      started = 1;
      bytesRead = 0;
      return -1;
  }

  // Throw away data until we get a START TEXT indicator.
  if (!started) {
    return -1;
  }

  if (ASCII_ETX == value) {
    started = 0;
    if (RFID_LENGTH == bytesRead) {
      rfid[bytesRead] = '\0';
      byte cardId = determineCardId(rfid);
      if (MAX_CARDS != cardId) {
        return cardId;
      }
    }
    return -1;
  }

  // Ignore carriage returns and line feeds.
  if ((ASCII_CR == value) || (ASCII_LF == value)) {
    return -1;
  }

  bytesRead++;
  if (bytesRead > RFID_LENGTH) {
    started = 0;
    return -1;
  }
  rfid[bytesRead-1] = value;
  return -1;
}

byte determineCardId(char* uniqueHexName) {
  size_t nameLength = strlen(uniqueHexName);
  if (nameLength != RFID_LENGTH) {
    return MAX_CARDS;
  }
  
  byte uniqueId[RFID_BYTES];
  byte recordedChecksum = 0;
  byte calculatedChecksum = 0;

  for(byte i = 0; i <= RFID_BYTES; i++) {
    char byteStr[3] = {*uniqueHexName, *(uniqueHexName + sizeof(char)), '\0'};
    uniqueId[i] = (byte)strtoul(byteStr, NULL, 16);
    uniqueHexName += (2 * sizeof(char));
    calculatedChecksum = calculatedChecksum ^ uniqueId[i];
  }
  recordedChecksum = (byte)strtoul(uniqueHexName, NULL, 16);
  
  if (recordedChecksum != calculatedChecksum) {
    // checksum mismatch - so reject
    return MAX_CARDS;
  }
  
  return lookupCard(uniqueId);
}

byte lookupCard(byte uniqueId[]) {
  //TODO: Store unique names in EEPROM?
  static byte cards[RFID_BYTES * MAX_CARDS] = {0};
  static byte registeredCards = 0;
  
  for (byte cardNo = 0; cardNo < MAX_CARDS; cardNo++) {
    byte found = 1;
    for (byte byteNo = 0; byteNo < RFID_BYTES; byteNo++) {
      if (cards[cardNo * RFID_BYTES + byteNo] != uniqueId[byteNo]) {
        found = 0;
        break;
      }
    }
    if (1 == found) {
      return cardNo;
    }
  }
  
  if (registeredCards >= MAX_CARDS) {
    return MAX_CARDS;
  }

  byte startByte = registeredCards * RFID_BYTES;
  for (byte byteNo = 0; byteNo < RFID_BYTES; byteNo++) {
    cards[startByte + byteNo] = uniqueId[byteNo];
  }
  return registeredCards++;
}

void processCardArrival(byte cardId, unsigned long time) {
  Serial.print("Card arrival detected <");
  Serial.print(cardId, DEC);
  Serial.print("> at time <");
  Serial.print(time, DEC);
  Serial.println(">.");
  return;
}
