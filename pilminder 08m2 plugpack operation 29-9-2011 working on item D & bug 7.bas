'TIMING TEST RESULTS

'26/9/2011
'8 hr test resulted in 8hrs 2 seconds duration using modified interupt routine on mains operation
'1 hr test perfect again using mains interupt ! Allowed led to flash for 3 mins before taking med, hence a 1 hr 3 min time as expected.
'27/9/2011
'12 hr test in progress using pilminder 08m2 plugpack operation 27-9-2011 solved bug 3.bas on mains operation
'- tripped at 12hrs exactly. Allowed it to flash for a while before allowing test to continue to 24 hr point
'- where it tripped on shedule again!
'28/0/2011
'using code pilminder 08m2 plugpack operation 28-9-2011 working on item D.bas
'started 8 hr test (3 pips) running off internal timer - light flashed 8 hrs 34 secs later
'/29/9/2011
'started 1 hr test using code pilminder 08m2 plugpack operation 28-9-2011 working on item D.bas 
'- internal timer 59 min 58 secs allowed led to wink 2 mins, thenacknoledged it
'- sencond time around 59 mins 30 secs
'- 3rd time 59 mins 50 secs
'4th time on mians - 59 mins and about 30 secs
'5th time on mains timing = 59 mins! I suspect it is not returning to mains timing at all!




'BUGLIST

'*1* done - Reminder LED flashes inconsistently
'*2* done Reminder beep for bottle not back in holder is inconsistent as well
'*3* done Late med interval timer to add a beep if user not taken pill doesnt work
'*4* I THINK the bottle may be being tested as being present all the time - this will reduce battery endurance if thats the case 
'*5* Exec loop is being stopped in a 1:30 duty cycle by Check_Med_Time - at least when debug in execloop it is...
'*6* Shouldnt the return in the interupt be right @ the end of the function????
'*7* changeoevr from mains to internal timer, sometimes dumps sec and min timers - single pip might be a clue
'*8" reminder beep to put bottle back not working on repeating 1 hr timer (was on internal timer on this test) . it buzes when time expired
'	it does work when on the mains timer! needs a retest
	
'IDEAS FOR DEVELOPMENT

'**A** done - User should be prompted to take 1st dose of meds as soon as programming complete
'**B** Can have test/demo mode where everything happens quicky - test if bottle present on start or not *****
'**C** Can make beep increase in pitch as more meds per day added ****
'**D** Add a test to see if mains pluses present or not, use internal timer interupt if its not ****
'	**** Ideally needs hardware to change between mains/bat as well - germnaium diodes?
'**E** Allow user to specfify a day to NOT take meds if med count =1 (sat night for Tony S)
'allow bottle to stay in holder during 30 sec med timer period to do this
'**F** Allow user to pre-empt the reminder somehow
'**G** done The reminder to put the bottle back needs to be more urgent pip-pip-pip   pip-pip-pip 
'**H** Remove pip at 24 hr rollover (2 of them)
'**I** Remove InteruptCounterMax vriables and logic
'*J** Is it possible to use the input for mains pulses as a battery volatge monitor when in battery mode?


'Bottle missing @ start = demo mode
'Bottle present and static during med timer programming = 1 med per day, skip this day and every 7th subsequent
'bottle present and removed/replaced = current behaviour = 'x' meds per 24 hr period

'#freq m4

' developed using compiler 5.4.2
'08M2 hardware

'Program Variables
symbol	LineFreq = 50		;  50 Hz
symbol	HighMask = %00001000	;  Interrupt mask for high-going input3 interrupt
symbol	LowMask = %00000000 	;  Interrupt mask for low-going input3 interrupt
symbol	PinMask = %00001000	;  input3 is the interrupt line			
symbol 	IR_Threshold = 150		;  slice level for deciding if bottle present or not
symbol 	Late_Med_Interval = 29  ;  Number mins+1 flashing till beeper goes off as well
symbol	MainsFailedThreshold = 2	;  Slice level for deciding when mains is gone & switch to internal timing

'08M2 I/O definitions
symbol 	Side_LED = 0		'  output 0 (via open collector driver) 
symbol 	Beeper = 1			'  output 1 (drives piezo directly)
symbol 	IR_TX_LED = 2		'  output 2 (drives IR led via 470ohm resistor)** why ?? ould leave tx led on all the time !! **
symbol 	MainsFreq = 3    		'  input 3  (driven from 5VAC plugpack, 10k series R 5v1 zenner to gnd)
symbol 	IR_RX_LED = 4		'  input 4  (analogue input, 10K to gnd, LED to Vcc)

'Register B0 Bit definitions
symbol 	Second_Flag = bit0      
symbol 	Bottle_Missing_Flag = bit1 
symbol 	Day_Roll_Over_Flag = bit2
symbol 	Remind_Req_Flag = bit3    	
symbol 	Min_Flag = bit4
'symbol 	Mains_Failed_Flag = bit5		
symbol 	Sched_Bottle_Check_Flag = bit6
symbol	Int_Sense_Flag =	bit7	;  Semaphore to indicate whether the int sense is high or low  

'Register B1 Bit definitions   

symbol 	Mains_Failed_Flag = bit8

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
symbol 	InteruptCounter = b14
symbol 	InteruptCounterMax = b15
  
'=================================================================
Begin:

'**B** Can have test/demo mode where everything happens quicky - test if bottle present on start or not *****

'SetTimer t1s_4			;set timer to 1 seconds ticks at 4Mhz - but not on the 08m2 BUGGAR!!

'remove and replace bottle X times in next 30 secs to allow user to nominate # times per day to take meds

for SecCount = 0 to 30 ' 30 secs in which to program medication schedule
	gosub Check_Bottle
	if Bottle_Missing_Flag =1 then
		MedsPerDay = MedsPerDay +1
		'**C** Can make beep increase in pitch as more meds per day added ****	
		sound Beeper, (125,1)	   
	endif
LoopBotBack:
	gosub Check_Bottle		
	if Bottle_Missing_Flag =1 then goto LoopBotBack: 'loop around till bottle back
	pause 600
next SecCount

debug

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

	Remind_Req_Flag = 1
	
endif 'MedsPerDay >3

main:
    	setint %00001000, %00001000 ' jump to interrupt on input 3 going high
    		     
execloop:
' All subroutines must yield promptly, and NOT hold the processor. 
	'Interupt routine looks after counting mains pulses, and maintaining timing
    	'debug
wait_Second_Flag:   	
'	If time >= 1 Then		; Internal timer has reached 1 second
'		let time = 0	; set it back to start
'	endif
		
	If Second_Flag = 0 then 	' may need to interlock this with mains_fail_flag
      	inc InteruptCounter	;determine the normal number of interupts in an Execloop cycle in InteruptCounterMax
      	if interuptCounter > InteruptCounterMax then
			InteruptCounterMax = InteruptCounter	
		Endif
		
		If InteruptCounter > MainsFailedThreshold then ; no interupt will be happening...
    			Mains_Failed_Flag = 1	
    			gosub SysTimer		;update system time using a local timer
    		endif
    	
      	GoTo wait_Second_Flag	'ensures a stable flash of the led, somewhat random otherwise - bug **1**
      Else

    		gosub Check_Med_Time		'checks if time to flash side led or make noise - calls remind 
    		gosub Bottle_Check		'checks if time to squeal at user for not putting bottle back

    		'If Min_Flag = 1 then
    		'	debug
    		'Endif
    		
    		Second_Flag = 0; Flags only stays up 1 pass
    		Day_Roll_Over_Flag = 0; 
    		Min_Flag = 0
	Endif
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

	if Day_Roll_Over_Flag = 1 or MedsPerDay = 2 and Mincount = 720 and SecCount =0 then
		Remind_Req_Flag = 1
	'	Bottle_check_counter = 0
	endif 

	if Second_Flag = 1 and Remind_Req_Flag = 1 then
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
		If Min_Flag = 1 then
			Bottle_check_counter = Bottle_check_counter +1
		Endif
		
		if Bottle_check_counter > Late_Med_Interval then
			sound Beeper, (125,1)
		Endif
		
		gosub check_bottle  'this assumes user will never pre-empt the reminder....
		'debug bottle_missing
		if Bottle_Missing_Flag = 1 then 'assume meds just taken
			TimeToNextMed = 0 'sets next med time relative to when bottle lifted
			'Day_Roll_Over_Flag = 0 
			;Med_taken_Flag = 1' what resets or uses this?
			'Med_Missed_Flag = 0 'what resets or uses this?
			Low Side_LED ;force led off - 50% chance it will be on otherwise....
			Sched_Bottle_Check_Flag = 1 
			Remind_Req_Flag = 0
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

SysTimer:
'Only runs if the mains driven interupt isnt happening (this is detected in execloop)
'Otherwise, it does what the mains timer does, with much less precision.

'maintains a second counter in SecCount
'toggles Second_Flag every second
'maintains a minute counter in MinCount
'resets MinCount to 0 at 24hr rollover and sets flag Day_Roll_Over_Flag
'increments TimeToNextMed Counter every minute (used for reminders > 3 per day)

'here when internal timer gets to 1 second and only if interupts arent happening

		If time >= 1 Then		; Internal timer has reached 1 second
			let time = 0	; set it back to start

			MainsCount = 1					; may as well clear it
			inc SecCount					; Increment the second register
			Second_Flag = 1					; Second flag cleared again at end of execloop.
	
			if SecCount >= 60 then
				SecCount = 0
				Inc MinCount
				Min_Flag = 1
				Inc TimeToNextMed
			endif

			if MinCount >= 1440 then 				'day over, start again
				MinCount = 0					'reset elasped min counter
				Day_Roll_Over_Flag = 1
		 		sound Beeper, (200,1)				'1 pip for rollover time
			endif
		endif
 
Return

interrupt:
;maintains a mains frequency counter in MainsCount
'maintains a second counter in SecCount
'toggles Second_Flag every second
'toggles Tenth_Flag every 10th second
'maintains a minute counter in MinCount
'resets MinCount to 0 at 24hr rollover and sets flag Day_Roll_Over_Flag
'increments TimeToNextMed Counter every minute (used for reminders > 3 per day)

	if Int_Sense_Flag = 0 then
	
		;  if the interrupt was called on a low-going transition,
		;  just re-set the interrupt for a high-going transition on pin3
		
		Int_Sense_Flag = 1											
		setint HighMask,PinMask							
		return

	
	else ' Int_Sense_Flag must be = 1
	
		inc MainsCount
		
		Mains_Failed_Flag = 0					;its obviously not, a mains pulse bought us here!
		InteruptCounter = 0					;determine the normal number of interupts in an execloop cycle (in InteruptCounterMax)
		
	'	if MainsCount =5 or MainsCount =10 or MainsCount =15 or MainsCount =20 or MainsCount =25 or MainsCount =30 or MainsCount =35 or MainsCount =40 or MainsCount =45 or MainsCount =50 then
	
	'		toggle Tenth_Flag						
						
	'	endif
		
		if MainsCount >= LineFreq then
		
			MainsCount = 0
			inc SecCount					; Increment the second register
			Second_Flag = 1					; Second flag cleared again at end of execloop.
						
		endif
	
		Int_Sense_Flag = 0											

		if SecCount >= 60 then
		'if SecCount >= 2 then	
			SecCount = 0
			Inc MinCount
			Min_Flag = 1
			Inc TimeToNextMed
		endif

		if MinCount >= 1440 then 				'day over, start again
			MinCount = 0					'reset elasped min counter
			Day_Roll_Over_Flag = 1
		 	sound Beeper, (200,1)				'1 pip for rollover time
		endif
	
	setint LowMask,PinMask					; Re-enable interrupts for pin3 = low
	return
	   

   endif 
' Return  **? ** Shouldnt the return be here????