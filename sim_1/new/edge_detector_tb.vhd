library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library xil_defaultlib;

entity edge_detector_tb is
end edge_detector_tb;

architecture Behavioral of edge_detector_tb is

constant C_CLK_PERIOD : time := 125 ms;  -- 8 Hz - lakse za test
signal clk : std_logic := '0';
signal reset : std_logic := '1';
signal btn_start : std_logic := '0';
signal edge : std_logic := '0';

begin

DUT: entity xil_defaultlib.edge_detector
    generic map(
        DEB_CYCLES => 16   -- 2s deb time - 2 s * 8 Hz = 16
    )
    port map( 
        clk => clk,
        reset => reset,
        btn_start => btn_start,
        edge => edge
    );

clk <= not clk after C_CLK_PERIOD/2;

STIMULUS_PROC : process
begin 

wait for 5*C_CLK_PERIOD;
reset <= '0';
wait for C_CLK_PERIOD;
btn_start <= '1';
wait for 30*C_CLK_PERIOD;
btn_start <= '0';
wait;



end process;



end Behavioral;