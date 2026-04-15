/*
 * LacC4.c
 *
 * Created: 9 de Abril del 2026 
 * Author: Juan Daniel Sandoval Rodriguez
 * Description: Lab No.4
 */
/****************************************/
// Encabezado (Libraries) que lea el cpu en 32bits
#define F_CPU 16000000UL
#include <avr/io.h>
#include <util/delay.h>
#include <stdint.h>
#include <avr/interrupt.h>

/****************************************/
// Function prototypes
void setup(void);
void MOSTRAR_LEDS(uint8_t value);
uint8_t BOTON_INCREMENTO(void);
uint8_t BOTON_DECREMENTO(void);
void ACTUALIZAR_CONTADOR(void);

void adc_init(void);
uint16_t adc_read(void);
void display_init(void);
void timer1_init(void);
void update_display_value(uint8_t value);

uint8_t counter = 0;
volatile uint8_t current_display = 0;
volatile uint8_t display_buffer[2];

//Actualizar de 10 a 16
const uint8_t seg_code[16] = {
	0b01000000, // 0
	0b01111001, // 1
	0b00100100, // 2
	0b00110000, // 3
	0b00011001, // 4
	0b00010010, // 5
	0b00000010, // 6
	0b01111000, // 7
	0b0000000,  // 8
	0b00011000, // 9
    0b00001000, // A
    0b00000011, // b
    0b01000110, // C
    0b00100001, // d
    0b00000110, // E
    0b00001110  // F
    };

/****************************************/
// Main Function

int main(void)
{
    setup();
    
    uint8_t blink_state = 0;
    uint8_t blink_timer = 0;
    
    while (1)
    {
        ACTUALIZAR_CONTADOR();
        
        uint16_t adc_value = adc_read();
        uint8_t adc_byte = (adc_value >> 2); //Pasa de 0 a 1023 a solo 0 a 255
        update_display_value(adc_byte);
        
        if (adc_byte > counter)
        {
            if (blink_timer >= 20)
            {
                blink_timer = 0;
                blink_state = !blink_state;
            }
            if (blink_state)
                PORTD = 0xFF;
            else
                PORTD = 0x00;
            blink_timer++;
        }
        else
        {
            MOSTRAR_LEDS(counter);
            blink_state = 0;
            blink_timer = 0;
        }
        
        _delay_ms(5);
    }
}

/****************************************/
// NON-Interrupt subroutines
void setup(void)
{
    DDRD = 0xFF;
    PORTD = 0x00;
    
    DDRB &= ~((1 << PB0) | (1 << PB1));
    PORTB |= (1 << PB0) | (1 << PB1);
	
    adc_init();
    display_init();
    timer1_init();
    update_display_value(0);
}

void MOSTRAR_LEDS(uint8_t value)
{
    PORTD = value;
}

uint8_t BOTON_INCREMENTO(void)
{
    if (!(PINB & (1 << PB0))) //Leer pin del boton, solo d8
    {
        _delay_ms(20);
        if (!(PINB & (1 << PB0))) //Fue real o solo ruido
        {
            while (!(PINB & (1 << PB0)));
            _delay_ms(20);
            return 1;
        }
    }
    return 0;
}

uint8_t BOTON_DECREMENTO(void)
{
    if (!(PINB & (1 << PB1)))
    {
        _delay_ms(20);
        if (!(PINB & (1 << PB1)))
        {
            while (!(PINB & (1 << PB1)));
            _delay_ms(20);
            return 1;
        }
    }
    return 0;
}

void ACTUALIZAR_CONTADOR(void)
{
    if (BOTON_INCREMENTO())
    {
        counter++;
    }
    
    if (BOTON_DECREMENTO())
    {
        counter--;
    }
}

void adc_init(void)
{
	ADMUX = (1 << REFS0); //5V
	ADCSRA = (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0); //Preescaler 128
}

uint16_t adc_read(void)
{
	ADMUX = (ADMUX & 0xF0) | 0; //A0
	ADCSRA |= (1 << ADSC); //Compara A0 con Ref
	while (ADCSRA & (1 << ADSC));
	return ADC; //Regresa un valor 0 a 1023
}

void display_init(void)
{
	DDRB |= (1 << PB2) | (1 << PB3) | (1 << PB4) | (1 << PB5);
	DDRC |= (1 << PC1) | (1 << PC2) | (1 << PC3);
	DDRC |= (1 << PC4) | (1 << PC5);
	PORTB |= (1 << PB2) | (1 << PB3) | (1 << PB4) | (1 << PB5);
	PORTC |= (1 << PC1) | (1 << PC2) | (1 << PC3);
	PORTC |= (1 << PC4) | (1 << PC5);
}

void timer1_init(void)
{
	TCCR1A = 0;
	TCCR1B = (1 << WGM12) | (1 << CS11) | (1 << CS10);
	OCR1A = 499;
	TIMSK1 = (1 << OCIE1A);
	sei();
}

void update_display_value(uint8_t value)
{
	display_buffer[0] = value >> 4; //Decenas Hex del nibble alto
	display_buffer[1] = value & 0x0F; //Nibble bajo que serian unidades del hex
}

/****************************************/
// Interrupt routines
ISR(TIMER1_COMPA_vect)
{
	PORTC |= (1 << PC4) | (1 << PC5);
	uint8_t segments = seg_code[display_buffer[current_display]];
	PORTB = (PORTB & 0b11000011) | ((segments & 0x0F) << 2);
	PORTC = (PORTC & 0b11110001) | (((segments >> 4) & 0x07) << 1);
	if (current_display == 0)
	PORTC &= ~(1 << PC4);
	else
	PORTC &= ~(1 << PC5);
	current_display = !current_display;
}