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
'6/10
'series of 3 or 4 1 hr tests, on both mains and batt timing , also checked switching between timing sources. No fault found
'7/10
;12 hr test on batt timing - within30 secs. swapped to and from to mains, no problems. 12 hr test on mains continues....
;declaring bug 7 not found - cant fix what aint broke! might be related to debug...
;declaring development D done. 
'13/10
;declaring development E done. 
;started a 8 hr test on mains
;8hr bit was fine, but it didnt do the beepy thing 30 mins later. it wasnt doing anything....
;likely to be sun onto the IR sensor..
'made new sensor hood suitable for daytime use, started 3 hr test. started flashing exactly on time. 30 mins & 30 sec timers worked ok as well.



'BUGLIST

'*1* done - Reminder LED flashes inconsistently
'*2* done Reminder beep for bottle not back in holder is inconsistent as well
'*3* done Late med interval timer to add a beep if user not taken pill doesnt work
'*4* fault not found I THINK the bottle may be being tested as being present all the time - this will reduce battery endurance if thats the case 
'*5* fault not found Exec loop is being stopped in a 1:30 duty cycle by Check_Med_Time - at least when debug in execloop it is...
'*6* Shouldnt the return in the interupt be right @ the end of the function????
'*7* fault not found later - related to bug 10? changeover from mains to internal timer, sometimes dumps sec and min timers - single pip might be a clue
'*8" reminder beep to put bottle back not working on repeating 1 hr timer (was on internal timer on this test) . it buzes when time expired
'	it does work when on the mains timer! needs a retest
'*9* the user has to put the bottle back for the 30 sec timer at begining to work. It all stalls if you leave it out
'*10* changeoevr from mains<>battery very flaky. often reboots i think its hardware not software - psu rail glitch i suspect
'*11* done beeping to get user to put bottle back only lasts 3 min 50 sec, and side_led is left on when it stops. byte counter overflowing...
	
'IDEAS FOR DEVELOPMENT

'**A** done - User should be prompted to take 1st dose of meds as soon as programming complete
'**B** done Can have test/demo mode where everything happens quicky - test if bottle present on start or not *****
'**C** Can make beep increase in pitch as more meds per day added ****
'**D** done Add a test to see if mains pluses present or not, use internal timer interupt if its not ****
'	**** Ideally needs hardware to change between mains/bat as well - germnaium diodes?
'**E** done Allow user to specfify a day to NOT take meds if med count =1 (sat night for Tony S)
'**F** done Allow user to pre-empt the reminder somehow
'**G** done The reminder to put the bottle back needs to be more urgent pip-pip-pip   pip-pip-pip 
'**H** Remove pip at 24 hr rollover (2 of them) 
'**I** done Remove InteruptCounterMax variables and logic
'**J** Test for bottle missing at medtime and generate alarm, rather than assume pill taken.
'**K** Tidy code indents ect
'**L** done Swap outputs 1 and 2 then add tune during the skiped med istead of a boring beep
'**M** Experiment with checking IR level and looking for an abrubt change in level, rather than a crossing of a threshold.
'compare level now against a rolling average of last few reads
'this might be a better way of detecting bottle up or foil up if sunlight is involved in the mix.
'be a problem if the sensor is swamped - but you could probably detect that as well.

'**N** Music doesnt play properly when running on mains. Does the interupt screw it?
'**O** done its very quiet in the first production prototype case...No holes to let sound out!

' operation
'Bottle missing @ start = demo mode **B**
'Bottle present and static during med timer programming = 1 med per day, skip this day and every 7th subsequent day **E**
'bottle present and removed/replaced = 'x' meds per 24 hr period

'#freq m4

' developed using compiler 5.4.2
'08M2 hardware

'Program Variables
symbol	LineFreq = 50		;  50 Hz
symbol 	IR_Threshold = 100' was 40 'was 150		;  slice level for deciding if bottle present or not
symbol 	Late_Med_Interval = 29  ;  Number mins+1 flashing till beeper goes off as well
symbol	MainsFailedThreshold = 2	;  Slice level for deciding when mains is gone & switch to internal timing
symbol	Demo_interval = 5	;seconds
symbol	TouchValueThresholdIncrement = 150 ;this value works sometimes with coil of hookup wite 1cm dia, and the thick wall prototype...
symbol	PreemptValue = 30 'mins

'08M2 I/O definitions
'symbol 	Side_LED = 0		'  output 0 on pin 7 (via open collector driver) 
'symbol 	Beeper = 2			'  output 2 on pin 5 (drives IR led via 470ohm resistor) ** why ?? would leave tx led on all the time !! **
'symbol	TuneNum = 1			' 1 for 08M2
'symbol 	IR_TX_LED = 1		'  output 1 on pin 6 (drives piezo directly)
'symbol 	MainsFreq = 3    		'  input 3 on pin 4 (driven from 5VAC plugpack, 10k series R 5v1 zenner to gnd)
'symbol 	IR_RX_LED = 4
'symbol	HighMask = %00001000	;  Interrupt mask for high-going input3 interrupt
'symbol	LowMask = %00000000 	;  Interrupt mask for low-going input3 interrupt
'symbol	PinMask = %00001000	;  input3 is the interrupt line			

'014M2 I/O definitions

symbol 	IR_TX_LED = B.1	'pin 12output 1 (via open collector drver)
symbol 	Beeper = B.2	'pin 11
symbol	TuneNum = 2		'2 for 14M2
symbol 	Side_LED = B.3	'pin 10 (via open collector drver) 
symbol 	IR_RX_LED = C.0	'pin 7 (analogue input)
symbol 	MainsFreq = C.2 	'pin 5 (driven from 5VAC plugpack, 10k series R 5v1 zenner to gnd) 
symbol	TouchSensor1 = C.4'pin 3
symbol	TouchSensor2 = B.5'pin 8

'the wooden pillminder not setup for mains input as yet...
symbol Bat_Voltage_Sensor = 4 ; not used yet...
'the wooden pillminder is setup for low battery detection, but there is no code for it in this version
'input 4 on pin 3 (analogue input, 10K to gnd, LED to Vcc)
symbol	HighMask = %00000100	;  Interrupt mask for high-going input3 interrupt
symbol	LowMask = %00000000 	;  Interrupt mask for low-going input3 interrupt
symbol	PinMask = %00000100	;  input3 is the interrupt line			


'Register B0 Bit definitions bit0 - bit7
symbol 	Second_Flag = bit0      
symbol 	Bottle_Missing_Flag = bit1 
symbol 	Day_Roll_Over_Flag = bit2
symbol 	Remind_Req_Flag = bit3    	
symbol 	Min_Flag = bit4
symbol 	Demo_Mode_Flag = bit5	'do you need this?	
symbol 	Sched_Bottle_Check_Flag = bit6
symbol	Int_Sense_Flag =	bit7	;  Semaphore to indicate whether the int sense is high or low  

'Register B1 Bit definitions bit8 - bit15

symbol 	Mains_Failed_Flag = bit8 ' do you need this?
symbol 	Skip_Tune_Played_Already_Flag = bit9
symbol	Preempt_Flag = bit10
symbol	Prempt_SkipNextRemind_Flag = bit11

'Register B2 - B27 definitions 


symbol 	MinCount = w1 		'elasped minutes since rollover
'b2 & b3 used as w1 
symbol 	SecCount = b4
symbol 	Mainscount = b5
symbol 	MedsPerDay = b6 
symbol 	IR_Level = b7
'b8 & b9 used as w4
symbol 	Med_Interval = w4

symbol 	TouchValueThreshold2 = w5
'b10 & b11 used as w5

symbol 	TimeToNextMed = w6 'b12/b13
'b12 & b13 used as w6
symbol 	InteruptCounter = b14
symbol 	General_Counter = b15 

symbol	SkipDayCounter = b16	''a non zero value indicates MedSkipDay is active, the skip day is 1
symbol	Bottle_Check_Threshold = b17

 
'B18 & b19 used as w9

symbol 	Bottle_Check_Counter = w9 ' b18/19 needs a word avoid overflow of a byte at ~ 3 min 50 - counts seconds

symbol	TouchValue = w10
'B20 & b21 used as w10
symbol 	TouchValueThreshold1 = w11
'B22 & b23 used as w11
symbol	PremptCheck = w12
'B24 & b25 used as w12

'symbol 	unused = w13
'B26 & b27 used as w13

 
'=================================================================
Begin:
let 		Bottle_Check_Threshold = 30 ; 30 seconds normally, overwritten to 3 in demo mode

		'	gosub Check_Bottle
		'	debug
		'	goto begin

CalibrateTouch1:

	'Calc baseline for Touch Sensor
	touch16 TouchSensor1, TouchValueThreshold1
	for General_Counter = 1 to 20
		touch16 TouchSensor1, TouchValue
		Let TouchValueThreshold1 = TouchValue + TouchValueThreshold1 / 2 
	next
	'set detect value based on baseline + add-value

	Let TouchValueThreshold1 = TouchValueThreshold1 + TouchValueThresholdIncrement
	
'CalibrateTouch2:


	'Calc baseline for Touch Sensor
	touch16 TouchSensor2, TouchValueThreshold2
	for General_Counter = 1 to 20
		touch16 TouchSensor2, TouchValue
	Let TouchValueThreshold2 = TouchValue + TouchValueThreshold2 / 2 
	next
	'set detect value based on baseline + add-value

	Let TouchValueThreshold2 = TouchValueThreshold2 + TouchValueThresholdIncrement
	
	
'**B** Can have test/demo mode where everything happens quicky - test if bottle present on start or not *****
	gosub Check_Bottle
		'debug
		'goto begin:
		
	if Bottle_Missing_Flag = 1 then 
		setint HighMask,PinMask	
		'setint %00001000, %00001000 ' jump to interrupt on input 3 going high
		Demo_mode_Flag =1 ;modifies Remind and Check_bottle_back routine behaviours
		let Bottle_Check_Threshold = 3
		goto demo:	'jump to demo routine.
	endif

'	debug

' touch sensor 1 X times in next 30 secs to allow user to nominate # times per day to take meds

	for SecCount = 0 to 30 ' 30 secs in which to program medication schedule
	'gosub Check_Bottle - used to use this to program med timer intervals...
	
	touch16 touchSensor2, touchvalue

	if touchvalue >TouchValueThreshold2 then 'Bottle_Missing_Flag =1 or Bottle_Missing_Flag =1 or
		MedsPerDay = MedsPerDay +1
		'**C** Can make beep increase in pitch as more meds per day added ****	
		;sound Beeper, (125,1)	
		for General_Counter = 1 to MedsPerDay
			sound Beeper, (125,1)
			pause 600
		next General_Counter
		General_Counter = 0	;allows counter to be used again in Bottle_Check routine
	
		if MedsPerDay = 3 then
			touch16 touchSensor1, touchvalue
			if touchvalue >TouchValueThreshold1 then 
				' assume user wants to skip this day and every 7th subsequent
				sound Beeper, (155,1)
				SkipDayCounter = 1 'a non zero value indicates MedSkipDay is active, 1 is the SkipDay
				let MedsPerDay = 1
			endif'touchvalue >TouchValueThreshold1
		endif
	endif'touchvalue >TouchValueThreshold2
	
	
LoopBotBack:
	gosub Check_Bottle
			
	if Bottle_Missing_Flag =1 then goto LoopBotBack: 'loop around till bottle back
	
	pause 600
	next SecCount


	if MedsPerDay = 0 then 'assume 24 hr doseing shcedule
		let MedsPerDay = 1
	endif

	if MedsPerDay > 24 then 
		let MedsPerDay = 24 ; 1 dose per hour maximum
	endif

'Reflect meds per day back to user...

	for General_Counter = 1 to MedsPerDay
		sound Beeper, (125,1)
		pause 600
	next General_Counter
	General_Counter = 0	;allows counter to be used again in Bottle_Check routine
	SecCount = 0 ;start from scratch

'at this point, MedsPerDay (A BYTE) contains a number > 1 representing # doses per 24 hrs required

	Med_Interval = 1440 / MedsPerDay ' # mins in 24 hrs divided by # doses required

'at this point, Med_Interval (a WORD) contains the # minutes between doses

'Preload timers so user prompted to take meds now programing is complete item **A**

main:
	If MedsPerDay >=3 then 
		TimeToNextMed = Med_Interval
		
	Else 'medsPerDay <3

		Remind_Req_Flag = 1
	
	Endif 'MedsPerDay >3
	

    	setint HighMask,PinMask	     


execloop:

' All subroutines must yield promptly, and NOT hold the processor. 
'Interupt routine looks after counting mains pulses, and maintaining timing

wait_Second_Flag:   	
		
	If Second_Flag = 0 then 	
      	inc InteruptCounter	;determine the normal number of interupts in an Execloop cycle in InteruptCounterMax
      	'if interuptCounter > InteruptCounterMax then
		'	InteruptCounterMax = InteruptCounter	
		'endif
		
		If InteruptCounter > MainsFailedThreshold then ; no interupt will be happening...
    			Mains_Failed_Flag = 1	
    			gosub SysTimer		;update system time using the local timer
    		endif
    		
    		    	
      	GoTo wait_Second_Flag	'ensures a stable flash of the led, somewhat random otherwise - bug **1**
      Else

    		gosub Check_Med_Time		'checks if time to flash side led or make noise - calls remind 
    		gosub Is_Bottle_Back_Check		'checks if time to squeal at user for not putting bottle back

    		'If Min_Flag = 1 then
    		'	debug
    		'Endif
    		
    		Second_Flag = 0; Flags only stays up 1 pass
    		Day_Roll_Over_Flag = 0; 
    		Min_Flag = 0
    		
    		

		
		
		'Here to allow preempting the med timers to take pills early
		touch16 touchSensor2, touchvalue
		if touchvalue >TouchValueThreshold2 then
		
			if MedsPerDay <=2 then
					
				'here to pre-empt medication timer
			
				PremptCheck = TimeToNextMed + PreemptValue
			
				if PremptCheck >= Med_Interval Then
				'here to prompt for meds to be taken early
				
					Preempt_Flag =1

				else
					'here to tell user to piss off, its too early to take the pill, come back later
					sound Beeper, (100,30)
				endif
			else'if MedsPerDay >3
				'here to tell user to piss off, you cant prempt meds when taking them >3 x per day
				sound Beeper, (100,30)
			endif'if MedsPerDay <=2
		endif'touchvalue >TouchValueThreshold2
		
		
		
		
	'	touch16 touchSensor1, touchvalue
	'	
	'	if touchvalue >TouchValueThreshold1 then
	'				
	'		'here to preload min and med timers for a test
	'		sound Beeper, (200,30)
	'		gosub Check_Bottle
	'		debug
	'		MinCount = 1439'359'1439
	'		TimeToNextMed = 1439'359'1439
	'		
	'		
	'	endif
   		
    	Endif
    	
	GoTo execloop

 
Check_Med_Time:

	if MedsPerDay >=3 then 
'if meds taken 3X day or more, the time of day isnt used to trip reminder, instead a time relative to the
'last time a dose was taken is used
;the reminders will get later in the day as time goes on, but will always be the same time apart.
		if Second_Flag = 1 and TimeToNextMed => Med_Interval then
			gosub Remind
		endif  
	
	Else 'medsPerDay <3
'if meds taken 1 or 2 times per day, the time of day is used to trip reminder at regular intervals
'irrespective of when the last dose was taken (preempting probably breaks this rule)
;reminders will occur at regular intervals
'here if medsperday = 1 or 2
		if Prempt_SkipNextRemind_Flag =1 and Day_Roll_Over_Flag = 1 or MedsPerDay = 2 and Mincount = 720 and SecCount =0 then
			Prempt_SkipNextRemind_Flag =0
		
		
		elseif Preempt_Flag = 1 or Day_Roll_Over_Flag = 1 or MedsPerDay = 2 and Mincount = 720 and SecCount =0 then
			if Preempt_Flag =1 then
				Preempt_Flag =0
				Prempt_SkipNextRemind_Flag =1	
			endif
			Remind_Req_Flag = 1
		endif 

		if Second_Flag = 1 and Remind_Req_Flag = 1 then
			If SkipDayCounter <> 1 then	'1 is SkipDay
				gosub remind
			Else ' here if skipday and its the normal time to take meds
				'tune TuneNum, 13,($49,$40,$44,$49,$4B,$44,$40,$4B,$50,$44,$40)
				tune TuneNum, 13,($49,$40,$44,$49,$4B,$44,$40,$4B,$50,$44,$40,$50,$46,$42,$49,$46,$44,$40,$49,$00,$44,$40,$79,$77,$77,$79,$39)
				Remind_Req_Flag = 0
			Endif
		endif
		'endif	'If SkipDayCounter = 1
	endif 'MedsPerDay >3
	
Return 

Remind:
'flashes the reminder led
'checks to see if the bottle picked up
'when bottle is picked up, sets sched_bottle_check_flag and dumps timers
	gosub Toggle_Side_LED
	if Demo_Mode_Flag = 0 then ;no Late_med_interval reminders in demo mode
		If Min_Flag = 1 then
			Bottle_check_counter = Bottle_check_counter +1
		Endif
		
		if Bottle_check_counter > Late_Med_Interval then
			sound Beeper, (125,1)
		Endif
	endif	
	gosub check_bottle  'this assumes user will never pre-empt the reminder without using the touch sensor for permission....
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
		if Demo_Mode_Flag = 1 then
			General_Counter = 0
		endif
	endif 'If Bottle_missing = 1 then
	
Return

Is_Bottle_Back_Check:

	if sched_Bottle_Check_Flag = 1 and Second_Flag = 1 then
		Bottle_Check_Counter = Bottle_Check_Counter + 1
		gosub Check_Bottle
		if bottle_Missing_Flag = 0 then 'user has put bottle back in holder, all good
			if Demo_Mode_Flag = 1 then
				General_Counter = 0
			endif
			sched_Bottle_Check_Flag = 0
			Bottle_Check_Counter = 0
			Low Side_LED ;force led off - 50% chance it will be on otherwise....
		elseif Bottle_Check_Counter > Bottle_Check_Threshold then ' after 30 secs
			gosub Toggle_Side_LED
			For General_Counter = 0 to 5  
				sound Beeper, (125,1)
				pause 10
			Next General_Counter
		endif
	endif		
Return	
	
Toggle_Side_LED:
' Drive side led - toggle every second'
    
    if Second_Flag = 1 then 
        toggle Side_LED
    endif
       
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
			Day_Roll_Over_Flag = 1				'1 = sat...
			if SkipDayCounter >= 1 then			'SkipDayCounter = 0 means SkipDay inactive
				inc SkipDayCounter
				if SkipDayCounter = 8 then		'week over
					SkipDayCounter =1
				endif
			endif
			sound Beeper, (200,1)				'1 pip for rollover time
		endif
	endif
 
Return

demo:
'Point of sale demo mode
'Prompts user to take meds on an ongoing and continuing basis with minimal delays and noises
'this is essentially a simplier exexloop
'makes calls on same subroutines as real execloop

	'tune TuneNum, 13,($49,$40,$44,$49,$4B,$44,$40,$4B,$50,$44,$40,$50,$46,$42,$49,$46,$44,$40,$49,$00,$44,$40,$79,$77,$77,$79,$39)
	tune TuneNum, 13,($49,$40,$44,$49,$4B)
				
wait_Second_Flag_Demo:   	
		
	If Second_Flag = 0 then 
		
      	inc InteruptCounter	;determine the normal number of interupts in an Execloop cycle in InteruptCounterMax		
		If InteruptCounter > MainsFailedThreshold then ; no interupt will be happening...
    			Mains_Failed_Flag = 1	
    			gosub SysTimer		;update system time using the local timer
    		endif
    	
      	GoTo wait_Second_Flag_Demo	'ensures a stable flash of the led, somewhat random otherwise - bug **1**
      Else
      
            Inc General_Counter
            
            If General_Counter > Demo_Interval then
             
            if Sched_Bottle_Check_Flag = 0 then 'and General_Counter > Demo_Interval then
    			gosub Remind
    		'else
    			
    		endif	
    		
    		endif
    		
    		gosub Is_Bottle_Back_Check	'checks if time to squeal at user for not putting bottle back

    		'If Min_Flag = 1 then
    		'	debug
    		'Endif
    		
    		Second_Flag = 0; Flags only stays up 1 pass
    		Day_Roll_Over_Flag = 0; 
    		Min_Flag = 0
    		
    	Endif
    	
	GoTo wait_Second_Flag_Demo


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
		InteruptCounter = 0					;indicate to execloops that mains interupts are occuring normally
		
	
		'if MainsCount >= 2 then
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
			MinCount = 0				'reset elasped min counter
			'MinCount = 1439				'reset elasped min counter to day-1
			Day_Roll_Over_Flag = 1
			if SkipDayCounter >= 1 then
				inc SkipDayCounter
				if SkipDayCounter = 8 then			'week over
					SkipDayCounter =1
				endif
			endif
	 		sound Beeper, (200,1)				'1 pip for rollover time
		endif
	
		setint LowMask,PinMask					; Re-enable interrupts for pin3 = low
return
	   

	endif ' Where is the if for this?
' Return  **? ** Shouldnt the return be here????