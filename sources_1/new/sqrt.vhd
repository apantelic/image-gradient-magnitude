library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sqrt is
  generic (
    G_IN_BW    : natural := 16;
    G_OUT_BW   : natural := 16;
    G_OUT_FRAC : natural := 8
  );
  port (
    clk       : in  std_logic;
    reset     : in  std_logic; 
    d_in      : in  std_logic_vector(G_IN_BW-1 downto 0);
    valid_in  : in  std_logic;
    d_out     : out std_logic_vector(G_OUT_BW-1 downto 0);
    valid_out : out std_logic
  );
end entity;

-- SEKVENCIJALNA MREZA
architecture Behavioral_sqrt_seq of sqrt is

  type state_t is (st_Idle, st_Run);
  signal state_reg, next_state : state_t := st_Idle;

  constant N     : natural := G_OUT_BW;
  constant SRC_W : natural := 2*N;
  constant REM_W : natural := N + 2;      -- bezbedno (moze i N+1)
  constant TMP_W : natural := REM_W + 2;  -- zbog shiftovanje ostatka

  signal src_reg,  src_next  : unsigned(SRC_W-1 downto 0) := (others => '0');
  signal rem_reg,  rem_next  : unsigned(REM_W-1 downto 0) := (others => '0');
  signal root_reg, root_next : unsigned(N-1 downto 0)     := (others => '0');
  signal iter_reg, iter_next : natural range 0 to N       := 0;
  signal valid_out_reg, valid_out_next : std_logic        := '0';

  -- posle reseta cekamo da valid_in postane 0 bar jednom
  signal din_ok_after_rst_reg, din_ok_after_rst_next :  std_logic := '0';   

begin
  -- izlaz se update-uje kad se promeni root_reg
  -- izlaz postaje validan tek kada valid_out = 1
  d_out     <= std_logic_vector(root_reg);
  valid_out <= valid_out_reg;

  -- SEKVENCIJALNI proces: upis u registre na ulaznu ivicu clk-a
  TRANSITION_LOGIC : process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        state_reg     <= st_Idle;
        src_reg       <= (others => '0');
        rem_reg       <= (others => '0');
        root_reg      <= (others => '0');
        iter_reg      <= 0;
        valid_out_reg <= '0';
        din_ok_after_rst_reg <= '0';    
      else
        state_reg     <= next_state;
        src_reg       <= src_next;
        rem_reg       <= rem_next;
        root_reg      <= root_next;
        iter_reg      <= iter_next;
        valid_out_reg <= valid_out_next;
        din_ok_after_rst_reg <= din_ok_after_rst_next;

      end if;
    end if;
  end process TRANSITION_LOGIC;

  -- KOMBINACIONI proces: next stanje i next registri
  COMB_LOGIC : process(state_reg,iter_reg,valid_in,din_ok_after_rst_reg)
    variable next2dig    : unsigned(1 downto 0);
    variable rem_tmp    : unsigned(TMP_W-1 downto 0);
    variable trial    : unsigned(TMP_W-1 downto 0);
    variable root_new : unsigned(N-1 downto 0);
  begin
    -- default: dzi vrednosti 
    next_state     <= state_reg;
    src_next       <= src_reg;
    rem_next       <= rem_reg;
    root_next      <= root_reg;
    iter_next      <= iter_reg;
    valid_out_next <= '0'; 
    din_ok_after_rst_next <= din_ok_after_rst_reg;

    next2dig    := (others => '0');
    rem_tmp    := (others => '0');
    trial    := (others => '0');
    root_new := root_reg;
    
    if din_ok_after_rst_reg = '0' then 
        if valid_in = '0' then 
           din_ok_after_rst_next <= '1';
        end if;
    end if;
    
    case state_reg is

      when st_Idle =>
        -- prihvati ulaz samo kad si spreman
        if (valid_in = '1') and (din_ok_after_rst_reg = '1') then
          src_next  <= shift_left(resize(unsigned(d_in), SRC_W), 2*G_OUT_FRAC);
          rem_next  <= (others => '0');
          root_next <= (others => '0');
          iter_next <= 0;
          next_state <= st_Run;
        end if;

      when st_Run =>
        -- uzmi 2 bita sa MSB
        next2dig := src_reg(src_reg'high downto src_reg'high-1);

        -- trenutni ostatak - shifftujemo za 2 mesta ulevo i dodajemo nove dve  cifre
        rem_tmp := shift_left(resize(rem_reg, TMP_W), 2);
        rem_tmp(1 downto 0) := next2dig;

        -- trial za odluku da li je sledeci bit 0 ili 1
        trial := shift_left(resize(root_reg, TMP_W), 2) + 1;

        -- odluka bita
        if rem_tmp >= trial then
          rem_next    <= resize(rem_tmp - trial, REM_W);
          root_new  := (root_reg sll 1) + 1;
        else
          rem_next    <= resize(rem_tmp, REM_W);
          root_new  := (root_reg sll 1);
        end if;

        root_next <= root_new;
        src_next  <= shift_left(src_reg, 2);   -- za sledecu iter

        if iter_reg = N-1 then
          --  valid_out=1 jedan takt i odmah nazad u Idle
          valid_out_next <= '1';
          next_state     <= st_Idle;
          -- iter_next moze ostati kako jeste, ali je nekako cistije resetovati ga
          iter_next      <= 0;
        else
          iter_next <= iter_reg + 1;
        end if;

    end case;
  end process COMB_LOGIC;
end architecture;

-- PAJPLAJNOVANA ARHITEKTURA
architecture Behavioral_sqrt_pipelined of sqrt is
    constant N     : natural := G_OUT_BW;
    constant SRC_W : natural := 2*N;
    constant REM_W : natural := N + 2;
    constant TMP_W : natural := REM_W + 2;
    
    type src_pipe_t  is array (0 to N) of unsigned(SRC_W-1 downto 0);
    type rem_pipe_t  is array (0 to N) of unsigned(REM_W-1 downto 0);
    type root_pipe_t is array (0 to N) of unsigned(N-1 downto 0);
    
    signal src_pipe   : src_pipe_t  := (others => (others => '0'));
    signal rem_pipe   : rem_pipe_t  := (others => (others => '0'));
    signal root_pipe  : root_pipe_t := (others => (others => '0'));
    signal valid_pipe : std_logic_vector(0 to N) := (others => '0');
    
begin

    d_out     <= std_logic_vector(root_pipe(N));
    valid_out <= valid_pipe(N);
    
    SQRT_COMPUTE_PIPELINING : process(clk)
    variable next2dig : unsigned(1 downto 0);
    variable rem_tmp  : unsigned(TMP_W-1 downto 0);
    variable trial    : unsigned(TMP_W-1 downto 0);
    variable root_new : unsigned(N-1 downto 0);
    variable sub_ext  : unsigned(TMP_W downto 0);    -- +1 bit za underflow
    variable ge       : std_logic;

    begin
        if rising_edge(clk) then
          if reset = '1' then
            src_pipe    <= (others => (others => '0'));
            rem_pipe    <= (others => (others => '0'));
            root_pipe   <= (others => (others => '0'));
            valid_pipe  <= (others => '0');
    
          else
            -- STAGE 0: valid prati valid_in 
            valid_pipe(0) <= valid_in;
            if valid_in = '1' then
              src_pipe(0)  <= shift_left(resize(unsigned(d_in), SRC_W), 2*G_OUT_FRAC);
              rem_pipe(0)  <= (others => '0');
              root_pipe(0) <= (others => '0');
            end if;
    
            -- STAGE1-STAGEN -- pajppppplajning ugh
            for i in 0 to N-1 loop
              valid_pipe(i+1) <= valid_pipe(i);
              if valid_pipe(i) = '1' then
                 -- rem_tmp = (rem<<2) + next2dig  -> konkatenacija (REM_W + 2 = TMP_W)
                 rem_tmp := rem_pipe(i) & src_pipe(i)(SRC_W-1 downto SRC_W-2);
                 -- skupo => trial := shift_left(resize(root_pipe(i), TMP_W), 2) + 1;
                 -- trial = (root << 2) + 1  - bez addera: shift + set bit0
                 trial := shift_left(resize(root_pipe(i), TMP_W), 2);
                 trial(0) := '1';
                
                 -- jedno oduzimanje daje i compare i diff
                 sub_ext := ('0' & rem_tmp) - ('0' & trial);
                 ge := not sub_ext(TMP_W);  -- ge='1' -> rem_tmp >= trial
                 
                 if ge = '1' then
                    rem_pipe(i+1) <= resize(sub_ext(TMP_W-1 downto 0), REM_W); -- rem_tmp - trial
                 else
                    rem_pipe(i+1) <= resize(rem_tmp, REM_W);
                 end if;
                 
                 -- root_new = (root<<1) + ge -> bez addera: shift + set LSB
                 root_new := shift_left(root_pipe(i), 1);
                 root_new(0) := ge;
                 root_pipe(i+1) <= root_new;
    
                 -- src shift
                 src_pipe(i+1) <= shift_left(src_pipe(i), 2);
              end if;
           end loop;
         end if;
       end if;
    end process SQRT_COMPUTE_PIPELINING;
end architecture;