library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library xil_defaultlib;

entity uart_org_img_send is
    port (
        clk : in std_logic;
        reset : in std_logic;
        start_uart : in std_logic;
        tx : out std_logic
    );
end uart_org_img_send;

architecture Behavioral of uart_org_img_send is
    constant G_IMG_W : integer := 8;
    constant G_IMG_H : integer := 8;
    constant C_DEPTH : integer := G_IMG_W*G_IMG_H;
    constant G_ADDR_W : integer := 6;
    constant C_BRAM_LAT   : natural := 2; 
    
    -- BRAM
    signal doutb : std_logic_vector(7 downto 0);
    constant G_INIT_FILENAME: string := "C:\Users\User\Documents\VLSI\vlsi_projekat_faza_1\input_img_krug_88.txt"; --"cameramann.dat";

    -- UART
    
    signal rd_addr : std_logic_vector(G_ADDR_W-1 downto 0);
    signal transfer_active : std_logic := '0';
    signal transfer_done : std_logic := '0';
    signal start_transfer : std_logic := '0';
begin
    
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

end Behavioral;
