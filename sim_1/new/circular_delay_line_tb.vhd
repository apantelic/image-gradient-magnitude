library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library xil_defaultlib;


entity circular_delay_line_tb is
end circular_delay_line_tb;

architecture Test of circular_delay_line_tb is
    constant G_LINE_DEPTH : natural := 5;
    constant G_DATA_WIDTH : natural := 8;
    constant C_CLK_PERIOD : time := 10ns;
    constant G_IMG_W    : integer := 8; -- sirina slike
    constant G_IMG_H   : integer := 8; -- visina slike 
    
    -- Signali za interfejs modula circular_delay_line
    signal line_data_out : std_logic_vector(G_DATA_WIDTH-1 downto 0);
    signal reset : std_logic := '1';
    signal clk : std_logic := '1';
    signal enb : std_logic := '0';
    
    -- Signali za interfejs - BRAM   
    signal addrb : std_logic_vector(5 downto 0) := (others=>'0');
    signal doutb : std_logic_vector(7 downto 0);
    signal enb_line   : std_logic := '0';
    constant G_INIT_FILENAME: string := "input_img_krug_88.txt";
begin
    BRAM: entity xil_defaultlib.im_ram
        generic map(
          G_RAM_WIDTH => 8,
          G_RAM_DEPTH => G_IMG_H*G_IMG_W,
          G_RAM_PERFORMANCE => "HIGH_PERFORMANCE",
          G_INIT_FILENAME => G_INIT_FILENAME
        )
        port map(
          addra  => (others=>'0'), 
          dina   => (others=>'0'),
          wea    => '0',
          clka   => clk,
    
          addrb  => addrb,
          enb    => enb,
          rstb   => '0',
          regceb => '1',
          doutb  => doutb
        );
        
    DUT: entity xil_defaultlib.circular_delay_line(Behavioral)
        generic map (
            G_LINE_DEPTH => G_LINE_DEPTH,
            G_DATA_WIDTH => G_DATA_WIDTH
        )
        port map (
            clk => clk,
            reset => reset,
            enb => enb_line,
            line_data_in => doutb,
            line_data_out => line_data_out
        );

    clk <= not clk after C_CLK_PERIOD/2;
    
    STIMULUS : process
      variable addr : unsigned(5 downto 0) := (others => '0');
    begin 
    
      reset <= '1';
      wait for 2*C_CLK_PERIOD;
      reset <= '0';
      enb <= '1';
   
       -- pipelining: prvih 2 takta samo postavljam adrese za  RAM pipeline
      -- ciklus 0: addr=0
      addrb <= std_logic_vector(addr);
      addr := addr + 1;
      wait until rising_edge(clk);
    
      -- ciklus 1: naruči addr=1
      addrb <= std_logic_vector(addr);
      addr := addr + 1;
      wait until rising_edge(clk);
    
      -- od ciklusa 2: doutb je validan (za addr=0), pa valid=1
      enb_line <= '1';
    
      -- sada šalješ preostale adrese, svaku ivicu
      for i in 2 to G_IMG_H*G_IMG_W-1 loop
        addrb <= std_logic_vector(addr);
        addr := addr + 1;
        wait until rising_edge(clk);
      end loop;
    
      -- posle poslednje adrese još 2 takta izlazi drain-uju pipeline
      -- da window_gen dobije i poslednja 2 piksela
      wait until rising_edge(clk);
      wait until rising_edge(clk);
    
      enb_line <= '0';
      wait;
    
    end process;

end Test;
