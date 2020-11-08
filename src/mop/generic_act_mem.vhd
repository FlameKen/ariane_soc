-- Test RAM
-- values have been hardcoded for the two-comp instruction set format
-- next step may be to replace these with some python generation script
-- author: Benjamin Tan

library IEEE;
library work;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.instr_pkg2.all;

entity generic_act_mem is
generic (initmem : flow_mem2 := (others=>(others=>'0')));
port (
	clk		:	in std_logic;
	address	:	in unsigned(AL2 - 1 downto 0);
	data_in	:	in std_logic_vector(DW2 - 1 downto 0);
	rd		: 	in std_logic;
	wr		:	in std_logic;
	q		:	out std_logic_vector(DW2 - 1 downto 0);
	rdy		:	out std_logic
);
end generic_act_mem;

architecture behaviour of generic_act_mem is
	signal memory_element : flow_mem2 := initmem;

begin
    rdy <= '1';
    
    process(clk)
	variable address_to_read : unsigned(AL2 - 1 downto 0);
	begin
	if (rising_edge(clk)) then
		if(rd = '1') then
            address_to_read := address;
            q <= memory_element(to_integer(address_to_read));
        end if;
        
        if (wr = '1') then
            address_to_read := address;
            memory_element(to_integer(address_to_read)) <= data_in;
        end if;
	end if;
	
	end process;


end architecture behaviour;