-- Generic Counter

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity gencount is
generic (COUNT_WIDTH : integer := 32);
port(
	reset : in std_logic;
	clk : in std_logic;
	count_en : in std_logic;
	count_value : out unsigned(COUNT_WIDTH - 1 downto 0)
);
end gencount;

architecture str of gencount is

begin
	cnt: process(reset, clk)
		variable cnt : unsigned(COUNT_WIDTH-1 downto 0);
	begin
		if (reset = '1') then
			cnt := (others=>'0');
			count_value <= (others=>'0');
		elsif(rising_edge(clk)) then
			if (count_en = '1') then
				cnt := cnt + 1;
			end if;
		end if;

		count_value <= cnt;

	end process;



end architecture str;