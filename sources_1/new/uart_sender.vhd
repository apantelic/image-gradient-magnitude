library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xil_defaultlib;

entity uart_sender is
  generic(
    CLK_FREQ     : integer := 250;      -- MHz 
    SER_FREQ     : integer := 115200;   -- bps
    ADDR_W       : natural := 16;
    DEPTH        : natural := 65536;
    BRAM_LAT     : natural := 2
  );
  port(
    clk            : in  std_logic;
    reset          : in  std_logic;

    start_transfer : in  std_logic;     -- npr state_reg=st_DONE

    -- BRAM read port B
    mem_addr      : out std_logic_vector(ADDR_W-1 downto 0);
    mem_rdata     : in  std_logic_vector(7 downto 0);  -- bram_dout

    -- UART
    tx             : out std_logic;
    par_en         : in  std_logic := '0';

    -- status
    transfer_active  : out std_logic; -- da BRAM port B cita uart_addr, a ne addrb od Sobel dela
    transfer_done   : out std_logic  -- mozda zatreba
  );
end uart_sender;

architecture Behavioral of uart_sender is

  constant LAST_ADDR : unsigned(ADDR_W-1 downto 0) := to_unsigned(DEPTH-1, ADDR_W);

  -- UART interfejs
  signal tx_data   : std_logic_vector(7 downto 0) := (others=>'0');
  signal tx_dvalid : std_logic := '0';
  signal tx_busy   : std_logic;

  -- FSM
  type uart_state_t is (u_Idle, u_BramWait, u_WaitReady, u_WaitAccept, u_WaitDone);
  signal u_state : uart_state_t := u_Idle;

  signal rd_addr_reg  : unsigned(ADDR_W-1 downto 0) := (others=>'0');
  signal bram_wait_cnt  : natural range 0 to BRAM_LAT := 0;
  signal last_flag : std_logic := '0';

  signal active_reg  : std_logic := '0';    
  signal done_reg    : std_logic := '0';

  signal start_prev : std_logic := '0';

begin
  transfer_active <= active_reg;
  transfer_done <= done_reg;
  mem_addr  <= std_logic_vector(rd_addr_reg);


  UART_TX : entity xil_defaultlib.uart_tx
    generic map(
      CLK_FREQ => CLK_FREQ,  -- MHz
      SER_FREQ => SER_FREQ
    )
    port map(
      clk       => clk,
      rst       => reset,
      tx        => tx,
      par_en    => par_en,
      tx_dvalid => tx_dvalid,
      tx_data   => tx_data,
      tx_busy   => tx_busy
    );

  UART_SENDER: process(clk)
  begin
    if rising_edge(clk) then
      if reset='1' then
         u_state <= u_IDLE;
         rd_addr_reg<= (others=>'0');
         bram_wait_cnt <= 0;
         last_flag <= '0';
         active_reg  <= '0';
         done_reg <= '0';
         tx_data <= (others=>'0');
         tx_dvalid <= '0';
         start_prev <= '0';
         
      else
      
         done_reg <= '0';  -- pulse 1 clk -- ako mi bude trebalo za debug ili nesto tako za LED staviti duze 
         --  novi start tek kad start_transfer padne na 0
         if start_transfer = '0' then
            start_prev <= '0';
         end if;

         case u_state is
 
           when u_Idle =>
             tx_dvalid <= '0';
             active_reg  <= '0';
             last_flag <= '0';

             -- startujemo samo jednom 
             if (start_transfer='1') and (start_prev='0') then
                 start_prev <= '1';
                 active_reg <= '1';
                 rd_addr_reg <= (others=>'0'); -- krecemo od nulte adrese
                 bram_wait_cnt <= BRAM_LAT;         
                 u_state <= u_BramWait;
             end if;

            when u_BramWait =>
              tx_dvalid <= '0';
              if bram_wait_cnt = 0 then
                 u_state <= u_WaitReady;
              else
                bram_wait_cnt <= bram_wait_cnt - 1;
             end if;

            when u_WaitReady =>
              if tx_busy='0' then
                 -- trenutni bajt iz BRAM-a
                 tx_data   <= mem_rdata;
                 tx_dvalid <= '1';

                 -- prefetch sledece adrese dok UART salje
                 if rd_addr_reg = LAST_ADDR then
                    last_flag <= '1';
                 else
                    rd_addr_reg  <= rd_addr_reg + 1;
                    last_flag <= '0';
                 end if;

                 u_state <= u_WaitAccept;
             end if;

            when u_WaitAccept =>
              -- drzi dvalid dok UART ne prihvati - busy ode na 1
              if tx_busy='1' then
                 tx_dvalid <= '0';
                 u_state <= u_WaitDone;
              end if;

            when u_WaitDone =>
              -- cekanje kraja prenosa - busy nazad na 0
              if tx_busy='0' then
                 if last_flag='1' then
                    active_reg <= '0';
                    done_reg  <= '1';
                    u_state  <= u_IDLE;
                 else
                    u_state  <= u_WaitReady;
                 end if;
              end if;
          end case;
      end if;
    end if;
  end process;

end Behavioral;