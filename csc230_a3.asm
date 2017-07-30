; csc230_a3.asm
; CSC 230 - Summer 2017
;
; Matthew McKay - 07/16/2017
; V00900866
;
; B. Bird - 06/29/2017

.equ SPH_DATASPACE = 0x5E
.equ SPL_DATASPACE = 0x5D

.equ STACK_INIT = 0x21FF

; No data address definitions are needed since we use the "m2560def.inc" file

.include "m2560def.inc"

.include "lcd_function_defs.inc"

; Definitions for button values from the ADC
; Some boards may use the values in option B
; The code below used less than comparisons so option A should work for both
; Option A (v 1.1)
;.equ ADC_BTN_RIGHT = 0x032
;.equ ADC_BTN_UP = 0x0FA
;.equ ADC_BTN_DOWN = 0x1C2
;.equ ADC_BTN_LEFT = 0x28A
;.equ ADC_BTN_SELECT = 0x352
; Option B (v 1.0)
.equ ADC_BTN_RIGHT = 0x032
.equ ADC_BTN_UP = 0x0C3
.equ ADC_BTN_DOWN = 0x17C
.equ ADC_BTN_LEFT = 0x22B
.equ ADC_BTN_SELECT = 0x316

.equ counter_value = 0x11000
.def D0 = r20
.def D1 = r21
.def D2 = r22
.def D3 = r23
.equ CV0 = low(counter_value-1)
.equ CV1 = byte2(counter_value-1)
.equ CV2 = byte3(counter_value-1)
.equ CV3 = byte4(counter_value-1)

.cseg
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                          Reset/Interrupt Vectors                            ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.org 0x0000 ; RESET vector
	jmp main_begin

.org 0x002e	; Timer overflow interrupt handler
	jmp timer_interrupt
; Add interrupt handlers for timer interrupts here. See Section 14 (page 101) of the datasheet for addresses.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                               Main Program                                  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; According to the datasheet, the last interrupt vector has address 0x0070, so the first
; "unreserved" location is 0x0072
.org 0x0074
main_begin:

	; Initialize the stack
	; Notice that we use "SPH_DATASPACE" instead of just "SPH" for our .def
	; since m2560def.inc defines a different value for SPH which is not compatible
	; with STS.
	ldi r16, high(STACK_INIT)
	sts SPH_DATASPACE, r16
	ldi r16, low(STACK_INIT)
	sts SPL_DATASPACE, r16
	; Initialize carry variable to 25
	ldi r16, 0x19
	sts carry_var, r16
	; Set start flag to zero
	ldi r16, 0x00
	sts increment, r16
	sts timer_on_flag, r16
	; Set overflow counter to 0
	sts overflows, r16
	sts overflows1, r16
	; Initialize the Timer
	call timer_init
	; Initialize the LCD
	call lcd_init
	; Initialize the ADC
	call adc_init
	; Clear Time
	call clear_time
	; Clear Line two
	call clear_line_two
	;call clear_lap
	call LED_display
	
	
main_loop:
	
	; Display LED
	;call LED_display
	;call LED_display
	start_adc:
		lds	r16, ADCSRA
		ori	r16, 0x40
		sts	ADCSRA, r16
	wait_for_adc:
		lds	r16, ADCSRA
		andi r16, 0x40
		brne wait_for_adc

	lds	ZL, ADCL
	lds	ZH, ADCH
	cp_right:
		ldi r16, low(ADC_BTN_RIGHT)
		ldi r17, high(ADC_BTN_RIGHT)
		cp ZL, r16
		cpc ZH, r17
		brlo main_loop
		call DELAY_FUNCTION	
		call DELAY_FUNCTION	
		call DELAY_FUNCTION	
	cp_up:
		ldi r16, low(ADC_BTN_UP)
		ldi r17, high(ADC_BTN_UP)
		cp ZL, r16
		cpc ZH, r17
		brlo set_lap_init
		call DELAY_FUNCTION	
		call DELAY_FUNCTION			
		call DELAY_FUNCTION	
	cp_down:
		ldi r16, low(ADC_BTN_DOWN)
		ldi r17, high(ADC_BTN_DOWN)
		cp ZL, r16
		cpc ZH, r17
		brlo clear_lap_init		
	cp_left:
		ldi r16, low(ADC_BTN_LEFT)
		ldi r17, high(ADC_BTN_LEFT)
		cp ZL, r16
		cpc ZH, r17
		brlo clear_time_init 
	cp_select:
		ldi r16, low(ADC_BTN_SELECT)
		ldi r17, high(ADC_BTN_SELECT)
		cp ZL, r16
		cpc ZH, r17
		brlo start_stop_init
	delay:
	call DELAY_FUNCTION
	call DELAY_FUNCTION
	call DELAY_FUNCTION	
	call DELAY_FUNCTION
	jmp main_loop
	
	set_lap_init:
		call set_lap
		rjmp delay
	clear_lap_init:
		call clear_lap
		rjmp delay
	clear_time_init:
		call clear_time
		rjmp delay
	start_stop_init:
		call start_stop
		rjmp delay
	
	
	start_stop:
		push r16
		lds r16, timer_on_flag
		cpi r16, 1
		breq stop
		start:
			ldi r16, 0x01
			sts timer_on_flag, r16
			sts TIMSK0, r16	
			rjmp start_stop_done
		stop:
			ldi r16, 0x00
			sts timer_on_flag, r16
			sts TIMSK0, r16	
		start_stop_done:
		pop r16
		ret
DELAY_FUNCTION:
	; We need to use r0, r16 and r20-23 (D0-D3)
	; Since these registers might contain data that the caller
	; wants to preserve, we will save their current values to memory
	; and load them when the function ends.
	; We use the push instruction to push each value onto the stack
	; and then pop them at the end of the function. Remember to pop
	; values in reverse order from the push ordering.
	push r0
	push r16
	push r20
	push r21
	push r22
	push r23
	
	
	; This "function" assumes that the return address (to jump
	; to when the function ends) has been stored in R31:R30 = Z
	; Load the counter_value into D3:D0
	ldi	D0, CV0
	ldi D1, CV1
	ldi D2, CV2
	ldi D3, CV3
delay_loop:
	; Subtract 1 from the counter
	ldi r16, 1
	clr r0
	sub D0, r16
	sbc D1, r0
	sbc D2, r0
	sbc D3, r0
	; If the C flag is not set, the value D3:D0
	; hasn't wrapped around yet.
	brcc delay_loop
	
	; Reload the saved values of registers r0, r16, r20-r23
	pop r23
	pop r22
	pop r21
	pop r20
	pop r16
	pop r0
	
	; Now, use the RET instruction to return
	; RET pops the stack twice to obtain the 16-bit
	; return address, then jumps to that address.
	ret	
	clear_lap:
		push r16
		ldi r16, 0x00
		sts LAST_LAP_START_TEN, r16
		sts LAST_LAP_START_SEC_H, r16
		sts LAST_LAP_START_SEC_L, r16
		sts LAST_LAP_START_MIN_H, r16
		sts LAST_LAP_START_MIN_L, r16
		sts LAST_LAP_END_TEN, r16
		sts LAST_LAP_END_SEC_H, r16
		sts LAST_LAP_END_SEC_H, r16
		sts LAST_LAP_END_MIN_H, r16
		sts LAST_LAP_END_MIN_L, r16
		sts lap_timer_flag, r16
		call clear_line_two
		;call display_line2
		;call LED_display
		pop r16
		ret 
		
	set_lap:
		push r16
		lds r16, LAST_LAP_START_TEN
		sts LAST_LAP_END_TEN, r16
		lds r16, LAST_LAP_START_SEC_H
		sts LAST_LAP_END_SEC_H, r16
		lds r16, LAST_LAP_START_SEC_L
		sts LAST_LAP_END_SEC_L, r16
		lds r16, LAST_LAP_START_MIN_H
		sts LAST_LAP_END_MIN_H, r16
		lds r16, LAST_LAP_START_MIN_L
		sts LAST_LAP_END_MIN_L, r16
		
		lds r16, CURRENT_LAP_TEN
		sts LAST_LAP_START_TEN, r16
		lds r16, CURRENT_LAP_SEC_H
		sts LAST_LAP_START_SEC_H, r16
		lds r16, CURRENT_LAP_SEC_L
		sts LAST_LAP_START_SEC_L, r16
		lds r16, CURRENT_LAP_MIN_H
		sts LAST_LAP_START_MIN_H, r16
		lds r16, CURRENT_LAP_MIN_L
		sts LAST_LAP_START_MIN_L, r16
		
		ldi r16, 0x1
		sts lap_timer_flag, r16
		;call LED_display
		pop r16
		ret
	
	clear_time:
		push r16
		clr r16
		sts TIMSK0, r16
		clr r16
		sts CURRENT_LAP_TEN, r16
		sts CURRENT_LAP_SEC_H, r16
		sts CURRENT_LAP_SEC_L, r16
		sts CURRENT_LAP_MIN_H, r16
		sts CURRENT_LAP_MIN_L, r16
		sts LAST_LAP_START_TEN, r16
		sts LAST_LAP_START_SEC_H, r16
		sts LAST_LAP_START_SEC_L, r16
		sts LAST_LAP_START_MIN_H, r16
		sts LAST_LAP_START_MIN_L, r16
		sts LAST_LAP_END_TEN, r16
		sts LAST_LAP_END_SEC_H, r16
		sts LAST_LAP_END_SEC_H, r16
		sts LAST_LAP_END_MIN_H, r16
		sts LAST_LAP_END_MIN_L, r16
		sts lap_timer_flag, r16
		call LED_display
		pop r16
		ret

	adc_init:
		push r16
		; Set up the ADC
		; Set up ADCSRA (ADEN = 1, ADPS2:ADPS0 = 111 for divisor of 128)
		ldi	r16, 0x87
		sts	ADCSRA, r16
		; Set up ADMUX (MUX4:MUX0 = 00000, ADLAR = 0, REFS1:REFS0 = 1)
		ldi	r16, 0x40
		sts	ADMUX, r16
		pop r16
		ret

	timer_init:
		push r16
		clr r16
		ldi r16,  0x04
		out TCCR0B, r16 
		ldi r16, 0x00
		sts TIMSK0, r16 
		clr r16
		out TCNT0, r16      
		ldi r16, 0x01
		out TIFR0, r16
		pop r16
		ret

  timer_interrupt:
		push r16
		push r17
		push r18
		push r19 ; temp carry
		push r20
		;call LED_display
		clr r18

		; Load carry and overflow var from dataspace
		ldi r16, 0xF9
		
		lds r17, overflows
		inc r17
		sts overflows, r17
		cp r16, r17
		brlo done_timer_inc
		
		clr r19
		sts overflows, r19	
		
		lds r17, overflows1
		inc r17
		sts overflows1, r17
		cpi r17, 0x21
		brlo done_timer_inc
		
		clr r19
		sts overflows1, r19
		sts TCNT0, r19
		
		call increment_timer
		call LED_display
		done_timer_inc:
		pop r20
		pop r19
		pop r18
		pop r17
		pop r16
		reti
	increment_timer:
		; Increment timer
		lds r19, CURRENT_LAP_TEN
		inc r19
		cpi r19, 0x0a
		sts CURRENT_LAP_TEN, r19
		breq PC + 2
		ret
		; If tenth-seconds = 10 inc seconds low
		clr r19
		sts CURRENT_LAP_TEN, r19
		; Current lap sec low
		lds r19, CURRENT_LAP_SEC_L
		inc r19
		cpi r19, 0x0a
		sts CURRENT_LAP_SEC_L, r19
		breq PC + 2
		ret
		; If seconds low = 10 inc seconds high
		clr r19
		sts CURRENT_LAP_SEC_L, r19
		; Current lap sec high
		lds r19, CURRENT_LAP_SEC_H
		inc r19
		cpi r19, 0x06
		sts CURRENT_LAP_SEC_H, r19
		breq PC + 2
		ret
		; If seconds high = 6 inc min low
		clr r19
		sts CURRENT_LAP_SEC_H, r19
		; Current lap min low
		lds r19, CURRENT_LAP_MIN_L
		inc r19
		cpi r19, 0x0a
		sts CURRENT_LAP_MIN_L, r19
		breq PC + 2
		ret
		; If min low = 10 inc min low
		clr r19
		sts CURRENT_LAP_MIN_L, r19
		; Current lap min low
		lds r19, CURRENT_LAP_MIN_H
		inc r19
		cpi r19, 0x0a
		sts CURRENT_LAP_MIN_H, r19
		breq PC + 2
		ret
		; If min high = 6 inc min low
		clr r19
		sts CURRENT_LAP_MIN_H, r19
		ret
		
	clear_line_two:
		push r21
		push r23
		
		clr r21
		ldi r23, ' '
		ldi YL, low(LINE_TWO)
		ldi YH, high(LINE_TWO)
		loop:
			st Y+, r23 
			inc r21
			cpi r21, 0x16
		brne loop
		
		ldi r23, 0
		st Y+, r23
		
		pop r23
		pop r21
		ret
		
	LED_display:
		push r16
		push r17
		push YL
		push YH
		ldi r17, 48
		; Load the base address of the LINE_ONE array
		line1:
		ldi YL, low(LINE_ONE)
		ldi YH, high(LINE_ONE)
		; Manually set the string to contain the text "Time: HH:MM.S"
		ldi r16, 'T'
		st Y+, r16
		ldi r16, 'i'
		st Y+, r16
		ldi r16, 'm'
		st Y+, r16
		ldi r16, 'e'
		st Y+, r16
		ldi r16, ':'
		st Y+, r16
		ldi r16, ' '
		st Y+, r16
		ldi r16, ' '
		st Y+, r16
		lds r16, CURRENT_LAP_MIN_H
		add r16, r17
		st Y+, r16
		lds r16, CURRENT_LAP_MIN_L
		add r16, r17
		st Y+, r16
		ldi r16, ':'
		st Y+, r16
		lds r16, CURRENT_LAP_SEC_H
		add r16, r17
		st Y+, r16
		lds r16, CURRENT_LAP_SEC_L
		add r16, r17
		st Y+, r16
		ldi r16, '.'
		st Y+, r16
		lds r16, CURRENT_LAP_TEN
		add r16, r17
		st Y+, r16
		; Null terminator
		ldi r16, 0
		st Y+, r16

		; Set up the LCD to display starting on row 0, column 0
		ldi r16, 0 ; Row number
		push r16
		ldi r16, 0 ; Column number
		push r16
		call lcd_gotoxy
		pop r16
		pop r16
		
		; Display the string on line 1
		ldi r16, high(LINE_ONE)
		push r16
		ldi r16, low(LINE_ONE)
		push r16
		call lcd_puts
		pop r16
		pop r16

		; Check the timer lap flag
		lds r16, lap_timer_flag
		cpi r16, 0
		breq skip2
		; If timer flag is off then set the fist byte as a NULL Terminator
		;ldi r16, 0
		;st Y+, r16
		ldi YL, low(LINE_TWO)
		ldi YH, high(LINE_TWO)
		
		line2:
		ldi r17, 48
		; Manually set the string to contain the text "HH:MM.S   HH:MM.S"
		lds r16, LAST_LAP_END_MIN_H
		add r16, r17
		st Y+, r16
		lds r16, LAST_LAP_END_MIN_L
		add r16, r17
		st Y+, r16
		ldi r16, ':'
		st Y+, r16
		lds r16, LAST_LAP_END_SEC_H
		add r16, r17
		st Y+, r16
		lds r16, LAST_LAP_END_SEC_L
		add r16, r17
		st Y+, r16
		ldi r16, '.'
		st Y+, r16
		lds r16, LAST_LAP_END_TEN
		add r16, r17
		st Y+, r16
		
		; Two byte space
		ldi r16, ' '
		st Y+, r16
		ldi r16, ' '
		st Y+, r16

		lds r16, LAST_LAP_START_MIN_H
		add r16, r17
		st Y+, r16
		lds r16, LAST_LAP_START_MIN_L
		add r16, r17
		st Y+, r16
		ldi r16, ':'
		st Y+, r16
		lds r16, LAST_LAP_START_SEC_H
		add r16, r17
		st Y+, r16
		lds r16, LAST_LAP_START_SEC_L
		add r16, r17
		st Y+, r16
		ldi r16, '.'
		st Y+, r16
		lds r16, LAST_LAP_START_TEN
		add r16, r17
		st Y+, r16
		;LED_done:
		
		; Null terminator
		ldi r16, 0
		st Y+, r16
		
		
		
		skip2:
		
		call display_line2
		;call clear_line_two	
		

		LED_done:
		
		pop YH
		pop YL
		pop r17
		pop r16
		ret
		
	display_line2:
	; Set up the LCD to display starting on row 0, column 0
		push r16
		
		; Set up the LCD to display starting on row 0, column 0
		ldi r16, 1 ; Row number
		push r16
		ldi r16, 0 ; Column number
		push r16
		call lcd_gotoxy
		pop r16
		pop r16
		
		; Display the string on line 1
		ldi r16, high(LINE_TWO)
		push r16
		ldi r16, low(LINE_TWO)
		push r16
		call lcd_puts
		pop r16
		pop r16
		
		pop r16
		ret
	; At this point, the Y register contains the address of the next
	; character in the array.


; Include LCD library code
.include "lcd_function_code.asm"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                               Data Section                                  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.dseg
; counter
increment: .byte 1
; Define a carry variables
carry_var: .byte 1
; Define an overflow counter
overflows: .byte 1
overflows1: .byte 1
; Boolean values for conditional logic of program
timer_on_flag: .byte 1
lap_timer_flag: .byte 1
; Space in data memory to store each respective line of the LED Display
LINE_ONE: .byte 100
LINE_TWO: .byte 100
; Current time variables
CURRENT_LAP_MIN_L: .byte 1
CURRENT_LAP_MIN_H: .byte 1
CURRENT_LAP_SEC_L: .byte 1
CURRENT_LAP_SEC_H: .byte 1
CURRENT_LAP_TEN: .byte 1
; End of last lap variables
LAST_LAP_END_MIN_L: .byte 1
LAST_LAP_END_MIN_H: .byte 1
LAST_LAP_END_SEC_L: .byte 1
LAST_LAP_END_SEC_H: .byte 1
LAST_LAP_END_TEN: .byte 1
; Start of last lap variables
LAST_LAP_START_MIN_L: .byte 1
LAST_LAP_START_MIN_H: .byte 1
LAST_LAP_START_SEC_L: .byte 1
LAST_LAP_START_SEC_H: .byte 1
LAST_LAP_START_TEN: .byte 1
