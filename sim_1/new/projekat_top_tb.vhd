library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library xil_defaultlib;
use IEEE.NUMERIC_STD.ALL;


entity projekat_top_tb is
end projekat_top_tb;

architecture Behavioral of projekat_top_tb is
    constant C_CLK_PERIOD : time := 8ns;
    signal clk : std_logic := '0';
    signal reset : std_logic := '0';
    signal start : std_logic := '0';
    signal tx : std_logic;
begin
    
    clk <= not clk after C_CLK_PERIOD/2;
    
    DUT_FULL_PROJ : entity xil_defaultlib.projekat_top
        port map (
            clk => clk,
            reset => reset,
            start => start,
            tx => tx
        );
        
      STIMULUS_PROC : process
      begin 
        reset <= '1';
        wait for 3*C_CLK_PERIOD;
        reset <= '0';
        wait for 2*C_CLK_PERIOD;
        start <= '1';
        wait;
        
      end process;

end Behavioral;
