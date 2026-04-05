library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library xil_defaultlib;

entity sobel_mag_sqrt_compute is
  generic (
    G_PIX_W     : natural := 8;
    G_ADDR_W    : natural := 16;
    G_SQRT_LAT  : natural := 17
  );
  port (
    clk   : in  std_logic;
    reset : in  std_logic;

    -- 3x3 window
    a00 : in  std_logic_vector(G_PIX_W-1 downto 0);
    a01 : in  std_logic_vector(G_PIX_W-1 downto 0);
    a02 : in  std_logic_vector(G_PIX_W-1 downto 0);
    a10 : in  std_logic_vector(G_PIX_W-1 downto 0);
    a11 : in  std_logic_vector(G_PIX_W-1 downto 0);
    a12 : in  std_logic_vector(G_PIX_W-1 downto 0);
    a20 : in  std_logic_vector(G_PIX_W-1 downto 0);
    a21 : in  std_logic_vector(G_PIX_W-1 downto 0);
    a22 : in  std_logic_vector(G_PIX_W-1 downto 0);

    window_valid    : in  std_logic;
    center_addr_in  : in  unsigned(G_ADDR_W-1 downto 0);

    mag8_out        : out std_logic_vector(7 downto 0);
    valid_out       : out std_logic;
    center_addr_out : out unsigned(G_ADDR_W-1 downto 0)
  );
end entity;

architecture Behavioral of sobel_mag_sqrt_compute is

    -- STAGE0: pos/neg sume 
    signal pos_h, neg_h : unsigned(9 downto 0) := (others=>'0');
    signal pos_v, neg_v : unsigned(9 downto 0) := (others=>'0');
    signal v_s0    : std_logic := '0';
    signal addr_s0 : unsigned(G_ADDR_W-1 downto 0) := (others=>'0');
    
    -- STAGE1: RAZLIKA - ovo je resilo problem net delay-a na kriticnoj putanji do dsp-a 
    signal gh_dif, gv_dif : signed(10 downto 0) := (others=>'0');
    signal v_s1    : std_logic := '0';
    signal addr_s1 : unsigned(G_ADDR_W-1 downto 0) := (others=>'0');
    
    -- znaci ubacila sam registar da presecem kriticnu putanju - ovi atributi kazu sintezu da ostavi taj ff i da ga ne primesti oduzimanej u dsp alu
    attribute dont_touch : string;
    attribute dont_touch of gh_dif: signal is "true";
    attribute dont_touch of gv_dif : signal is "true";
    
    -- STAGE2: abs 
    signal gh_abs, gv_abs : unsigned(9 downto 0) := (others=>'0');
    signal v_s2    : std_logic := '0';
    signal addr_s2 : unsigned(G_ADDR_W-1 downto 0) := (others=>'0');
    
    -- STAGE3: kvadrati
    signal gh_sq, gv_sq : unsigned(19 downto 0) := (others=>'0');
    signal v_s3    : std_logic := '0';
    signal addr_s3 : unsigned(G_ADDR_W-1 downto 0) := (others=>'0');
    
    attribute use_dsp : string; -- atribut da koristi dsp - vrv nr mora svakako ga koristi
    attribute use_dsp of gh_sq : signal is "yes";
    attribute use_dsp of gv_sq : signal is "yes";
    
    -- STAGE4: suma kvadrata + shift u desno za 6
    signal sqrt_in_reg : unsigned(15 downto 0) := (others=>'0');
    signal v_s4    : std_logic := '0';
    signal addr_s4 : unsigned(G_ADDR_W-1 downto 0) := (others=>'0');
    
    -- sqrt interfejs
    signal sqrt_in       : std_logic_vector(15 downto 0) := (others=>'0');
    signal sqrt_valid_in : std_logic := '0';
    signal sqrt_out      : std_logic_vector(15 downto 0);
    signal sqrt_vout     : std_logic;
    
    -- addr pipe kroz sqrt ltencu
    type addr_pipe_t is array (0 to G_SQRT_LAT-1) of unsigned(G_ADDR_W-1 downto 0);
    signal addr_pipe : addr_pipe_t := (others => (others=>'0'));
    
    -- outputs
    signal mag8_reg            : std_logic_vector(7 downto 0) := (others => '0');
    signal valid_out_reg       : std_logic := '0';
    signal center_addr_out_reg : unsigned(G_ADDR_W-1 downto 0) := (others => '0');

begin

    mag8_out        <= mag8_reg;
    valid_out       <= valid_out_reg;
    center_addr_out <= center_addr_out_reg;

    SQRT : entity xil_defaultlib.sqrt(Behavioral_sqrt_pipelined)
    generic map (
      G_IN_BW    => 16,
      G_OUT_BW   => 16,
      G_OUT_FRAC => 8
    )
    port map (
      clk       => clk,
      reset     => reset,
      d_in      => sqrt_in,
      valid_in  => sqrt_valid_in,
      d_out     => sqrt_out,
      valid_out => sqrt_vout
    );

    STAGE0 : process(clk)
    variable u00,u01,u02,u10,u12,u20,u21,u22 : unsigned(G_PIX_W+1 downto 0); -- 10b
    variable ph, nh, pv, nv : unsigned(G_PIX_W+1 downto 0); -- 10b
    begin
    if rising_edge(clk) then
       if reset='1' then
          pos_h <= (others=>'0'); neg_h <= (others=>'0');
          pos_v <= (others=>'0'); neg_v <= (others=>'0');
          v_s0 <= '0';
          addr_s0 <= (others=>'0');
       else
          v_s0 <= window_valid;
          addr_s0 <= center_addr_in;
    
          if window_valid='1' then
             u00 := resize(unsigned(a00), G_PIX_W+2);
             u01 := resize(unsigned(a01), G_PIX_W+2);
             u02 := resize(unsigned(a02), G_PIX_W+2);
             u10 := resize(unsigned(a10), G_PIX_W+2);
             u12 := resize(unsigned(a12), G_PIX_W+2);
             u20 := resize(unsigned(a20), G_PIX_W+2);
             u21 := resize(unsigned(a21), G_PIX_W+2);
             u22 := resize(unsigned(a22), G_PIX_W+2);
    
             -- Gh sume
             ph := u02 + (u12 sll 1) + u22;
             nh := u00 + (u10 sll 1) + u20;
    
             -- Gv sume
             pv := u20 + (u21 sll 1) + u22;
             nv := u00 + (u01 sll 1) + u02;
    
             pos_h <= ph; neg_h <= nh;
             pos_v <= pv; neg_v <= nv;
          end if;
        end if;
    end if;
    end process;

    STAGE1 : process(clk)
    begin
    if rising_edge(clk) then
       if reset='1' then
          gh_dif <= (others=>'0');
          gv_dif <= (others=>'0');
          v_s1 <= '0';
          addr_s1 <= (others=>'0');
       else
          v_s1 <= v_s0;
          addr_s1 <= addr_s0;
    
          if v_s0='1' then
             gh_dif <= signed('0' & pos_h) - signed('0' & neg_h);
             gv_dif <= signed('0' & pos_v) - signed('0' & neg_v);
          end if;
       end if;
    end if;
    end process;

    STAGE2 : process(clk)
    variable gh_abs_u, gv_abs_u : unsigned(10 downto 0);
    begin
    if rising_edge(clk) then
       if reset='1' then
          gh_abs <= (others=>'0');
          gv_abs <= (others=>'0');
          v_s2 <= '0';
          addr_s2 <= (others=>'0');
        else
          v_s2 <= v_s1;
          addr_s2 <= addr_s1;
    
          if v_s1='1' then
             if gh_dif(10)='1' then gh_abs_u := unsigned(-gh_dif); else gh_abs_u := unsigned(gh_dif); end if;
             if gv_dif(10)='1' then gv_abs_u := unsigned(-gv_dif); else gv_abs_u := unsigned(gv_dif); end if;
    
             gh_abs <= gh_abs_u(9 downto 0);
             gv_abs <= gv_abs_u(9 downto 0);
          end if;
        end if;
    end if;
    end process;

    STAGE3 : process(clk)
    begin
    if rising_edge(clk) then
       if reset='1' then
          gh_sq <= (others=>'0');
          gv_sq <= (others=>'0');
          v_s3 <= '0';
          addr_s3 <= (others=>'0');
       else
          v_s3 <= v_s2;
          addr_s3 <= addr_s2;
    
          if v_s2='1' then
             gh_sq <= gh_abs * gh_abs;
             gv_sq <= gv_abs * gv_abs;
          end if;
        end if;
    end if;
    end process;

    STAGE4 : process(clk)
    variable sumsq : unsigned(20 downto 0);
    begin
    if rising_edge(clk) then
       if reset='1' then
          sqrt_in_reg <= (others=>'0');
          v_s4 <= '0';
          addr_s4 <= (others=>'0');
       else
          v_s4    <= v_s3;
          addr_s4 <= addr_s3;
    
          if v_s3='1' then
             sumsq := resize(gh_sq,21) + resize(gv_sq,21);
             sqrt_in_reg <= resize(shift_right(sumsq,6),16);
          end if;
       end if;
    end if;
    end process;
    
    sqrt_in <= std_logic_vector(sqrt_in_reg);
    sqrt_valid_in <= v_s4;

    -- addr pipe kroz sqrt latency
    PIPE_SQRT : process(clk)
    begin
    if rising_edge(clk) then
       if reset='1' then
          addr_pipe <= (others => (others=>'0'));
       else
          addr_pipe(0) <= addr_s4;
          for i in 1 to G_SQRT_LAT-1 loop
              addr_pipe(i) <= addr_pipe(i-1);
          end loop;
       end if;
    end if;
    end process;

    ROUND_UINT8 : process(clk)
    variable tmp : unsigned(16 downto 0);
    variable sh  : unsigned(16 downto 0);
    begin
    if rising_edge(clk) then
       if reset='1' then
          mag8_reg <= (others=>'0');
          valid_out_reg <= '0';
          center_addr_out_reg <= (others=>'0');
       else
          valid_out_reg <= sqrt_vout;
    
          if sqrt_vout='1' then
             center_addr_out_reg <= addr_pipe(G_SQRT_LAT-1);
             tmp := resize(unsigned(sqrt_out),17) + to_unsigned(16#0080#,17); -- +0.5 za rounding
             sh  := shift_right(tmp,8);
             mag8_reg <= std_logic_vector(sh(7 downto 0));
          end if;
       end if;
    end if;
    end process;

end architecture;