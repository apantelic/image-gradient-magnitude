library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity edge_detector is
    generic (
        DEB_CYCLES:   natural :=  800000  -- 200 10^6 * 4 * 10^-3
    );
    port( 
        clk : in std_logic;
        reset : in std_logic;
        btn_start  : in std_logic;
        edge : out std_logic 
    );
end edge_detector;

architecture Behavioral of edge_detector is
    type State_t is (st_Idle, st_Debounce, st_Confirm, st_EdgePulse, st_WaitRelease);
    signal state_reg, next_state : State_t;
    signal edge_reg : std_logic := '0';
    signal cnt_deb : integer range 0 to DEB_CYCLES := 0;
begin

edge <= edge_reg;

TRANSITION_LOGIC : process(clk) is             
begin
    if rising_edge(clk) then
       if reset='1' then
          state_reg <= st_Idle;
       else
          state_reg <= next_state;
       end if;
    end if;      
end process TRANSITION_LOGIC;

NEXT_STATE_LOGIC : process(state_reg,btn_start,cnt_deb) is   -- debouncing
begin

    next_state <= state_reg;
    edge_reg <= '0';
    
    case state_reg is
        when st_Idle =>
                if (btn_start = '1') then         -- idle - desi se pritisak tastera
                    next_state <= st_Debounce;
                end if;
        when st_Debounce =>                         -- debouncing - 4ms 
                if (cnt_deb = DEB_CYCLES-1) then 
                    next_state <= st_Confirm;     
                end if;
        when st_Confirm =>                          -- ako je i dalje stisnuto dugme - tj. visok nivo prelazimo u st4
                if (btn_start = '1') then
                    next_state <= st_EdgePulse;
                else 
                    next_state <= st_Idle;          -- ako ne vracamo se u idle
                end if;
        when st_EdgePulse =>                        -- ako smo dosli do ovog stanja znaci desio se edge 
                edge_reg <= '1';
                next_state <= st_WaitRelease;
        when st_WaitRelease =>
                edge_reg <= '0';
                if (btn_start = '0') then            -- kad se pusti dugme prelazi se u idle
                    next_state <= st_Idle;
                end if;
    end case;
end process NEXT_STATE_LOGIC;

COUNTER_DEB_LOGIC : process(clk) is
	begin
	   if rising_edge(clk) then 
	      if (reset = '1') then 
	           cnt_deb <= 0;
	      elsif (state_reg = st_Idle) then 
	            cnt_deb <= 0;
	      elsif (state_reg = st_Debounce) then 
	            cnt_deb <= cnt_deb + 1;
	      end if;
	       
	       
	   end if;
	end process COUNTER_DEB_LOGIC;

end Behavioral;
