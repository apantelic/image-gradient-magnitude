library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library xil_defaultlib;

entity projekat_top is
    port(
      clk_in   : in  std_logic;
      reset : in  std_logic;
      start : in  std_logic;
      tx  : out std_logic;
      led_transfer : out std_logic 
);
end projekat_top;

architecture Behavioral of projekat_top is
    constant G_IMG_H : natural := 256; -- 8;
    constant G_IMG_W : natural := 256; -- 8;
    constant G_PIX_W : natural := 8;
    constant G_ADDR_W: natural := 16; --6
    constant G_SQRT_LAT : natural := 17;                    
    constant G_INIT_FILENAME : string := "cameramann.dat"; --"C:\Users\User\Documents\VLSI\vlsi_projekat_faza_1\input_img_krug_88.txt";
    constant C_BRAM_LAT : natural := 2;
    -- DRAIN latenca - broj taktova nakon procitanjeg procitanog podatka iz BRAMA-a da bi iz pipeline-a sistema izasli svi preostali  rezultati
    constant C_DRAIN_CYC : natural := C_BRAM_LAT + 1 + (5 + G_SQRT_LAT) + 3;  
    constant C_LAST_ADDR : unsigned(G_ADDR_W-1 downto 0) := to_unsigned(G_IMG_H*G_IMG_W-1, G_ADDR_W);
    constant G_DEB_CYCLES : natural := 800000; -- 4ms * 200MHZ
    
    -- clock wizard 
    signal clk : std_logic; 
    component clk_wiz_0
      port (
        clk_out1 : out std_logic;
        reset    : in  std_logic;
        clk_in1  : in  std_logic
      );
    end component;
    
    -- BRAM port B za read
    signal addrb : unsigned(G_ADDR_W-1 downto 0) := (others => '0');
    signal doutb : std_logic_vector(G_PIX_W-1 downto 0);
    
    -- BRAM port A za writeback
    signal addra : std_logic_vector(G_ADDR_W-1 downto 0) := (others => '0');
    signal dina  : std_logic_vector(G_PIX_W-1 downto 0) := (others => '0');
    signal wea   : std_logic := '0';
    
    -- BRAM address mux (processing vs uart)
    signal bram_addrb_mux : std_logic_vector(G_ADDR_W-1 downto 0);
    
    -- window inputs
    signal pix_in    : std_logic_vector(G_PIX_W-1 downto 0);
    signal pix_valid : std_logic := '0';
    
    -- window outputs
    signal a00,a01,a02,a10,a11,a12,a20,a21,a22 : std_logic_vector(G_PIX_W-1 downto 0);
    signal window_valid : std_logic;
    signal center_addr  : unsigned(G_ADDR_W-1 downto 0);
    
    -- sobel inputs - register slice - fixme: mozda i ne mora vise registar izmedju proveriti da li smeta kriticnoj putanji 
    signal a00_reg,a01_reg,a02_reg,a10_reg,a11_reg,a12_reg,a20_reg,a21_reg,a22_reg : std_logic_vector(G_PIX_W-1 downto 0);
    signal window_valid_reg : std_logic := '0';
    signal center_addr_reg  : unsigned(G_ADDR_W-1 downto 0) := (others=>'0');
    
    -- sobel outputs
    signal mag8_out        : std_logic_vector(7 downto 0);
    signal sobel_valid_out : std_logic;
    signal center_addr_out : unsigned(G_ADDR_W-1 downto 0);
    
    -- edge detector interfejs
    signal start_pulse : std_logic;
    
    -- uart interfejs 
    signal start_transfer  : std_logic;
    signal mem_addr_uart   : std_logic_vector(G_ADDR_W-1 downto 0);
    signal transfer_active : std_logic;
    signal transfer_done   : std_logic;
    
    -- FSM
    type state_t is (st_IDLE, st_RUN, st_DRAIN, st_DONE);
    signal state_reg, state_next : state_t := st_IDLE;
    signal drain_cnt : unsigned(15 downto 0) := (others=>'0');
    signal rd_req : std_logic := '0';                                                -- rd request 1 takt = 1 adresa
    signal rd_valid_pipe : std_logic_vector(C_BRAM_LAT-1 downto 0) := (others=>'0'); -- BRAM dout valid pipe 

begin
    
    CLK_GEN : clk_wiz_0
       port map ( 
           clk_out1 => clk,             
           reset => '0',
           clk_in1 => clk_in
        );

    start_transfer <= '1' when state_reg = st_DONE else '0';
    
    -- BRAM address mux: dok UART salje, port B cita UART adresu
    bram_addrb_mux <= mem_addr_uart when transfer_active='1' else std_logic_vector(addrb);
    
    BRAM: entity xil_defaultlib.im_ram
        generic map(
          G_RAM_WIDTH => G_PIX_W,
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
          addrb  => bram_addrb_mux,
          enb    => '1',
          rstb   => '0',
          regceb => '1',
          doutb  => doutb
        );
    
    pix_in <= doutb;

    -- WINDOW GENERATOR
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
          a00 => a00, a01 => a01, a02 => a02,
          a10 => a10, a11 => a11, a12 => a12,
          a20 => a20, a21 => a21, a22 => a22,
          window_valid => window_valid,
          center_addr  => center_addr
        );
    
    -- SOBEL + MAG + SQRT
    SOBEL: entity xil_defaultlib.sobel_mag_sqrt_compute(Behavioral)
        generic map(
          G_PIX_W    => G_PIX_W,
          G_ADDR_W   => G_ADDR_W,
          G_SQRT_LAT => G_SQRT_LAT   
        )
        port map(
          clk   => clk,
          reset => reset,
        
          a00 => a00_reg, a01 => a01_reg, a02 => a02_reg,
          a10 => a10_reg, a11 => a11_reg, a12 => a12_reg,
          a20 => a20_reg, a21 => a21_reg, a22 => a22_reg,
        
          window_valid   => window_valid_reg,
          center_addr_in => center_addr_reg,
        
          mag8_out        => mag8_out,
          valid_out       => sobel_valid_out,
          center_addr_out => center_addr_out
        );
 
    
    UART_S : entity xil_defaultlib.uart_sender
        generic map(
            CLK_FREQ => 200,              -- MHz 
            SER_FREQ => 115200,
            ADDR_W   => G_ADDR_W,
            DEPTH    => G_IMG_H*G_IMG_W,  -- 65536
            BRAM_LAT => 2
        )
        port map(
            clk  => clk,
            reset  => reset,
            start_transfer => start_transfer,
            mem_addr => mem_addr_uart,
            mem_rdata => doutb,  -- isti doutb od BRAM-a
            tx  => tx,
            par_en  => '0',
            transfer_active => transfer_active,
            transfer_done  => transfer_done
      );
      
    START_DETECTION : entity xil_defaultlib.edge_detector
        generic map (
            DEB_CYCLES => G_DEB_CYCLES
        )
        port map ( 
        clk => clk,
        reset => reset,
        btn_start  => start,
        edge =>  start_pulse
    );    
       
    -- REGISTER SLICE: WIN - SOBEL
    REGISTER_SLICE : process(clk)
    begin
    if rising_edge(clk) then
       if reset='1' then
          window_valid_reg <= '0';
          center_addr_reg  <= (others=>'0');
          a00_reg <= (others=>'0'); a01_reg <= (others=>'0'); a02_reg <= (others=>'0');
          a10_reg <= (others=>'0'); a11_reg <= (others=>'0'); a12_reg <= (others=>'0');
          a20_reg <= (others=>'0'); a21_reg <= (others=>'0'); a22_reg <= (others=>'0');
       else
          window_valid_reg <= window_valid;
          center_addr_reg  <= center_addr;
    
          a00_reg <= a00; a01_reg <= a01; a02_reg <= a02;
          a10_reg <= a10; a11_reg <= a11; a12_reg <= a12;
          a20_reg <= a20; a21_reg <= a21; a22_reg <= a22;
       end if;
    end if;
    end process;
    
    -- WRITEBACK : nakon obrade upis u isti ram 
    WRITEBACK : process(clk)
    begin
    if rising_edge(clk) then
       if reset='1' then
          wea   <= '0';
          addra <= (others => '0');
          dina  <= (others => '0');
       else
          wea <= '0';
          if sobel_valid_out='1' then
             addra <= std_logic_vector(center_addr_out);
             dina  <= mag8_out;
             wea   <= '1';
          end if;
       end if;
    end if;
    end process;

    -- Read request - mislim da mi ne treba transfer_active
    rd_req <= '1' when (state_reg = st_RUN and transfer_active='0') else '0';
    
    -- BRAM control
    ADDR_READ_CNT : process(clk)
    begin
      if rising_edge(clk) then
        if reset='1' then
          addrb <= (others=>'0');
        else
          if state_reg = st_IDLE then
             addrb <= (others=>'0');   -- spremno za sledeci start
          elsif rd_req='1' then
                  addrb <= addrb + 1;
          end if;
        end if;
      end if;
    end process;

    -- BRAM dout valid kasni 2  takta u odnosu na read request - HIGH PERFORMANCE
    BRAM_DOUT_VALID: process(clk)
    begin
    if rising_edge(clk) then
       if reset='1' then
          rd_valid_pipe <= (others=>'0');
       else
          rd_valid_pipe <= rd_valid_pipe(C_BRAM_LAT-2 downto 0) & rd_req;
       end if;
    end if;
    end process;
    
    pix_valid <= rd_valid_pipe(C_BRAM_LAT-1);

    STATE_TRANSITION_LOGIC: process(clk)
    begin
    if rising_edge(clk) then
       if reset='1' then
          state_reg <= st_IDLE;
        else
          state_reg <= state_next;
      end if;
    end if;
    end process;
    
    led_transfer <= transfer_active; -- za proveru
    NEXT_STATE_LOGIC : process(state_reg,start_pulse,addrb,drain_cnt,transfer_done)
    begin
    state_next <= state_reg;
    case state_reg is
      when st_IDLE =>
        if start_pulse='1' then
           state_next <= st_RUN;
        end if;
    
      when st_RUN =>
        if addrb = C_LAST_ADDR then
           state_next <= st_DRAIN;
        end if;

      when st_DRAIN =>
        if drain_cnt = to_unsigned(C_DRAIN_CYC-1, drain_cnt'length) then
           state_next <= st_DONE;
        end if;

      when st_DONE =>
           if transfer_done='1' then
              state_next <= st_IDLE;
           end if;
      end case;
    end process;
  
    DRAIN_CNT_LOGIC : process(clk)   
    begin
    if rising_edge(clk) then 
       if reset='1'then 
          drain_cnt <= (others=>'0');
       else
          drain_cnt <= (others=>'0'); -- njega uvek osvezavamo da bi izbegli da se sintetise kao ff sa enb, jer mi to pravi problem za kriticnu putanju, odnosno net delay mi poraste 
          if (state_reg = st_DRAIN) then 
              drain_cnt <= drain_cnt + 1; 
          end if;
       end if;         
    end if; 
    end process;
    

    
end Behavioral;