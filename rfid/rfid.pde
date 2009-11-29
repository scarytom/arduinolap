/* RFID ID12
 */

const byte ASCII_STX = 0x02; // Start of text
const byte ASCII_ETX = 0x03; // End of text
const byte ASCII_CR  = 0x0D; // Carriage Return
const byte ASCII_LF  = 0x0A; // Line feed

const byte RFID_SIZE = 12;

void setup() {
  // connect to the serial port and flush it
  Serial.begin(9600);
}

void loop () {
  if (Serial.available() > 0) {
    processSerialData(Serial.read());
  }
}

void processSerialData(byte value) {
  static byte started = 0;
  static byte bytesRead = 0;
  static char rfid[RFID_SIZE+1] = "";
   
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
    if (bytesRead > 0) {
      rfid[bytesRead] = '\0';
      Serial.print("RFID: ");
      Serial.println(rfid);
    }
    return;
  }

  // Ignore carriage returns and line feeds.
  if ((ASCII_CR == value) || (ASCII_LF == value)) {
    return;
  }

  bytesRead++;
  if (bytesRead > RFID_SIZE) {
    started = 0;
    return;
  }
  rfid[bytesRead-1] = value;
}

