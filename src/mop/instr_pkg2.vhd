-- this package contains "constants" for easier readability when it comes to
-- the monitoring/patching instruction set

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package instr_pkg2 is
	constant AL				: integer := 4; -- address length of flow memory
	constant DW				: integer := 13; -- data size of flow memory
	-- constant DW				: integer := 17; -- data size of flow memory
	type flow_mem is array(0 to 2**AL - 1)  of std_logic_vector(DW - 1 downto 0);
	constant AL2				: integer := 4; -- address length of assertion memory
	constant AL3				: integer := 3; -- address length of assertion memory
	constant DW2				: integer := 20; -- data size of assertion memory
	constant DW3				: integer := 19; -- data size of redirect memory
	type flow_mem2 is array(0 to 2**AL2 - 1)  of std_logic_vector(DW2 - 1 downto 0);
	type flow_mem3 is array(0 to 2**AL3 - 1)  of std_logic_vector(DW3 - 1 downto 0);
	type stored 	is array (0 to 2**AL - 1) of std_logic_vector(32 downto 0);
	constant STOR			: std_logic_vector(1 downto 0) := "00";
	constant STMV			: std_logic_vector(1 downto 0) := "01";
	constant ALRM			: std_logic_vector(1 downto 0) := "10";
	constant REPL			: std_logic_vector(1 downto 0) := "11";
	constant SEL_addr		: std_logic_vector(1 downto 0) := "00";
	constant SEL_rdata		: std_logic_vector(1 downto 0) := "01";
	constant SEL_wdata		: std_logic_vector(1 downto 0) := "10";
	constant SEL_count		: std_logic_vector(1 downto 0) := "11";
	constant SEL_r00		: std_logic_vector(1 downto 0) := "00";
	constant SEL_r01		: std_logic_vector(1 downto 0) := "01";
	constant SEL_r10		: std_logic_vector(1 downto 0) := "10";
	constant SEL_r11		: std_logic_vector(1 downto 0) := "11";
	constant BIGSEL_addr	: std_logic_vector(2 downto 0) := "100";
	constant BIGSEL_rdata	: std_logic_vector(2 downto 0) := "101";
	constant BIGSEL_wdata	: std_logic_vector(2 downto 0) := "110";
	constant BIGSEL_count	: std_logic_vector(2 downto 0) := "111";
	constant BIGSEL_r00		: std_logic_vector(2 downto 0) := "000";
	constant BIGSEL_r01		: std_logic_vector(2 downto 0) := "001";
	constant BIGSEL_r10		: std_logic_vector(2 downto 0) := "010";
	constant BIGSEL_r11		: std_logic_vector(2 downto 0) := "011";
	constant GT				: std_logic_vector(1 downto 0) := "00";
	constant LT				: std_logic_vector(1 downto 0) := "01";
	constant ET				: std_logic_vector(1 downto 0) := "10";
	constant NE				: std_logic_vector(1 downto 0) := "11";
	constant A_EVENT_valid	: std_logic_vector(1 downto 0) := "00";
	constant A_EVENT_ready	: std_logic_vector(1 downto 0) := "01";
	constant A_EVENT_reset	: std_logic_vector(1 downto 0) := "10";
	constant A_EVENT_clock	: std_logic_vector(1 downto 0) := "11";
	constant CNTCTRL_dis	: std_logic_vector(1 downto 0) := "00";
    constant CNTCTRL_clk	: std_logic_vector(1 downto 0) := "10";
    constant CNTCTRL_com	: std_logic_vector(1 downto 0) := "11";

	-- constant WDATA_SRC 		: std_logic_vector(3 downto 0) := "0000";
	-- constant ADDR_SRC 		: std_logic_vector(3 downto 0) := "0001";
	-- constant WSTRB_SRC 		: std_logic_vector(3 downto 0) := "0010";
	-- constant RDATA_SRC 		: std_logic_vector(3 downto 0) := "0011";
	-- constant ZEROS_SRC 		: std_logic_vector(3 downto 0) := "1000";
	-- constant CNTR_SRC 		: std_logic_vector(3 downto 0) := "1001";
	-- constant RPLA			: std_logic_vector(3 downto 0) := "0000";
	-- constant MOVE			: std_logic_vector(3 downto 0) := "0001";
	-- constant SHFT			: std_logic_vector(3 downto 0) := "0010";
	-- constant STOR			: std_logic_vector(3 downto 0) := "0011";
	-- constant STMV_WDATA		: std_logic_vector(3 downto 0) := "0100";
	-- constant STMV_ADDR		: std_logic_vector(3 downto 0) := "0101";
	-- constant STMV_WSTRB		: std_logic_vector(3 downto 0) := "0110";
	-- constant STMV_RDATA		: std_logic_vector(3 downto 0) := "0111";
	-- constant MISC_ACT		: std_logic_vector(3 downto 0) := "1000";
	-- constant STRT			: std_logic_vector(5 downto 0) := "100000";
	-- constant GOTO			: std_logic_vector(5 downto 0) := "100001";
	-- constant SCNT			: std_logic_vector(3 downto 0) := "1001";
	-- constant ALRM			: std_logic_vector(3 downto 0) := "1010";
	-- constant GT				: std_logic_vector(1 downto 0) := "00";
	-- constant LT				: std_logic_vector(1 downto 0) := "01";
	-- constant ET				: std_logic_vector(1 downto 0) := "10";
	-- constant NE				: std_logic_vector(1 downto 0) := "11";
	-- constant CNT_DISABLE	: std_logic_vector(1 downto 0) := "00";
	-- constant CNT_CLK		: std_logic_vector(1 downto 0) := "10";
	-- constant CNT_COMP		: std_logic_vector(1 downto 0) := "11";
end instr_pkg2;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package instr_pkg is
	constant AL				: integer := 3; -- address length of flow memory
	constant DW				: integer := 14; -- data size of flow memory
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