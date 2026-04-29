/*
 * LabC6.c
 *
 * Created: 23/04/2026 13:29:24
 * Author : Juan Daniel Sandoval
 */ 
#define F_CPU 16000000UL
#include <avr/io.h>
#include <util/delay.h>
#include <stdlib.h>

// --------------- UART Init ---------------
void UART_Init(void) {
	// Baud rate 9600 @ 16MHz Å® UBRR = 103
	UBRR0H = 0;
	UBRR0L = 103;

	// Habilitar TX y RX
	UCSR0B = (1 << TXEN0) | (1 << RXEN0);

	// Formato: 8 bits de datos, 1 stop bit, no paridad
	UCSR0C = (1 << UCSZ01) | (1 << UCSZ00);
}

void ADC_Init(void)
{
	ADMUX = (1 << REFS0);
	ADCSRA = (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0);
}

uint16_t ADC_Read(uint8_t channel)
{
	ADMUX = (ADMUX & 0xF0) | (channel & 0x0F);
	ADCSRA |= (1 << ADSC);
	while (ADCSRA & (1 << ADSC));
	return ADC;
}

void UART_SendNumber(uint16_t num)
{
	char buffer[10];
	itoa(num, buffer, 10);
	cadena(buffer);
}

// --------------- Transmitir 1 byte ---------------
void UART_SendChar(char c) {
	// Esperar a que el buffer de TX este libre
	while (!(UCSR0A & (1 << UDRE0)));
	UDR0 = c;
}

// --------------- Transmitir string ---------------
void UART_SendString(const char *str) {
	while (*str) {
		UART_SendChar(*str++);
	}
}

void cadena(char txt[])
{
	while (*txt)
	{
		UART_SendChar(*txt++);
	}
}

// --------------- Recibir 1 byte ---------------
uint8_t UART_Receive(void) {
	// Esperar a que llegue un dato
	while (!(UCSR0A & (1 << RXC0)));
	return UDR0;
}

// ==================== MAIN ====================
int main(void) {
	// Puerto B
	DDRB = 0xFF;
	PORTB = 0x00;

	UART_Init();
	ADC_Init();

	//Enviar mensaje al resetear
	_delay_ms(100); //delay
	cadena("Hello World, Juan Daniel Sandoval\r\n");

	//Loop recibir caracter y mostrarlo en Puerto B
	while (1)
	{
		cadena("\r\n===== MENU =====\r\n");
		cadena("1. Leer Potenciometro\r\n");
		cadena("2. Enviar ASCII\r\n");
		cadena("Seleccione opcion: ");

		char opcion = UART_Receive();
		UART_SendChar(opcion); // eco visual
		cadena("\r\n");

		if (opcion == '1')
		{
			uint16_t valor = ADC_Read(0);

			cadena("Valor del Potenciometro: ");
			UART_SendNumber(valor);
			cadena("\r\n");
		}

		else if (opcion == '2')
		{
			cadena("Ingrese un caracter: ");
			char dato = UART_Receive();
			UART_SendChar(dato);
			cadena("\r\n");

			PORTB = dato;
		}

		_delay_ms(1000);
	}
}