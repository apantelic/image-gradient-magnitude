library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.textio.all;
library xil_defaultlib;

entity widnow_gen_tb is
end widnow_gen_tb;

architecture Test of widnow_gen_tb is
    constant G_IMG_W    : integer := 8; -- sirina slike 
    constant G_IMG_H   : integer := 8; -- visina slike 
    constant G_PIX_W : integer := 8; -- Broj bita jednog piksela
    constant C_CLK_PERIOD : time := 10 ns;

    -- Signali za interfejs window_gen
    signal clk       : std_logic := '1';
    signal reset     : std_logic := '0';
    signal pix_in    : std_logic_vector(G_PIX_W-1 downto 0);
    signal pix_valid : std_logic := '0';
    signal a00 :  std_logic_vector(G_PIX_W-1 downto 0);
    signal a01 :  std_logic_vector(G_PIX_W-1 downto 0);
    signal a02 :  std_logic_vector(G_PIX_W-1 downto 0);
    signal a10 :  std_logic_vector(G_PIX_W-1 downto 0);
    signal a11 :  std_logic_vector(G_PIX_W-1 downto 0);
    signal a12 :  std_logic_vector(G_PIX_W-1 downto 0);
    signal a20 :  std_logic_vector(G_PIX_W-1 downto 0);
    signal a21 :  std_logic_vector(G_PIX_W-1 downto 0);
    signal a22 :  std_logic_vector(G_PIX_W-1 downto 0);
    signal window_valid : std_logic := '0';
    signal center_addr  :  unsigned(5 downto 0);  
    
    -- Signali za interfejs - BRAM   
    signal addrb : std_logic_vector(5 downto 0) := (others=>'0');
    signal doutb : std_logic_vector(7 downto 0);
    signal enb   : std_logic := '0';
    constant G_INIT_FILENAME: string := "input_img_krug_88.txt";

begin

    -- Generisanje takta
    clk <= not clk after C_CLK_PERIOD/2;

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
    
    pix_in <= doutb;
  
    DUT1 : entity xil_defaultlib.widnow_gen(Behavioral_circ_buff)
        generic map(
            G_IMG_W     => G_IMG_W,
            G_IMG_H     => G_IMG_H,
            G_PIX_W     => G_PIX_W
        )
        port map(
            clk        => clk,
            reset      => reset,
            pix_in     => pix_in,
            pix_valid  => pix_valid,
            a00        => a00,
            a01        => a01,
            a02        => a02,
            a10        => a10,
            a11        => a11,
            a12        => a12,
            a20        => a20,
            a21        => a21,
            a22        => a22,
            window_valid => window_valid,
            center_addr => center_addr
        );

    -- 3) STIM: adresa + valid
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
      pix_valid <= '1';
    
      -- saljemo preostale adrese, svaku ivicu
      for i in 2 to G_IMG_H*G_IMG_W-1 loop
        addrb <= std_logic_vector(addr);
        addr := addr + 1;
        wait until rising_edge(clk);
      end loop;
    
      -- posle poslednje adrese još 2 takta izlazi drain-uju pipeline
      -- da window_gen dobije i poslednja 2 piksela
      wait until rising_edge(clk);
      wait until rising_edge(clk);
    
      pix_valid <= '0';
      wait;
    
      end process;

end architecture;
