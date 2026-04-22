#ifndef PWM_SOFT_H_
#define PWM_SOFT_H_

#include <avr/io.h>

void pwm_soft_init(void);
void pwm_soft_set_duty(uint8_t duty);

#endif