library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.textio.all;
library xil_defaultlib;

entity sqrt_tb is
end sqrt_tb;

architecture Test of sqrt_tb is

    -- Podesi ove konstante prema svom projektu
    constant C_IN_BW    : integer := 16; -- Broj bita ulaza
    constant C_OUT_BW   : integer := 16; -- Broj bita izlaza
    constant C_OUT_FRAC : integer := 8; -- Broj bita za razlomljeni deo izlaza
    constant C_CLK_PERIOD : time := 10 ns;

    -- Signali za interfejs
    signal clk       : std_logic := '1';
    signal reset     : std_logic := '0';
    signal d_in      : std_logic_vector(C_IN_BW-1 downto 0) := (others => '0');
    signal valid_in  : std_logic := '0';
    signal d_out     : std_logic_vector(C_OUT_BW-1 downto 0);
    signal valid_out : std_logic := '0';
    -- Ocekivana vrednost procitana iz fajla
    signal d_out_exp : std_logic_vector(C_OUT_BW-1 downto 0);
    
begin

    -- Generisanje takta
    clk <= not clk after C_CLK_PERIOD/2;

    -- DUMMY MODEL: Simulira modul korena - potrebno ga je zameniti instancom
    -- realiyovane hardverske komponente
    DUT : entity xil_defaultlib.sqrt(Behavioral_sqrt_seq)
        generic map(
            G_IN_BW    => C_IN_BW,
            G_OUT_BW   => C_OUT_BW,
            G_OUT_FRAC => C_OUT_FRAC
        )
        port map(
            clk       => clk,
            reset     => reset,
            d_in      => d_in,
            valid_in  => valid_in,
            d_out     => d_out,
            valid_out => valid_out
        );

    ---------------------------------------------------------------------------
    -- TEST PROCES: Cita fajlove i proverava rezultate
    ---------------------------------------------------------------------------
    stim_proc: process
        file in_file  : text;
        file ref_file : text;
        variable v_in_line, v_ref_line : line;
        variable v_in_vec  : bit_vector(C_IN_BW-1 downto 0);
        variable v_ref_vec : bit_vector(C_OUT_BW-1 downto 0);
    begin
        -- ne zaboravite da dodate fajlove kao Simulation Sources
        file_open(in_file, "sqrt_input.txt", read_mode);
        file_open(ref_file, "sqrt_output.txt", read_mode);
        -- Inicijalni reset
        reset <= '1';
        wait for C_CLK_PERIOD*2;
        reset <= '0';
        wait for C_CLK_PERIOD*2;

        while not endfile(in_file) loop
            -- Citanje iz fajlova
            report "Loop entered" severity note;

            readline(in_file, v_in_line);
            report "Input line read" severity note;
            read(v_in_line, v_in_vec);
            report "Input parsed" severity note;

            
            readline(ref_file, v_ref_line);
            read(v_ref_line, v_ref_vec);

            -- Slanje podataka dummy modelu
            d_in     <= to_stdlogicvector(v_in_vec);
            valid_in <= '1';
            wait for C_CLK_PERIOD*2; -- moze i duze, prema tekstu zadatka
            valid_in <= '0';

            -- Cekanje na odgovor
            wait until valid_out = '1';
            
            -- konverzija ocekivane vrednosti
            d_out_exp <= to_stdlogicvector(v_ref_vec);
            -- Provera
            wait for 0 ns; -- forsiranje azuriranja signala
            assert (d_out = d_out_exp) -- desice se ako su rezultati razliciti i ispisace se greska u konzoli
                report "GRESKA: Dobijeno " & to_hstring(to_bitvector(d_out)) & 
                       ", ocekivano " & to_hstring(v_ref_vec)
                severity error;
            
            wait for C_CLK_PERIOD;
        end loop;
        wait;
    end process;
    

end Test;
