-- this is the comparator module
-- it takes in some inputs, outputs a condition depending on what the mode is
-- TODO: Make it generic?

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity comp is 
generic(DATA_SIZE : integer := 32);
port(
	a : in unsigned(DATA_SIZE - 1 downto 0);
	b : in unsigned(DATA_SIZE - 1 downto 0);
	-- mode : in std_logic_vector(1 downto 0); -- four modes of comparison
	output : out std_logic_vector(3 downto 0) -- GT, LT, EQ, NE
);

end entity comp;

architecture struc of comp is
begin

	comb: process(a, b)
		begin

		output <= "0000";

		if (a > b) then
			output(3) <= '1';
		end if;

		if (a < b) then
			output(2) <= '1';
		end if;

		if (a = b) then
			output(1) <= '1';
		end if;
		
		if (a /= b) then
			output(0) <= '1';
		end if;
		
	end process; 


end architecture struc;