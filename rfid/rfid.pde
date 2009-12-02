/* 
 * RFID Lap timer.
 * (c) Tom Denley 2009
 */

const byte ASCII_STX = 0x02; // Start of text
const byte ASCII_ETX = 0x03; // End of text
const byte ASCII_CR  = 0x0D; // Carriage Return
const byte ASCII_LF  = 0x0A; // Line feed

const int  PIN_LED_WARNING = 8;
const int  PIN_LED_STOP = 7;
const int  PIN_DISPLAY_DATA = 2;
const int  PIN_DISPLAY_CLOCK = 3;


// Size of an RFID number in bytes.
const size_t RFID_BYTES = 5;

// Size of character array of ASCII string representation of an RFID with 1 byte checksum.
const size_t RFID_LENGTH = (RFID_BYTES + 1) * 2;

// Maximum number of cards that the system can track.
const size_t MAX_CARDS = 2;

// Target number of laps for a session.
const size_t TARGET_LAP_COUNT = 5;

// Minimum length of time in milliseconds that a lap can realistically be completed in.
const unsigned int MIN_LAP_TIME_MILLIS = 3000;



void setup() {
  Serial.begin(9600);
  pinMode(PIN_LED_WARNING, OUTPUT);
  pinMode(PIN_LED_STOP, OUTPUT);
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

void processCardArrival(byte cardId, unsigned long timeMillis) {
  static unsigned long lastTimesMillis[MAX_CARDS] = {0L};
  static byte lapCounts[MAX_CARDS] = {0};
  static unsigned long aveTimesMillis[MAX_CARDS] = {0L};
  static unsigned int lapTimesTenths[MAX_CARDS][TARGET_LAP_COUNT];

  /* DEBUG
  Serial.print("Card arrival detected <");
  Serial.print(cardId, DEC);
  Serial.print("> at time <");
  Serial.print(time, DEC);
  Serial.println(">.");
  */
  
  // Clear previous arrival's status.
  digitalWrite(PIN_LED_WARNING, LOW);
  digitalWrite(PIN_LED_STOP, LOW);

  // Update the recorded last-seen time.
  unsigned long lastTimeMillis = lastTimesMillis[cardId];  
  lastTimesMillis[cardId] = timeMillis;

  // No previous time, therefore starting first lap.
  if (0L == lastTimeMillis) {
    displayLapNumber(0);
    return;
  }
  
  // Calculate the lap time
  unsigned long lapTimeMillis = (timeMillis - lastTimeMillis);
  if (lapTimeMillis < MIN_LAP_TIME_MILLIS) {
    digitalWrite(PIN_LED_WARNING, HIGH);
    return;
  }

  // Calculate number of laps (to account for any mis-registered laps).
  byte lapCount = 1;
  if (lapTimeMillis > (2 * (long)MIN_LAP_TIME_MILLIS)) {
    unsigned long averageTimeMillis = aveTimesMillis[cardId];
    if (0L == averageTimeMillis) {
      averageTimeMillis = MIN_LAP_TIME_MILLIS;
    }
    lapCount = (lapTimeMillis + (averageTimeMillis / 2)) / averageTimeMillis;
  }

  // Calculate and record the new average lap time
  aveTimesMillis[cardId] = ((aveTimesMillis[cardId] * lapCounts[cardId]) + lapTimeMillis)
                           / (lapCounts[cardId] + lapCount);

  // Record the new lap times.
  for (byte lapNo = lapCounts[cardId]; lapNo < lapCounts[cardId] + lapCount; lapNo++) {
    lapTimesTenths[cardId][lapNo] = (lapTimeMillis / lapCount) / 100;
  }

  // Record and display the new lap count.
  lapCounts[cardId] += lapCount;
  displayLapNumber(lapCounts[cardId]);
  //indicateGoodLap();

  // If lap target has been reached, show the stop sign.
  if (lapCounts[cardId] >= TARGET_LAP_COUNT) {
    digitalWrite(PIN_LED_STOP, HIGH);
    return;
  }
  
  return;
}

void displayLapNumber(byte lapNumber) {
  static const byte displaycodes[] = {0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F};
  
  if (lapNumber > 99) {
    return;
  }
  
  byte rightDigit = lapNumber % 10;
  byte leftDigit = (lapNumber - rightDigit) / 10;
  
  shiftOut(PIN_DISPLAY_DATA, PIN_DISPLAY_CLOCK, MSBFIRST, displayCodes[leftDigit]);
  shiftOut(PIN_DISPLAY_DATA, PIN_DISPLAY_CLOCK, MSBFIRST, displayCodes[rightDigit]);
  
  return;
}

