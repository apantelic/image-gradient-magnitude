library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
library xil_defaultlib;

entity sqrt_pipelined_tb is
end entity;

architecture tb of sqrt_pipelined_tb is

  constant C_IN_BW      : natural := 16;
  constant C_OUT_BW     : natural := 16;
  constant C_OUT_FRAC   : natural := 8;
  constant C_CLK_PERIOD : time    := 10 ns;

  signal clk       : std_logic := '0';
  signal reset     : std_logic := '0';
  signal d_in      : std_logic_vector(C_IN_BW-1 downto 0) := (others => '0');
  signal valid_in  : std_logic := '0';
  signal d_out     : std_logic_vector(C_OUT_BW-1 downto 0);
  signal valid_out : std_logic;

  -- FIFO ZA EXPECTED
  constant QMAX : natural := 70000;

  type t_bv_array is array (0 to QMAX-1) of bit_vector(C_OUT_BW-1 downto 0);
  signal exp_q : t_bv_array := (others => (others => '0'));

  signal q_wr   : natural := 0;
  signal q_rd   : natural := 0;

  signal wr_cnt : natural := 0;
  signal rd_cnt : natural := 0;

  signal started : std_logic := '0';

begin

  clk <= not clk after C_CLK_PERIOD/2;

 
  DUT : entity xil_defaultlib.sqrt(Behavioral_sqrt_pipelined)
    generic map (
      G_IN_BW    => C_IN_BW,
      G_OUT_BW   => C_OUT_BW,
      G_OUT_FRAC => C_OUT_FRAC
    )
    port map (
      clk       => clk,
      reset     => reset,
      d_in      => d_in,
      valid_in  => valid_in,
      d_out     => d_out,
      valid_out => valid_out
    );


  stim_proc : process
    file in_file  : text;
    file ref_file : text;

    variable l_in, l_ref : line;
    variable v_in_vec  : bit_vector(C_IN_BW-1 downto 0);
    variable v_ref_vec : bit_vector(C_OUT_BW-1 downto 0);
  begin
    file_open(in_file,  "sqrt_input.txt",  read_mode);
    file_open(ref_file, "sqrt_output.txt", read_mode);

    -- reset
    reset <= '1';
    valid_in <= '0';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    reset <= '0';
    wait until rising_edge(clk);

    -- slanje svakog takta
    while (not endfile(in_file)) and (not endfile(ref_file)) loop

      readline(in_file, l_in);
      read(l_in, v_in_vec);

      readline(ref_file, l_ref);
      read(l_ref, v_ref_vec);

      assert (wr_cnt - rd_cnt < QMAX-1)
        report "GRESKA: FIFO overflow."
        severity error;

      -- upis expected
      exp_q(q_wr) <= v_ref_vec;
      q_wr   <= (q_wr + 1) mod QMAX;
      wr_cnt <= wr_cnt + 1;

      d_in     <= to_stdlogicvector(v_in_vec);
      valid_in <= '1';

      wait until rising_edge(clk);
    end loop;

    -- stop input
    valid_in <= '0';
    d_in <= (others => '0');

    -- cekaj da pipeline izbaci sve
    while wr_cnt /= rd_cnt loop
      wait until rising_edge(clk);
    end loop;

    report "TEST ZAVRSEN: svi uzorci prosli." severity note;
    wait;
  end process;

 
  upis_proc : process(clk)
    variable exp_now : bit_vector(C_OUT_BW-1 downto 0);
    variable got_now : bit_vector(C_OUT_BW-1 downto 0);
  begin
    if rising_edge(clk) then
      if reset='1' then
        q_rd <= 0;
        rd_cnt <= 0;
        started <= '0';

      else
        if valid_out='1' then
          started <= '1';
        end if;

        if (started='1') and (wr_cnt > rd_cnt) then
          assert (valid_out='1')
            report "GRESKA: valid_out nije kontinuiran."
            severity error;
        end if;

        if valid_out='1' then
          assert (wr_cnt > rd_cnt)
            report "GRESKA: FIFO prazan a valid_out=1."
            severity error;

          exp_now := exp_q(q_rd);
          got_now := to_bitvector(d_out);

          assert (got_now = exp_now)
            report "GRESKA: Dobijeno " & to_hstring(got_now) &
                   ", ocekivano " & to_hstring(exp_now)
            severity error;

          q_rd   <= (q_rd + 1) mod QMAX;
          rd_cnt <= rd_cnt + 1;

          if wr_cnt - rd_cnt = 1 then
            started <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;

end architecture;
