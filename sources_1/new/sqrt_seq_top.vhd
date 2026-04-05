-- wrapper za sekvencijalnu argitekturu sqrt
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library xil_defaultlib;


entity sqrt_seq_top is
  port (
    clk       : in  std_logic;
    reset     : in  std_logic;

    d_in      : in  std_logic_vector(15 downto 0);
    valid_in  : in  std_logic;

    d_out     : out std_logic_vector(15 downto 0);
    valid_out : out std_logic
  );
end entity;

architecture rtl of sqrt_seq_top is
begin

  U0: entity work.sqrt(Behavioral_sqrt_seq)
    generic map (
      G_IN_BW    => 16,
      G_OUT_BW   => 16,
      G_OUT_FRAC => 8
    )
    port map (
      clk       => clk,
      reset     => reset,
      d_in      => d_in,
      valid_in  => valid_in,
      d_out     => d_out,
      valid_out => valid_out
    );

end architecture;