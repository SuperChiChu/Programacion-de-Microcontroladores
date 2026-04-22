#ifndef PWM_SERVO_H_
#define PWM_SERVO_H_

#include <avr/io.h>
#include <stdint.h>

#ifndef F_CPU
#define F_CPU 16000000UL
#endif

#define PWM_SERVO_TOP_VALUE              39999U
#define PWM_SERVO_MIN_PULSE_US           600U //Limites menores
#define PWM_SERVO_CENTER_PULSE_US        1500U
#define PWM_SERVO_MAX_PULSE_US           2400U //Limites mayores

void pwm_servo_init(void);
void pwm_servo_set_dutyA(uint16_t dutyTicks);
void pwm_servo_set_dutyB(uint16_t dutyTicks);
void pwm_servo_set_pulseA(uint16_t pulseWidthUs);
void pwm_servo_set_pulseB(uint16_t pulseWidthUs);
uint16_t pwm_servo_map_adc_to_pulse(uint16_t adcValue);

void pwm_servo_set_duty(uint16_t duty);

#endif /* PWM_SERVO_H_ */