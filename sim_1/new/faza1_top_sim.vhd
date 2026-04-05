library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;

library xil_defaultlib;

entity faza1_top_sim is
end faza1_top_sim;

architecture Behavioral of faza1_top_sim is
  constant C_CLK_PERIOD : time := 8 ns;

  signal clk       : std_logic := '0';
  signal reset     : std_logic := '1';
  signal start     : std_logic := '0';
  signal dout      : std_logic_vector(7 downto 0);
  signal valid_out : std_logic;

  constant OUT_FILENAME : string :=
    "C:\Users\User\Documents\VLSI\vlsi_projekat_faza_1\output_img_krug_88_top.txt"; --output_img_cameraman_top.txt";

  constant EXPECTED_CNT : integer := 6*6; 

  signal wr_count : integer := 0;
begin

  clk <= not clk after C_CLK_PERIOD/2;

  DUT_FAZA1 : entity xil_defaultlib.faza1_top
    port map (
      reset     => reset,
      clk       => clk,
      start     => start,
      dout      => dout,
      valid_out => valid_out
    );

 
  STIMULUS : process
  constant TIMEOUT_CYC : integer := 250000; 
  begin
   
    reset <= '1';
    start <= '0';
    for i in 1 to 5 loop
      wait until rising_edge(clk);
    end loop;
    reset <= '0';
    wait until rising_edge(clk);

    start <= '1';
    wait for 2*C_CLK_PERIOD;
    start <= '0';

    for k in 0 to TIMEOUT_CYC loop
      wait until rising_edge(clk);
      exit when wr_count = EXPECTED_CNT;
    end loop;

    wait;
   end process;

    
  UPIS_U_TXT : process(clk)
    file f_out : text open write_mode is OUT_FILENAME;
    variable L  : line;
    variable bv : bit_vector(7 downto 0);
  begin
    if rising_edge(clk) then
      if reset = '1' then
        wr_count <= 0;
      else
        if valid_out = '1' then
          bv := to_bitvector(dout);
          write(L, bv);
          writeline(f_out, L);
          wr_count <= wr_count + 1;
        end if;
      end if;
    end if;
  end process;

end Behavioral;
