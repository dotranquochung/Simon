--------------------------------------------------------------------------------
--
--   FileName:         hw_image_generator.vhd
--   Dependencies:     none
--   Design Software:  Quartus II 64-bit Version 12.1 Build 177 SJ Full Version
--
--   HDL CODE IS PROVIDED "AS IS."  DIGI-KEY EXPRESSLY DISCLAIMS ANY
--   WARRANTY OF ANY KIND, WHETHER EXPRESS OR IMPLIED, INCLUDING BUT NOT
--   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
--   PARTICULAR PURPOSE, OR NON-INFRINGEMENT. IN NO EVENT SHALL DIGI-KEY
--   BE LIABLE FOR ANY INCIDENTAL, SPECIAL, INDIRECT OR CONSEQUENTIAL
--   DAMAGES, LOST PROFITS OR LOST DATA, HARM TO YOUR EQUIPMENT, COST OF
--   PROCUREMENT OF SUBSTITUTE GOODS, TECHNOLOGY OR SERVICES, ANY CLAIMS
--   BY THIRD PARTIES (INCLUDING BUT NOT LIMITED TO ANY DEFENSE THEREOF),
--   ANY CLAIMS FOR INDEMNITY OR CONTRIBUTION, OR OTHER SIMILAR COSTS.
--
--   Version History
--   Version 1.0 05/10/2013 Scott Larson
--     Initial Public Release
--    
--------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;

ENTITY hw_image_generator IS
	PORT(
		----KEYBOARD
		ps2_code_new: IN STD_LOGIC;
		ps2_code 	: IN STD_LOGIC_VECTOR (7 DOWNTO 0); --keyboard code
		
		-----CLOCK
		game_clk		: IN STD_LOGIC;
		
		--SWITCHES to START / RESET (not buttons)
		reset_button: IN STD_LOGIC; --sw17
		start_button: IN STD_LOGIC; --sw16
		
		----Change the pattern-------
		sw0			: IN STD_LOGIC;
		sw1			: IN STD_LOGIC;
		sw2			: IN STD_LOGIC;
		sw3			: IN STD_LOGIC;
		sw4			: IN STD_LOGIC;
		sw5			: IN STD_LOGIC;
		sw6			: IN STD_LOGIC;
		sw7			: IN STD_LOGIC;
		
		----Speed up---------------
		sw8			: IN STD_LOGIC;
		sw9			: IN STD_LOGIC;
		sw10			: IN STD_LOGIC;
		sw11			: IN STD_LOGIC;
		sw12			: IN STD_LOGIC;
		sw13			: IN STD_LOGIC;
		
		--BUTTONS FOR CHECKING-----
		btn1			: IN STD_LOGIC;
		btn2			: IN STD_LOGIC;
		btn3			: IN STD_LOGIC;
		btn4			: IN STD_LOGIC;
		
		----LED---------------------
		ledCorrect	: OUT STD_LOGIC;
		ledWrong 	: OUT STD_LOGIC;
		led0			: OUT STD_LOGIC;
		led1			: OUT STD_LOGIC;
		led2			: OUT STD_LOGIC;
		led3			: OUT STD_LOGIC;
		--ORIGINAL CODE---------------
		disp_ena		:	IN		STD_LOGIC;	--display enable ('1' = display time, '0' = blanking time)
		row			:	IN		INTEGER;		--row pixel coordinate
		column		:	IN		INTEGER;		--column pixel coordinate
		red			:	OUT	STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');  --red magnitude output to DAC
		green			:	OUT	STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');  --green magnitude output to DAC
		blue			:	OUT	STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0'); --blue magnitude output to DAC
		---
		
		---Checking num compared to color on the screen---
		LED_hex			: OUT 	STD_LOGIC_VECTOR(0 to 6));
		
		
		
END hw_image_generator;

ARCHITECTURE behavior OF hw_image_generator IS
	-------------Clock-------------------------
	signal counter 	:	INTEGER RANGE 0 TO 30000000; 
	signal count		:	INTEGER RANGE 0 TO 15000000;	
	signal count_check: 	INTEGER RANGE 0 To 25000000; --waiting user input
	
	signal random	:	INTEGER RANGE 0 TO 3;
	signal color	: 	INTEGER RANGE 0 TO 3;
	signal color_temp : INTEGER;
	
	signal out_time: 	INTEGER:= 0; -- how many times output on the screen
	
	
	signal changes : INTEGER RANGE 0 TO 5000000:=0; --changing the pattern
	signal speedup : INTEGER RANGE 0 TO 15000000:=0; --speed up (didn't work)
	signal num: INTEGER:= 0;
	
	-----------Checking---------
	signal correct: BOOLEAN;
	signal started: BOOLEAN;
	signal check_reset: BOOLEAN:= FALSE;
	
	-----------Output num---------------
	signal hex 		: STD_LOGIC_VECTOR(0 to 6);

	-------Array-------
	type t_vector IS ARRAY (0 to 10) of INTEGER; --vector 11 element
	signal vector : t_vector;
	-------FSM---------
	type State_type IS (RUN_PATTERN, WAIT_STATE, PATTERN_CHECK, RESET); 
	signal state : State_type; 
	signal state_started : BOOLEAN;

BEGIN
	-------------Change the pattern----------------------------------------
	PROCESS (sw0,sw1,sw2,sw3,sw4,sw5,sw6,sw7,changes)
	BEGIN
		IF sw0 = '1' THEN
			changes <= 4500000;
		ELSIF sw1 = '1' THEN
			changes <= 4000000;
		ELSIF sw2 = '1' THEN
			changes <= 5000000;
		ELSIF sw3 = '1' THEN
			changes <= 1000000;
		ELSIF sw4 = '1' THEN
			changes <= 2000000;
		ELSIF sw5 = '1' THEN
			changes <= 3000000;
		ELSIF sw6 = '1' THEN
			changes <= 2500000;
		ELSIF sw7 = '1' THEN
			changes <= 3500000;
		ELSE
			changes <= 0;
		END IF;
	END PROCESS;
	
	-----------------SPEED UP (didn't work)------------------------------
	PROCESS (sw8,sw9,sw10,speedup)
	BEGIN
		IF sw8 = '1' THEN
			speedup <= 5000000;
		ELSIF	sw9 = '1' THEN
			speedup <= 10000000;
		ELSIF	sw10 = '1' THEN
			speedup <= 15000000;
		ELSE
			speedup <= 0;
		END IF;
	END PROCESS;
	
	
	PROCESS--(game_clk,start_button, reset_button,changes,speedup)
	variable k: INTEGER;
	BEGIN
	IF NOT state_started THEN
		state <= WAIT_STATE;
		state_started <= NOT state_started;
	END IF;
	
	----REset button on
	IF	reset_button = '1' THEN
		state <= RESET;
	END IF;
	WAIT UNTIL falling_edge(game_clk); 
	IF count <= 10000000 + changes THEN --change pattern when needed (1/5 of the second)
		count <= count + 1;
	ELSE
		IF random < 3 THEN
			random <= random + 1;
		ELSE
			random <= 0;
		END IF;
		count <= 0;
	END IF;
	CASE state IS
	
		WHEN RESET =>
			FOR i in 0 to 10 LOOP
				vector(i) <= 0;
			END LOOP;
			state <= WAIT_STATE;
			
		WHEN WAIT_STATE =>
			IF  start_button ='1' THEN
				state <= RUN_PATTERN;
			END IF;
			out_time <= 0;
			
		WHEN RUN_PATTERN =>
				
				IF counter <= 30000000 - speedup THEN --speed up when needed
					counter <= counter + 1;
				ELSE
					color <= random;
					----Assign value to the vector----
					out_time <= out_time + 1;
					IF out_time <= 10 THEN --where variable is stored
						vector(out_time) <= color;
					END IF;
					counter <= 0;
				END IF;				
				
				IF out_time >10 THEN
					state <= PATTERN_CHECK;
				END IF;
				
		WHEN PATTERN_CHECK =>	
			IF reset_button ='1' THEN -- if reset button is triggered
				state <= RESET;
			END IF;
			
			IF NOT started THEN 
				correct <= NOT correct; --set correct to true
				started <= NOT started; -- set started to false (to make sure not get inside this loop again, until failed the pattern_check)
			END IF;
			
			--process : checking num
	
			k := 0;
			IF count_check <= 25000000 THEN
				count_check <= count_check + 1;
			ELSE
				count_check <= 0;	
				IF btn1 = '0' and btn2 ='1' and btn3 ='1' and btn4 ='1' THEN
					k := k + 1;
					IF vector(k) = 0 THEN
						correct <= correct;
					ELSE
						correct <= NOT correct;
					END IF;
				ELSIF btn2 = '0' and btn1 ='1' and btn3 ='1' and btn4 ='1'THEN
					k := k + 1;
					IF vector(k) = 1 THEN
						correct <= correct;
					ELSE
						correct <= NOT correct;
					END IF;
				ELSIF btn3 = '0' and btn2 ='1' and btn1 ='1' and btn4 ='1' THEN
					k := k + 1;
					IF vector(k) = 2 THEN
						correct <= correct;
					ELSE
						correct <= NOT correct;
					END IF;
				ELSIF btn4 = '0' and btn2 ='1' and btn3 ='1' and btn1 ='1'THEN
					k := k + 1;
					IF vector(k) = 3 THEN
						correct <= correct;
					ELSE
						correct <= NOT correct;
					END IF;
				ELSE
					correct <= correct;
				END IF;
				IF k = 11 OR NOT correct THEN
					state <= RESET;
					started <= NOT started;
					IF correct THEN	
						correct <= NOT correct; --back to false if user hits the button 11 times
					END IF;
				END IF;
			END IF;
		END CASE;
	END PROCESS;
	color_temp <= color;
	
	---Show color to board---
	PROCESS(hex,color_temp)
	BEGIN
		IF color_temp = 0 THEN
			hex <= "0000001"; --o
		ELSIF color_temp = 1 THEN
			hex <= "1001111";	--1
		ELSIF color_temp = 2 THEN
			hex <= "0010010"; --2
		ELSIF color_temp = 3 THEN
			hex <= "0000110"; --3
		ELSE
			hex <= "1111111"; --nothing
		END IF;
	END PROCESS;
	LED_hex <= hex; 
	-------------------------
	
	----show led: correct/false-------
	PROCESS(correct)
	BEGIN
		IF correct = true THEN
			ledCorrect <= '1';
			ledWrong <= '0';
		ELSIF correct = false THEN
			ledWrong <= '1';
			ledCorrect <= '0';
		ELSE
			ledWrong <= '0';
			ledCorrect <= '0';
		END IF;
	END PROCESS;
	----------------------------------
	
	----show led: color---------------
	PROCESS(vector(out_time))
	BEGIN
		IF vector(out_time) = 0 THEN
			led0 <= '1';
			led1 <= '0';
			led2 <= '0';
			led3 <= '0';
		ELSIF vector(out_time) = 1 THEN
			led0 <= '0';
			led1 <= '1';
			led2 <= '0';
			led3 <= '0';
		ELSIF vector(out_time) = 2 THEN
			led0 <= '0';
			led1 <= '0';
			led2 <= '1';
			led3 <= '0';
				ELSIF vector(out_time) = 3 THEN
			led0 <= '0';
			led1 <= '0';
			led2 <= '0';
			led3 <= '1';
		END IF;
	END PROCESS;
	
	---Output on monitor--------
	PROCESS(disp_ena, row, column,color,out_time,hex,correct)
	BEGIN
		IF(disp_ena = '1') THEN		--display time
			IF out_time <= 10 THEN --how many times it will run 
				IF(row < 840 AND column < 525) AND color = 0 THEN
					--Yellow block	
					red <= (OTHERS => '1');
					green	<= (OTHERS => '1');
					blue <= (OTHERS => '0');
						
					-- Blue block
				ELSIF((row > 840 AND row < 1680) AND (column < 525)) AND color = 1 THEN
					red <= (OTHERS => '0');
					green	<= (OTHERS => '0');
					blue <= (OTHERS => '1');
						
					--Red block
				ELSIF(row < 840 AND (column > 525 AND column < 1050)) AND color = 2 THEN
					red <= (OTHERS => '1');
					green	<= (OTHERS => '0');
					blue <= (OTHERS => '0');
						
					--Green block
				ELSIF((row > 840 AND row < 1680) AND (column > 525 AND column < 1050)) AND color = 3 THEN
					red <= (OTHERS => '0');
					green	<= (OTHERS => '1');
					blue <= (OTHERS => '0');
						
				ELSE
					red <= (OTHERS => '0');
					green	<= (OTHERS => '0');
					blue <= (OTHERS => '0');
				END IF;
					
	
			ELSE --finish run
				IF correct = true THEN --green screen
					red <= (OTHERS => '0');
					green <= (OTHERS => '1');
					blue <= (OTHERS => '0');
				ELSIF correct = false THEN --red screen
					red <= (OTHERS => '1');
					green <= (OTHERS => '0');
					blue <= (OTHERS => '0');
				ELSE
					red <= (OTHERS => '1');
					green	<= (OTHERS => '1');
					blue <= (OTHERS => '1');
				END IF;
			END IF;
			
		ELSE										--blanking time
			red <= (OTHERS => '0');
			green	<= (OTHERS => '0');
			blue <= (OTHERS => '0');
		END IF;
	END PROCESS;
	
END behavior;