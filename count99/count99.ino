/* 
 * Use a 74HC595 Shift Register to count from 0 to 99
 * on a dual digit display.
 *
 * (c) Tom Denley 2009
 */

const int  PIN_DISPLAY_LATCH = 8;
const int  PIN_DISPLAY_DATA = 11;
const int  PIN_DISPLAY_CLOCK = 12;

void setup() {
  pinMode(PIN_DISPLAY_DATA, OUTPUT);
  pinMode(PIN_DISPLAY_LATCH, OUTPUT);
  pinMode(PIN_DISPLAY_CLOCK, OUTPUT);
}

void loop() {
  //count up routine
  for (byte j = 0; j <= 99; j=j+11) {
    displayLapNumber(j);
    delay(1000);
  }
}

void displayLapNumber(byte lapNumber) {
  static const byte displayCodes[] = {0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F};
  
  if (lapNumber > 99) {
    return;
  }
  
  byte rightDigit = lapNumber % 10;
  byte leftDigit = (lapNumber - rightDigit) / 10;
  
  digitalWrite(PIN_DISPLAY_LATCH, LOW);
  shiftOut(PIN_DISPLAY_DATA, PIN_DISPLAY_CLOCK, MSBFIRST, displayCodes[rightDigit]);
  shiftOut(PIN_DISPLAY_DATA, PIN_DISPLAY_CLOCK, MSBFIRST, displayCodes[leftDigit]);
  digitalWrite(PIN_DISPLAY_LATCH, HIGH);
  return;
}
