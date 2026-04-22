#ifndef PWM_SERVO2_H_
#define PWM_SERVO2_H_

#include <avr/io.h>
#include <stdint.h>

#define SERVO2_MIN_US 600 //Limite Menor en Micro Segundos
#define SERVO2_MAX_US 2400 //Limite Mayor en Micro Segundos

void pwm_servo2_init(void);
void pwm_servo2_set_pulse(uint16_t us);

#endif