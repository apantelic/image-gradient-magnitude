library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;
use xil_defaultlib.RAM_definitions_PK.all;  -- zbog clogb2

entity circular_delay_line is
  generic (
    G_LINE_DEPTH : natural := 253;
    G_DATA_WIDTH : natural := 8
  );
  port (
    clk           : in  std_logic;
    reset         : in  std_logic;
    enb           : in  std_logic;  -- ovde ti ide pix_valid
    line_data_in  : in  std_logic_vector(G_DATA_WIDTH-1 downto 0); -- pix_in
    line_data_out : out std_logic_vector(G_DATA_WIDTH-1 downto 0)
  );
end entity;

-- PROBELM SA OVOM ARHITEKTUROM GENERISE MI BRAM 
architecture Behavioral of circular_delay_line is
    type line_mem_t is array (0 to G_LINE_DEPTH-1) of std_logic_vector(G_DATA_WIDTH-1 downto 0);
    
    signal circ_buff : line_mem_t := (others => (others => '0'));
    signal mem_ptr   : unsigned((clogb2(G_LINE_DEPTH)-1) downto 0) := (others => '0');
    signal dout_reg  : std_logic_vector(G_DATA_WIDTH-1 downto 0) := (others => '0');
begin
    line_data_out <= dout_reg;
    
    DATA_BUFFERING_LOGIC : process(clk)
    begin
    
    if rising_edge(clk) then
      if reset = '1' then
        mem_ptr  <= (others => '0');
        dout_reg <= (others => '0');
      else
        if enb = '1' then
    
          -- read old value (delayed sample)
          dout_reg <= circ_buff(to_integer(mem_ptr));
    
          -- write new value at same place
          circ_buff(to_integer(mem_ptr)) <= line_data_in;
    
          -- increment pointer with wrap
          if mem_ptr = to_unsigned(G_LINE_DEPTH-1, mem_ptr'length) then
            mem_ptr <= (others => '0');
          else
            mem_ptr <= mem_ptr + 1;
          end if;
        end if;
      end if;
    end if;
    end process;
end architecture;

-- SINTETISE NIZ FF 
architecture Behavioral_shiftreg of circular_delay_line is
    type shreg_t is array (0 to G_LINE_DEPTH-1) of std_logic_vector(G_DATA_WIDTH-1 downto 0);
    
    signal sh       : shreg_t := (others => (others => '0'));
    signal dout_reg : std_logic_vector(G_DATA_WIDTH-1 downto 0) := (others => '0');
begin

    line_data_out <= dout_reg;
    
    SHIFTING: process(clk)
    begin
    if rising_edge(clk) then
       if reset = '1' then
          sh <= (others => (others => '0'));
          dout_reg <= (others => '0');
       elsif enb = '1' then
          -- izlaz uzmi pre shift-a - kao FIFO
          dout_reg <= sh(G_LINE_DEPTH-1);
    
          -- shift
          for i in G_LINE_DEPTH-1 downto 1 loop
             sh(i) <= sh(i-1);
          end loop;
          
          sh(0) <= line_data_in;
       end if;
    end if;
    end process;
end architecture;