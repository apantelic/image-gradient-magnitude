-- delay-line ima definisan izlaz posle reset-a (kod tebe ima, preko dout_reg), i
-- ostatak sistema gleda prozor samo kad je window_valid=1.
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library xil_defaultlib;
use xil_defaultlib.RAM_definitions_PK.all;

entity widnow_gen is
generic (
    G_IMG_W : natural := 256;
    G_IMG_H : natural := 256;
    G_PIX_W  : natural := 8
  );
  port (
    clk   : in  std_logic;
    reset : in  std_logic;

    pix_in    : in  std_logic_vector(G_PIX_W-1 downto 0);
    pix_valid : in  std_logic;

    -- 3x3 window (a00 a01 a02; a10 a11 a12; a20 a21 a22)
    a00 : out std_logic_vector(G_PIX_W-1 downto 0);
    a01 : out std_logic_vector(G_PIX_W-1 downto 0);
    a02 : out std_logic_vector(G_PIX_W-1 downto 0);
    a10 : out std_logic_vector(G_PIX_W-1 downto 0);
    a11 : out std_logic_vector(G_PIX_W-1 downto 0);
    a12 : out std_logic_vector(G_PIX_W-1 downto 0);
    a20 : out std_logic_vector(G_PIX_W-1 downto 0);
    a21 : out std_logic_vector(G_PIX_W-1 downto 0);
    a22 : out std_logic_vector(G_PIX_W-1 downto 0);

    window_valid : out std_logic;

    -- address of CENTER pixel (E) = (row-1,col-1)
    center_addr  : out unsigned(clogb2(G_IMG_W*G_IMG_H)-1 downto 0)  -- za 256x256
  );
end widnow_gen;

architecture Behavioral_full_lb of widnow_gen is
  subtype pix_t is std_logic_vector(G_PIX_W-1 downto 0);
  type line_t is array(0 to G_IMG_W-1) of pix_t;

  -- Full-row line buffers
  signal line1 : line_t := (others => (others => '0')); -- row-1
  signal line2 : line_t := (others => (others => '0')); -- row-2
  
  signal col : integer range 0 to G_IMG_W-1  := 0;
  signal row : integer range 0 to G_IMG_H-1 := 0;
  
  -- 3 shift regs za sva tri reda
  signal top0, top1, top2 : pix_t := (others => '0'); -- row-2 
  signal mid0, mid1, mid2 : pix_t := (others => '0'); -- row-1
  signal bot0, bot1, bot2 : pix_t := (others => '0'); -- row

  signal window_valid_reg : std_logic := '0';
  signal center_addr_reg : unsigned(clogb2(G_IMG_W*G_IMG_H)-1 downto 0) := (others => '0');

begin

  a00 <= top2; a01 <= top1; a02 <= top0;
  a10 <= mid2; a11 <= mid1; a12 <= mid0;
  a20 <= bot2; a21 <= bot1; a22 <= bot0;

  window_valid <= window_valid_reg;
  center_addr  <= center_addr_reg;

  WINDOW_UPDATE_LOGIC : process(clk)
    variable p1_v, p2_v : pix_t;
    variable addr_center : natural;
  begin
    if rising_edge(clk) then
      if reset = '1' then
        top0 <= (others => '0'); top1 <= (others => '0'); top2 <= (others => '0');
        mid0 <= (others => '0'); mid1 <= (others => '0'); mid2 <= (others => '0');
        bot0 <= (others => '0'); bot1 <= (others => '0'); bot2 <= (others => '0');
        window_valid_reg <= '0';
--        center_addr_reg <= (others => '0'); - sto bih resetovala dataregistre kad svakako sve sto se desava kasnije ceka valid
      else
        window_valid_reg <= '0';

        if pix_valid = '1' then
          -- pamtimo prethodne vrednosti line-buffer-a trenutne kolone
          p1_v := line1(col); -- (row-1, col)
          p2_v := line2(col); -- (row-2, col)

          -- SHIFT horizontal (3-pixel prozor) - sa vrednostima line-buffer-a trenutne kolone i novim pikselom 
          bot2 <= bot1; bot1 <= bot0; bot0 <= pix_in;
          mid2 <= mid1; mid1 <= mid0; mid0 <= p1_v;
          top2 <= top1; top1 <= top0; top0 <= p2_v;

          --  UPDATE line buffers posle toga
          line2(col) <= line1(col);
          line1(col) <= pix_in;

          --  VALID: kad smo primili piksel (row,col), centar prozora je (row-1,col-1)
          if (row >= 2) and (col >= 2) then
            window_valid_reg <= '1';
            addr_center := (row-1)*G_IMG_W + (col-1);
            center_addr_reg <= to_unsigned(addr_center, center_addr_reg'length);
          end if;
        end if;
      end if;
    end if;
  end process WINDOW_UPDATE_LOGIC;
  
  -- u simulaciji izgleda kao da center_addr kasni za col i row , jer su counter i window_update odvojeni procesi 
  -- i onda na isti rising edge window update kosristi stare row/col, ali counter_row_col azurira col i row i njih prikazuje 
  COUNTER_ROW_COL : process(clk) is
  begin
  if rising_edge(clk) then 
      if reset='1'then 
        col <= 0;
        row <= 0;
      elsif pix_valid = '1' then 
        if col = G_IMG_W-1 then
            col <= 0;
            if row = G_IMG_H-1 then
               row <= 0;
            else
               row <= row + 1;
            end if;
        else
            col <= col + 1;
        end if;
      end if;
  end if;
  end process COUNTER_ROW_COL;

end Behavioral_full_lb;

-- ARHITEKTURA SA shift reg-om KOJI JE SIRINE IMG_WIDTH - 3
architecture Behavioral_circ_buff of widnow_gen is
    subtype pix_t is std_logic_vector(G_PIX_W-1 downto 0);
    
    signal col : integer range 0 to G_IMG_W-1 := 0;
    signal row : integer range 0 to G_IMG_H-1 := 0;
    
    signal top0, top1, top2 : pix_t := (others => '0');
    signal mid0, mid1, mid2 : pix_t := (others => '0');
    signal bot0, bot1, bot2 : pix_t := (others => '0');
    
    signal window_valid_reg : std_logic := '0';
    signal center_addr_reg  : unsigned(clogb2(G_IMG_W*G_IMG_H)-1 downto 0) := (others => '0');
    
    signal line1_out, line2_out : pix_t := (others => '0');
begin
    -- mapiranje 3x3 prozora 
    a00 <= top0; a01 <= top1; a02 <= top2;
    a10 <= mid0; a11 <= mid1; a12 <= mid2;
    a20 <= bot0; a21 <= bot1; a22 <= bot2;
    
    window_valid <= window_valid_reg;
    center_addr  <= center_addr_reg;

  
    LINE1: entity xil_defaultlib.circular_delay_line(Behavioral_shiftreg)
        generic map (
          G_LINE_DEPTH => G_IMG_W - 3,
          G_DATA_WIDTH => G_PIX_W
        )
        port map (
          clk           => clk,
          reset         => reset,
          enb           => pix_valid,
          line_data_in  => bot1,
          line_data_out => line1_out
        );
    
    LINE2: entity xil_defaultlib.circular_delay_line(Behavioral_shiftreg)
        generic map (
          G_LINE_DEPTH => G_IMG_W - 3,
          G_DATA_WIDTH => G_PIX_W
        )
        port map (
          clk           => clk,
          reset         => reset,
          enb           => pix_valid,
          line_data_in  => mid1,
          line_data_out => line2_out
        );
    
    WINDOW_GEN_PROC: process(clk)
    variable addr_center : natural;
    begin
    if rising_edge(clk) then
       if reset = '1' then
          top0 <= (others => '0'); top1 <= (others => '0'); top2 <= (others => '0');
          mid0 <= (others => '0'); mid1 <= (others => '0'); mid2 <= (others => '0');
          bot0 <= (others => '0'); bot1 <= (others => '0'); bot2 <= (others => '0');
    
          window_valid_reg <= '0';
          center_addr_reg  <= (others => '0');
          col <= 0;
          row <= 0;
       else
          window_valid_reg <= '0';
    
          if pix_valid = '1' then
             -- shift donjeg reda (trenutni red)
             bot2 <= pix_in;
             bot1 <= bot2;
             bot0 <= bot1;
    
            -- shift srednjeg reda (row-1) - ulaz je line1_out
             mid2 <= line1_out;
             mid1 <= mid2;
             mid0 <= mid1;
    
             -- shift gornjeg reda (row-2) - ulaz je line2_out
             top2 <= line2_out;
             top1 <= top2;
             top0 <= top1;
    
             -- valid + adresa centra (row-1, col-1)
             if (row >= 2) and (col >= 2) then
                window_valid_reg <= '1';
                addr_center := (row-1)*G_IMG_W + (col-1);
                center_addr_reg <= to_unsigned(addr_center, center_addr_reg'length);
             end if;
    
             -- update countera kolona i redova 
             if col = G_IMG_W-1 then
                col <= 0;
                if row = G_IMG_H-1 then
                   row <= 0;
                else
                   row <= row + 1;
                end if;
             else
               col <= col + 1;
             end if;
         end if;
      end if;
    end if;
    end process;
end Behavioral_circ_buff;