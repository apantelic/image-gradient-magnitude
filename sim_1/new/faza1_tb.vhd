-- prvi test bez top modula 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;

library xil_defaultlib;

entity faza1_tb is
end faza1_tb;

architecture Test of faza1_tb is

  constant G_IMG_W : integer := 8;
  constant G_IMG_H : integer := 8;
  constant G_PIX_W : integer := 8;

  constant C_CLK_PERIOD : time := 10 ns;

  -- signali za interfejs za bram 
  signal clk   : std_logic := '0';
  signal reset : std_logic := '0';
  --  prtB za citanje
  signal addrb : std_logic_vector(5 downto 0) := (others=>'0');
  signal doutb : std_logic_vector(7 downto 0);
  signal enb   : std_logic := '0';
  -- portA za upis
  signal addra : std_logic_vector(5 downto 0) := (others => '0');
  signal dina  : std_logic_vector(7 downto 0) := (others => '0');
  signal wea   : std_logic := '0';

  signal pix_in    : std_logic_vector(G_PIX_W-1 downto 0);
  signal pix_valid : std_logic := '0';
  
  constant G_INIT_FILENAME : string := "C:\Users\User\Documents\VLSI\vlsi_projekat_faza_1\input_img_krug_88.txt";
  constant OUT_FILENAME    : string := "C:\Users\User\Documents\VLSI\vlsi_projekat_faza_1\output_img_krug_88.txt";
  constant G_SQRT_LAT : natural := 16; -- sqrt pipeline latency - pipelined sqrt N = 16 

  -- output signali za window generator
  signal a00,a01,a02,a10,a11,a12,a20,a21,a22 : std_logic_vector(G_PIX_W-1 downto 0);
  signal window_valid : std_logic;
  signal center_addr  : unsigned(5 downto 0);

  -- output signali za sobel_mag_sqrt_compute outputs
  signal mag8_out        : std_logic_vector(7 downto 0);
  signal sobel_valid_out : std_logic;
  signal center_addr_out : unsigned(5 downto 0);
  
begin

  clk <= not clk after C_CLK_PERIOD/2;

  -- BRAM - ciranje svaki takt
  BRAM: entity xil_defaultlib.im_ram
    generic map(
      G_RAM_WIDTH => 8,
      G_RAM_DEPTH => G_IMG_H*G_IMG_W,
      G_RAM_PERFORMANCE => "HIGH_PERFORMANCE",
      G_INIT_FILENAME => G_INIT_FILENAME
    )
    port map(
      -- WRITE port A
      addra  => addra,
      dina   => dina,
      wea    => wea,
      clka   => clk,

      -- READ port B
      addrb  => addrb,
      enb    => enb,
      rstb   => '0',
      regceb => '1',
      doutb  => doutb
    );

  pix_in <= doutb;

  -- window generator
  WIN: entity xil_defaultlib.widnow_gen(Behavioral_circ_buff)
    generic map(
      G_IMG_W => G_IMG_W,
      G_IMG_H => G_IMG_H,
      G_PIX_W => G_PIX_W
    )
    port map(
      clk        => clk,
      reset      => reset,
      pix_in     => pix_in,
      pix_valid  => pix_valid,

      a00 => a00, 
      a01 => a01,
      a02 => a02,
      a10 => a10, 
      a11 => a11, 
      a12 => a12,
      a20 => a20, 
      a21 => a21, 
      a22 => a22,

      window_valid => window_valid,
      center_addr  => center_addr
    );

  -- sobel + magnitude + sqrt
  SOBEL: entity work.sobel_mag_sqrt_compute(Behavioral)
    generic map(
      G_PIX_W    => G_PIX_W,
      G_ADDR_W   => 6,
      G_SQRT_LAT => G_SQRT_LAT + 1
    )
    port map(
      clk   => clk,
      reset => reset,

      a00 => a00,
      a01 => a01,
      a02 => a02,
      a10 => a10, 
      a11 => a11, 
      a12 => a12,
      a20 => a20, 
      a21 => a21, 
      a22 => a22,

      window_valid   => window_valid,
      center_addr_in => center_addr,

      mag8_out        => mag8_out,
      valid_out       => sobel_valid_out,
      center_addr_out => center_addr_out
    );

  -- BRAM read high performance
  STIMULUS : process
    variable addr : unsigned(5 downto 0) := (others => '0');
  begin
    reset <= '1';
    enb <= '0';
    pix_valid <= '0';
    wait for 2*C_CLK_PERIOD;

    reset <= '0';
    enb <= '1';

    -- 2 takta punjenje BRAM read pipeline
    addrb <= std_logic_vector(addr);
    addr := addr + 1;
    wait until rising_edge(clk);

    -- ciklus 1: addr=1
    addrb <= std_logic_vector(addr);
    addr := addr + 1;
    wait until rising_edge(clk);

    -- od ciklusa 2: doutb validan -> pix_valid=1
    pix_valid <= '1';

    for i in 2 to G_IMG_H*G_IMG_W-1 loop
      addrb <= std_logic_vector(addr);
      addr := addr + 1;
      wait until rising_edge(clk);
    end loop;
    
    -- drain za bram jos 2 takta 
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    
    pix_valid <= '0';
    
    
    -- drain: cekaj da pipeline izbaci rezultate
    for k in 0 to (2 + (G_SQRT_LAT+1) + 5) loop
      wait until rising_edge(clk);
    end loop;
    wait;
  end process;

  -- U ISTOM TAKTU kada sobel_valid_out=1: upis u RAM + upis u fajl
    WRITEBACK_AND_DUMP : process(clk)
    file f_out : text open write_mode is OUT_FILENAME;
    variable L : line;
    variable bv : bit_vector(7 downto 0);
  begin
    if rising_edge(clk) then
      if reset='1' then
        wea   <= '0';
        addra <= (others => '0');
        dina  <= (others => '0');
      else
        wea <= '0';

        if sobel_valid_out='1' then
          -- 1) upis u RAM (overwrite)
          addra <= std_logic_vector(center_addr_out);
          dina  <= mag8_out;
          wea   <= '1';

          -- 2) upis u fajl (isti trenutak)
          bv := to_bitvector(mag8_out);
          write(L, bv);
          writeline(f_out, L);
        end if;
     end if;
    end if;
  end process;
end architecture;