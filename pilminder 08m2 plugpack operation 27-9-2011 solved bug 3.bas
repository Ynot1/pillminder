'TIMING TEST RESULTS

'26/9/2011
'8 hr test resulted in 8hrs 2 seconds duration using modified interupt routine on mains operation
'1 hr test perfect ! Allowed led to flash for 3 mins before taking med, hence a 1 hr 3 min time as expected.



'BUGLIST

'*1* done - Reminder LED flashes inconsistently
'*2* done Reminder beep for bottle not back in holder is inconsistent as well
'*3* done Late med interval timer to add a beep if user not taken pill doesnt work
'*4* I THINK the bottle may be being tested as being present all the time - this will reduce battery endurance if thats the case 
'*5* Exec loop is being stopped in a 1:30 duty cycle by Check_Med_Time

'IDEAS FOR DEVELOPMENT

'**A** done - User should be prompted to take 1st dose of meds as soon as programming complete
'**B** Can have test/demo mode where everything happens quicky - test if bottle present on start or not *****
'**C** Can make beep increase in pitch as more meds per day added ****
'**D** Add a test to see if mains pluses present or not, use internal timer interupt if its not ****
'	**** Needs hardware to change between mains/bat as well - diodes?
'**E** Allow user to specfify a day to NOT take meds if med count =1 (sat night for Tony S)
'**F** Allow user to pre-empt the reminder somehow
'**G** done The reminder to put the bottle back needs to be more urgent pip-pip-pip   pip-pip-pip 

'#freq m4

' developed using compiler 5.4.2
'08M2 hardware

'Program Variables
symbol	LineFreq = 50		;  50 Hz
symbol	HighMask = %00001000	;  Interrupt mask for high-going input3 interrupt
symbol	LowMask = %00000000 	;  Interrupt mask for low-going input3 interrupt
symbol	PinMask = %00001000	;  input3 is the interrupt line			
symbol 	IR_Threshold = 20		;  slice level for deciding if bottle present or not
symbol 	Late_Med_Interval = 29  ;  Number mins+1 flashing till beeper goes off as well

'08M2 I/O definitions
symbol 	Side_LED = 0		'  output 0 (via open collector driver) 
symbol 	Beeper = 1			'  output 1 (drives piezo directly)
symbol 	IR_TX_LED = 2		'  output 2 (drives IR led via 470ohm resistor)** why ?? ould leave tx led on all the time !! **
symbol 	MainsFreq = 3    		'  input 3  (driven from 5VAC plugpack, 10k series R 5v1 zenner to gnd)
symbol 	IR_RX_LED = 4		'  input 4  (analogue input, 10K to gnd, IR LED to Vcc)

'Register B0 Bit definitions
symbol 	Second_Flag = bit0      
symbol 	Bottle_Missing_Flag = bit1 
symbol 	DayRollOverFlag = bit2
symbol 	RemindReq = bit3    	
symbol 	MinFlag = bit4
'symbol 	Tenth_Flag = bit5		'not being used at present commented out in interupt routine
symbol 	Sched_Bottle_Check_Flag = bit6
symbol	Int_sense =	bit7	;  Semaphore to indicate whether the int sense is high or low  

'Register B1 Bit definitions   

'all bits 8-15 (or b1) available

'Register B2 - B27 definitions 

'b2 & b3 used as w1 / MinCount
symbol 	MinCount = w1 	'elasped minutes since rollover
symbol 	SecCount = b4
symbol 	Mainscount = b5
symbol 	MedsPerDay = b6 
symbol 	IR_Level = b7
'b8 & b9 used as w4
symbol 	Med_Interval = w4
symbol 	Bottle_Check_Counter = b10
symbol 	ConfirmCounter = b11
'b12 & b13 used as w6
symbol 	TimeToNextMed = w6 'b12/b13
  
'=================================================================

'remove and replace bottle X times in next 30 secs to allow user to nominate # times per day to take meds

for SecCount = 0 to 30 ' 20 secs in which to program med schedule
	gosub Check_Bottle		
	if Bottle_Missing_Flag =1 then
		MedsPerDay = MedsPerDay +1
	sound Beeper, (125,1)	   
	endif
LoopBotBack:
	gosub Check_Bottle		
	if Bottle_Missing_Flag =1 then goto LoopBotBack: 'loop around till bottle back
	pause 600
next SecCount


if MedsPerDay = 0 then 
	let MedsPerDay = 1 ; assume a 24 hr dose shedule if no counts clocked up
endif

if MedsPerDay > 24 then 
	let MedsPerDay = 24 ; assume 1 dose per hour maximum
endif

'Reflect meds per day back to user...

for ConfirmCounter = 1 to MedsPerDay
	sound Beeper, (125,1)
	pause 600
next ConfirmCounter

ConfirmCounter = 0	;allows counter to be used again in Bottle_Check routine

'**E** Allow user to specfify a day to NOT take meds if med count =1 (sat night for Tony S)

SecCount = 0 ;start from scratch

'at this point, MedsPerDay (A BYTE) contains a number > 1 representing # doses per 24 hrs required

Med_Interval = 1440 / MedsPerDay ' # mins in 24 hrs divided by # doses required

'at this point, Med_Interval (a WORD) contains the # minutes between doses

'Preload timers so user prompted to take meds now programing is complete item **A**

if MedsPerDay >=3 then 
	TimeToNextMed = Med_Interval
		
Else 'medsPerDay <3

	RemindReq = 1
	
endif 'MedsPerDay >3


main:
    	setint %00001000, %00001000 ' jump to interrupt on input 3 going high
    		     
execloop:
' All subroutines must yield promptly, and NOT hold the processor. 
	'Interupt routine looks after counting mains pulses, and maintaining timing
    	'debug
wait_Second_Flag:   	
	If Second_Flag = 0 then 
      	GoTo wait_Second_Flag	'ensures a stable flash of the led, somewhat random otherwise - bug **1**
      Endif
    	gosub Check_Med_Time		'checks if time to flash side led or make noise - calls remind 
    	gosub Bottle_Check		'checks if time to squeal at user for not putting bottle back

    	Second_Flag = 0; Flags only stays up 1 pass
    	DayRollOverFlag = 0; 
    	MinFlag = 0
GoTo execloop

 
Check_Med_Time:

if MedsPerDay >=3 then 
'if meds taken 3X day or more, the time of day isnt used to trip reminder, instead a time relative to the
'last time a dose was taken is used
;the reminders will get later in the day as time goes on, but will always the same time apart.

	if Second_Flag = 1 and TimeToNextMed => Med_Interval then
		gosub Remind
	endif 
	
Else 'medsPerDay <3
'if meds taken 1 or 2 times per day, the time of day is used to trip reminder at regular intervals
'irrspective of when the last dose was taken
;reminders will occur at regular intervals
'here if medsperday = 1 or 2

	if DayRollOverFlag = 1 or MedsPerDay = 2 and Mincount = 720 and SecCount =0 then
		RemindReq = 1
	'	Bottle_check_counter = 0
	endif 

	if Second_Flag = 1 and RemindReq = 1 then
		gosub remind
	endif	
endif 'MedsPerDay >3
	
Return 

Remind:
'flashes the reminder led
'checks to see if the bottle picked up
'when bottle is picked up, sets flags and dumps timers
		gosub Toggle_Side_LED
	'	sound Beeper, (125,1)
		If MinFlag = 1 then
			Bottle_check_counter = Bottle_check_counter +1
		Endif
		
		if Bottle_check_counter > Late_Med_Interval then
			sound Beeper, (125,1)
		Endif
		
		gosub check_bottle  'this assumes user will never pre-empt the reminder....
		'debug bottle_missing
		if Bottle_Missing_Flag = 1 then 'assume meds just taken
			TimeToNextMed = 0 'sets next med time relative to when bottle lifted
			'DayRollOverFlag = 0 
			;Med_taken_Flag = 1' what resets or uses this?
			'Med_Missed_Flag = 0 'what resets or uses this?
			Low Side_LED ;force led off - 50% chance it will be on otherwise....
			Sched_Bottle_Check_Flag = 1 
			RemindReq = 0
			Bottle_check_counter = 0
		endif 'If Bottle_missing = 1 then
	
Return

Bottle_Check:

	if sched_Bottle_Check_Flag = 1 and Second_Flag = 1 then
		Bottle_Check_Counter = Bottle_Check_Counter + 1
		gosub Check_Bottle
		if bottle_Missing_Flag = 0 then 'user has put bottle back in holder, all good
			sched_Bottle_Check_Flag = 0
			Bottle_Check_Counter = 0
			Low Side_LED ;force led off - 50% chance it will be on otherwise....
		elseif Bottle_Check_Counter > 30 then ' after 30 secs
			gosub Toggle_Side_LED
			For ConfirmCounter = 0 to 5  '**G**
				sound Beeper, (125,1)
				pause 10
			Next ConfirmCounter
		endif
	endif		
Return	
	
Toggle_Side_LED:
' Drive side led - toggle every second'
    
    if Second_Flag = 1 then 
        toggle Side_LED
    EndIf
       
Return

'=================================================================

Check_Bottle: 

'powers up ir led and reads adc connected to IR sensor
'checks it against threshold. Sets Bottle_Missing flag if bottle not in holder
	

	high IR_TX_LED
	let Bottle_Missing_Flag = 0
	readadc IR_RX_led, IR_level
		
	low IR_TX_LED
	
	if IR_Level > IR_Threshold then 
		let Bottle_Missing_Flag = 1 
	endif
	'470 ohm tx current limit resistor, 5k rx resistor to gnd with IR led to VCC.
	'ambient dark
	'60 units bottle missing 2-5 when in place when ambient is dark.  may be scope to reduce tx current further
	'ambient full sun
	'bright sunshine a problem.mt bottle in full sun reads 130, full bottle in full sun about 20 bottle missing in full sun reads 250

Return
'=================================================================


interrupt:
;maintains a mains frequency counter in MainsCount
'maintains a second counter in SecCount
'toggles Second_Flag every second
'toggles Tenth_Flag every 10th second
'maintains a minute counter in MinCount
'resets MinCount to 0 at 24hr rollover and sets flag DayRolloverFlag
'increments TimeToNextMed Counter every minute (used for reminders > 3 per day)

	if Int_sense = 0 then
	
		;  if the interrupt was called on a low-going transition,
		;  just re-set the interrupt for a high-going transition on pin3
		
		Int_sense = 1											
		setint HighMask,PinMask							
		return

	
	else
	
		'inc PulseReg						; used to time pulses sent to display
		
		inc MainsCount
		
	'	if MainsCount =5 or MainsCount =10 or MainsCount =15 or MainsCount =20 or MainsCount =25 or MainsCount =30 or MainsCount =35 or MainsCount =40 or MainsCount =45 or MainsCount =50 then
	
	'		toggle Tenth_Flag						
						
	'	endif
		
		if MainsCount >= LineFreq then
		
			MainsCount = 0
			inc SecCount					; Increment the second register
			Second_Flag = 1					; Second flag cleared again at end of execloop.
						
		endif
	
		Int_sense = 0											

		if SecCount >= 60 then
		'if SecCount >= 2 then	
			SecCount = 0
			Inc MinCount
			MinFlag = 1
			Inc TimeToNextMed
		endif

		if MinCount >= 1440 then 				'day over, start again
			MinCount = 0					'reset elasped min counter
			DayRollOverFlag = 1
		 	'sound Beeper, (200,1)				'1 pip for rollover time
		endif
	
	setint LowMask,PinMask					; Re-enable interrupts for pin3 = low
	return
	   

   endif 