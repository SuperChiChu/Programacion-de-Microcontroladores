/*
 * Proyecto2Micros.c
 *
 * Created: 30 de Abril del 2026
 * Author: Juan Daniel Sandoval Rodriguez
 * Description: Proyecto 2, Funcionalidad de 4 Servos
 */

/****************************************/
// Encabezado (Libraries)

#define F_CPU 16000000UL

#include <avr/io.h>
#include <avr/interrupt.h>
#include <util/delay.h>
#include <stdint.h>
#include <stdlib.h>
#include <avr/eeprom.h>

#include "servo_t1.h"
#include "servo_t2.h"

/****************************************/
// Modos

#define MODO_MANUAL  0
#define MODO_EEPROM  1
#define MODO_UART    2

/****************************************/
// Variables Globales

volatile uint8_t modo_actual = MODO_MANUAL;

uint16_t servoPulse[4] =
{
	3000,
	3000,
	3000,
	3000
};

uint16_t EEMEM memoria1[4];
uint16_t EEMEM memoria2[4];
uint16_t EEMEM memoria3[4];
uint16_t EEMEM memoria4[4];

/****************************************/
// Function prototypes

void adc_init(void);
uint16_t adc_read(uint8_t channel);

void uart_init(void);
void uart_tx(char data);
void uart_print(char *str);
char uart_rx(void);
char uart_read_command(void);
uint16_t uart_read_number(void);

void rgb_init(void);
void update_rgb(void);

void uart_menu(void);

uint16_t map_adc_to_pulse(uint16_t adc);
void mover_servos_actuales(void);

void guardar_memoria(uint8_t slot);
void cargar_memoria(uint8_t slot);

/****************************************/
// Main Function

int main(void)
{
	adc_init();

	servo_t1_init();
	servo_t2_init();

	uart_init();

	rgb_init();

	sei();

	update_rgb();

	uart_print("\r\n");
	uart_print("Sistema Iniciado\r\n");

	uart_menu();

	while (1)
	{
		uint16_t adc0;
		uint16_t adc1;
		uint16_t adc2;
		uint16_t adc3;

		/****************************************/
		// UART Commands

		if(UCSR0A & (1 << RXC0))
		{
			char cmd;

			cmd = uart_read_command();

			/****************************************/
			// Cambio de modo

			if(cmd == '0')
			{
				modo_actual = MODO_MANUAL;
				update_rgb();
				uart_menu();
			}

			else if(cmd == '1')
			{
				modo_actual = MODO_EEPROM;
				update_rgb();
				uart_menu();
			}

			else if(cmd == '2')
			{
				modo_actual = MODO_UART;
				update_rgb();
				uart_menu();
			}

			/****************************************/
			// Modo UART: mover servos desde consola

			else if(modo_actual == MODO_UART)
			{
				uint16_t valor;

				if(cmd == 'A')
				{
					uart_print("\r\nIngrese valor Servo 1:\r\n");
					valor = uart_read_number();

					servoPulse[0] = valor;
					servo1_set(servoPulse[0]);

					uart_print("\r\nServo 1 Actualizado\r\n");
				}

				else if(cmd == 'B')
				{
					uart_print("\r\nIngrese valor Servo 2:\r\n");
					valor = uart_read_number();

					servoPulse[1] = valor;
					servo2_set(servoPulse[1]);

					uart_print("\r\nServo 2 Actualizado\r\n");
				}

				else if(cmd == 'C')
				{
					uart_print("\r\nIngrese valor Servo 3:\r\n");
					valor = uart_read_number();

					servoPulse[2] = valor;
					servo3_set(servoPulse[2]);

					uart_print("\r\nServo 3 Actualizado\r\n");
				}

				else if(cmd == 'D')
				{
					uart_print("\r\nIngrese valor Servo 4:\r\n");
					valor = uart_read_number();

					servoPulse[3] = valor;
					servo4_set(servoPulse[3]);

					uart_print("\r\nServo 4 Actualizado\r\n");
				}

				else
				{
					uart_print("\r\nComando UART no valido\r\n");
				}
			}

			/****************************************/
			// Modo EEPROM: guardar/cargar memorias

			else if(modo_actual == MODO_EEPROM)
			{
				char slot;

				if(cmd == 'G')
				{
					uart_print("\r\nSeleccione memoria para guardar 1-4:\r\n");

					slot = uart_read_command();

					guardar_memoria(slot - '0');

					uart_print("\r\nMemoria Guardada\r\n");
				}

				else if(cmd == 'C')
				{
					uart_print("\r\nSeleccione memoria para cargar 1-4:\r\n");

					slot = uart_read_command();

					cargar_memoria(slot - '0');

					uart_print("\r\nMemoria Cargada\r\n");
				}

				else
				{
					uart_print("\r\nComando EEPROM no valido\r\n");
				}
			}
		}

		/****************************************/
		// Modo Manual

		if(modo_actual == MODO_MANUAL)
		{
			adc0 = adc_read(0);
			adc1 = adc_read(1);
			adc2 = adc_read(2);
			adc3 = adc_read(3);

			servoPulse[0] = map_adc_to_pulse(adc0);
			servoPulse[1] = map_adc_to_pulse(adc1);
			servoPulse[2] = map_adc_to_pulse(adc2);
			servoPulse[3] = map_adc_to_pulse(adc3);

			mover_servos_actuales();
		}

		_delay_ms(20);
	}
}

/****************************************/
// NON-Interrupt subroutines

void adc_init(void)
{
	ADMUX = (1 << REFS0);

	ADCSRA = (1 << ADEN) |
	(1 << ADPS2) |
	(1 << ADPS1) |
	(1 << ADPS0);

	DIDR0 = 0x0F;
}

uint16_t adc_read(uint8_t channel)
{
	ADMUX = (ADMUX & 0xF0) |
	(channel & 0x0F);

	ADCSRA |= (1 << ADSC);

	while (ADCSRA & (1 << ADSC));

	return ADC;
}

/****************************************/
// UART

void uart_init(void)
{
	// 9600 baud @ 16MHz
	UBRR0H = 0;
	UBRR0L = 103;

	// Habilitar TX y RX
	UCSR0B = (1 << RXEN0) |
	(1 << TXEN0);

	// 8 bits, 1 stop, sin paridad
	UCSR0C = (1 << UCSZ01) |
	(1 << UCSZ00);
}

void uart_tx(char data)
{
	while(!(UCSR0A & (1 << UDRE0)));

	UDR0 = data;
}

void uart_print(char *str)
{
	while(*str)
	{
		uart_tx(*str);
		str++;
	}
}

char uart_rx(void)
{
	while(!(UCSR0A & (1 << RXC0)));

	return UDR0;
}

char uart_read_command(void)
{
	char c;

	do
	{
		c = uart_rx();
	}
	while(c == '\r' || c == '\n');

	return c;
}

uint16_t uart_read_number(void)
{
	char buffer[6];
	uint8_t i = 0;
	char c;

	while(1)
	{
		c = uart_rx();

		if(c == '\r' || c == '\n')
		{
			break;
		}

		if(i < 5)
		{
			buffer[i] = c;
			uart_tx(c);
			i++;
		}
	}

	buffer[i] = '\0';

	return (uint16_t)atoi(buffer);
}

/****************************************/
// RGB

void rgb_init(void)
{
	// D5 D6 D7 outputs
	DDRD |= (1 << DDD5) |
	(1 << DDD6) |
	(1 << DDD7);

	// OFF todo, anodo comun
	PORTD |= (1 << PORTD5) |
	(1 << PORTD6) |
	(1 << PORTD7);
}

void update_rgb(void)
{
	// OFF todo
	PORTD |= (1 << PORTD5) |
	(1 << PORTD6) |
	(1 << PORTD7);

	switch(modo_actual)
	{
		case MODO_MANUAL:

		// Verde
		PORTD &= ~(1 << PORTD6);

		break;

		case MODO_EEPROM:

		// Azul
		PORTD &= ~(1 << PORTD7);

		break;

		case MODO_UART:

		// Rojo
		PORTD &= ~(1 << PORTD5);

		break;
	}
}

/****************************************/
// UART Menu

void uart_menu(void)
{
	uart_print("\r\n");
	uart_print("====================\r\n");
	uart_print(" PROYECTO GARRA\r\n");
	uart_print("====================\r\n");

	uart_print("0 -> Manual\r\n");
	uart_print("1 -> EEPROM\r\n");
	uart_print("2 -> UART\r\n");

	uart_print("\r\n");

	switch(modo_actual)
	{
		case MODO_MANUAL:

		uart_print("Modo Actual: MANUAL\r\n");
		uart_print("Potenciometros controlan los servos\r\n");

		break;

		case MODO_EEPROM:

		uart_print("Modo Actual: EEPROM\r\n");
		uart_print("G -> Guardar memoria\r\n");
		uart_print("C -> Cargar memoria\r\n");

		break;

		case MODO_UART:

		uart_print("Modo Actual: UART\r\n");
		uart_print("A -> Servo 1\r\n");
		uart_print("B -> Servo 2\r\n");
		uart_print("C -> Servo 3\r\n");
		uart_print("D -> Servo 4\r\n");

		break;
	}

	uart_print("\r\n");
}

/****************************************/
// Servo helpers

uint16_t map_adc_to_pulse(uint16_t adc)
{
	if(adc > 1023)
	{
		adc = 1023;
	}

	return SERVO_MIN + (uint16_t)(((uint32_t)adc * (SERVO_MAX - SERVO_MIN)) / 1023);
}

void mover_servos_actuales(void)
{
	servo1_set(servoPulse[0]);
	servo2_set(servoPulse[1]);
	servo3_set(servoPulse[2]);
	servo4_set(servoPulse[3]);
}

/****************************************/
// EEPROM

void guardar_memoria(uint8_t slot)
{
	switch(slot)
	{
		case 1:

		eeprom_update_block((const void*)servoPulse,
		(void*)memoria1,
		sizeof(servoPulse));

		break;

		case 2:

		eeprom_update_block((const void*)servoPulse,
		(void*)memoria2,
		sizeof(servoPulse));

		break;

		case 3:

		eeprom_update_block((const void*)servoPulse,
		(void*)memoria3,
		sizeof(servoPulse));

		break;

		case 4:

		eeprom_update_block((const void*)servoPulse,
		(void*)memoria4,
		sizeof(servoPulse));

		break;

		default:

		uart_print("\r\nMemoria no valida\r\n");

		break;
	}
}

void cargar_memoria(uint8_t slot)
{
	switch(slot)
	{
		case 1:

		eeprom_read_block((void*)servoPulse,
		(const void*)memoria1,
		sizeof(servoPulse));

		break;

		case 2:

		eeprom_read_block((void*)servoPulse,
		(const void*)memoria2,
		sizeof(servoPulse));

		break;

		case 3:

		eeprom_read_block((void*)servoPulse,
		(const void*)memoria3,
		sizeof(servoPulse));

		break;

		case 4:

		eeprom_read_block((void*)servoPulse,
		(const void*)memoria4,
		sizeof(servoPulse));

		break;

		default:

		uart_print("\r\nMemoria no valida\r\n");

		return;
	}

	mover_servos_actuales();
}

/****************************************/
// Interrupt routines