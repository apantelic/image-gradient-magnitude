library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library xil_defaultlib;

entity uart_tb is
end uart_tb;

architecture Behavioral of uart_tb is
    constant G_IMG_W : integer := 8;
    constant G_IMG_H : integer := 8;
    constant C_DEPTH : integer := G_IMG_W*G_IMG_H;
    constant G_ADDR_W : integer := 6;

    constant C_CLK_PERIOD : time := 8 ns; -- 250 MHz
    constant C_BRAM_LAT   : natural := 2; 

    signal clk  : std_logic := '0';
    signal reset : std_logic := '1';

    -- BRAM
    signal doutb : std_logic_vector(7 downto 0);
    constant G_INIT_FILENAME: string := "C:\Users\User\Documents\VLSI\vlsi_projekat_faza_1\input_img_krug_88.txt"; --"cameramann.dat";

    -- UART
    signal tx : std_logic;
    signal rd_addr : std_logic_vector(G_ADDR_W-1 downto 0);
    signal transfer_active : std_logic := '0';
    signal transfer_done : std_logic := '0';
    signal start_transfer : std_logic := '0';

    -- receiver bookkeeping
begin
    -- clock
    clk <= not clk after C_CLK_PERIOD/2;

    -- BRAM instance
    BRAM: entity xil_defaultlib.im_ram
        generic map(
          G_RAM_WIDTH => 8,
          G_RAM_DEPTH => C_DEPTH,
          G_RAM_PERFORMANCE => "HIGH_PERFORMANCE",
          G_INIT_FILENAME => G_INIT_FILENAME
        )
        port map(
          addra  => (others=>'0'),
          dina   => (others=>'0'),
          wea    => '0',
          clka   => clk,

          addrb  => rd_addr,
          enb    => '1',
          rstb   => '0',
          regceb => '1',
          doutb  => doutb
        );

    
    UART_TRANSFER: entity xil_defaultlib.uart_sender
        generic map(
           CLK_FREQ => 125, -- MHz 
           SER_FREQ => 115200,
           ADDR_W => G_ADDR_W,
           DEPTH => C_DEPTH,
           BRAM_LAT => C_BRAM_LAT
        )
        port map(
           clk => clk,
           reset => reset,
           start_transfer => start_transfer,
           mem_addr  => rd_addr,
           mem_rdata => doutb,
           tx => tx,
           par_en   => '0',
           transfer_active => transfer_active,
           transfer_done => transfer_done
        );

    STIMULUS_PROC : process
    begin
    
    reset <= '1';
    wait for 2*C_CLK_PERIOD;
    reset <= '0';
    wait for 2*C_CLK_PERIOD;
    start_transfer <= '1';
    wait for 4*C_CLK_PERIOD;
    start_transfer <= '0';
    
    
    
    wait;
    end process;
   

   

end Behavioral;