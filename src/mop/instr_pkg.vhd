-- this package contains "constants" for easier readability when it comes to
-- the monitoring/patching instruction set

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package instr_pkg is
	constant AL				: integer := 3; -- address length of flow memory
	constant DW				: integer := 8; -- data size of flow memory
	type flow_mem is array(0 to 2**AL - 1)  of std_logic_vector(DW - 1 downto 0);
	constant WDATA_SRC 		: std_logic_vector(3 downto 0) := "0000";
	constant ADDR_SRC 		: std_logic_vector(3 downto 0) := "0001";
	constant WSTRB_SRC 		: std_logic_vector(3 downto 0) := "0010";
	constant RDATA_SRC 		: std_logic_vector(3 downto 0) := "0011";
	constant ZEROS_SRC 		: std_logic_vector(3 downto 0) := "1000";
	constant CNTR_SRC 		: std_logic_vector(3 downto 0) := "1001";
	constant RPLA			: std_logic_vector(3 downto 0) := "0000";
	constant MOVE			: std_logic_vector(3 downto 0) := "0001";
	constant SHFT			: std_logic_vector(3 downto 0) := "0010";
	constant STOR			: std_logic_vector(3 downto 0) := "0011";
	constant STMV_WDATA		: std_logic_vector(3 downto 0) := "0100";
	constant STMV_ADDR		: std_logic_vector(3 downto 0) := "0101";
	constant STMV_WSTRB		: std_logic_vector(3 downto 0) := "0110";
	constant STMV_RDATA		: std_logic_vector(3 downto 0) := "0111";
	constant MISC_ACT		: std_logic_vector(3 downto 0) := "1000";
	constant STRT			: std_logic_vector(5 downto 0) := "100000";
	constant GOTO			: std_logic_vector(5 downto 0) := "100001";
	constant SCNT			: std_logic_vector(3 downto 0) := "1001";
	constant ALRM			: std_logic_vector(3 downto 0) := "1010";
	constant GT				: std_logic_vector(1 downto 0) := "00";
	constant LT				: std_logic_vector(1 downto 0) := "01";
	constant ET				: std_logic_vector(1 downto 0) := "10";
	constant NE				: std_logic_vector(1 downto 0) := "11";
	constant CNT_DISABLE	: std_logic_vector(1 downto 0) := "00";
	constant CNT_CLK		: std_logic_vector(1 downto 0) := "10";
	constant CNT_COMP		: std_logic_vector(1 downto 0) := "11";
end instr_pkg;