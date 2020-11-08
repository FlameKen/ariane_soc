-- this is the single mop variant
-- prototype by B. Tan
library IEEE;
library work;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.instr_pkg.all;

entity newmop is
    port(
        clk     : in std_logic;
        reset   : in std_logic;
        i_addr  : in std_logic_vector(31 downto 0);
        i_write : in std_logic; -- 0=read, 1=write
        i_rdata : in std_logic_vector(31 downto 0);
        i_wdata : in std_logic_vector(31 downto 0);
        i_valid : in std_logic;
        i_ready : in std_logic;
        -- Intercept Versions
        o_addr  : out std_logic_vector(31 downto 0);
        o_write : out std_logic;
        o_rdata : out std_logic_vector(31 downto 0);
        o_wdata : out std_logic_vector(31 downto 0);
        o_valid : out std_logic;
        o_ready : out std_logic
    );
end entity newmop;

architecture behavior of newmop is
    begin

        o_addr   <= i_addr;
        o_write  <= i_write;
        o_rdata  <= i_rdata;
        o_wdata  <= i_wdata;
        o_valid  <= i_valid;
        o_ready  <= i_ready;

end architecture behavior;