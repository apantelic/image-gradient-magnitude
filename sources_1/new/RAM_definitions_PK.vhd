library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package RAM_definitions_PK is
    impure function clogb2 (depth: in natural) return integer;
end RAM_definitions_PK;

package body RAM_definitions_PK is
  impure function clogb2(depth : natural) return integer is
    variable temp    : natural;
    variable ret_val : integer := 0;
  begin
    -- da ne bi dobio vektor širine 0 bita kad je depth=1
    if depth <= 1 then
      return 1;
    end if;

    temp := depth - 1;
    while temp > 0 loop
      ret_val := ret_val + 1;
      temp := temp / 2;
    end loop;

    return ret_val;
  end function;
end package body;
