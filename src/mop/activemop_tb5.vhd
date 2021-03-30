-- this is the single mop testbench
-- prototype by B. Tan
library ieee;
library work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.instr_pkg2.all;

entity activemop_tb5 is
end entity;

architecture tb of activemop_tb5 is

    component newmop_5 is
        port(
            clk     : in std_logic;
            reset   : in std_logic;
            i_addr  : in std_logic_vector(31 downto 0);
            i_write : in std_logic; -- 0=read, 1=write
            i_rdata : in std_logic_vector(31 downto 0);
            i_wdata : in std_logic_vector(31 downto 0);
            i_wstrb : in std_logic_vector(3 downto 0); -- byte-wise strobe
            i_error : in std_logic; -- 0=ok, 1=error
            i_valid : in std_logic;
            i_ready : in std_logic;
            -- Intercept Versions
            o_addr  : out std_logic_vector(31 downto 0);
            o_write : out std_logic;
            o_rdata : out std_logic_vector(31 downto 0);
            o_wdata : out std_logic_vector(31 downto 0);
            o_wstrb : out std_logic_vector(3 downto 0);
            o_error : out std_logic;
            o_valid : out std_logic;
            o_ready : out std_logic;
    
            alarm   : out std_logic;
            ext_wr  : in std_logic;
            ext_data_in : in std_logic_vector(DW-1 downto 0);
            ext_act_in : in std_logic_vector(DW2-1 downto 0);
            ext_addr : in unsigned(2 downto 0);
            re_ext_wr  : in std_logic;
            re_ext_data_in : in std_logic_vector(DW3-1 downto 0);
            re_ext_addr : in unsigned(1 downto 0);
            redirection   : out std_logic;
            source          : out unsigned (3 downto 0);
            target          : out unsigned(3 downto 0)
        );
    end component newmop_5;
    
    signal t_clk     : std_logic;
    signal t_reset   : std_logic;
    signal t_i_addr  : std_logic_vector(31 downto 0);
    signal t_i_write : std_logic; -- 0=read, 1=write
    signal t_i_rdata : std_logic_vector(31 downto 0) := (others=>'0');
    signal t_i_wdata : std_logic_vector(31 downto 0);
    signal t_i_wstrb : std_logic_vector(3 downto 0); -- byte-wise strobe
    signal t_i_error : std_logic; -- 0=ok, 1=error
    signal t_i_valid : std_logic;
    signal t_i_ready : std_logic;
    signal t_o_addr  : std_logic_vector(31 downto 0);
    signal t_o_write : std_logic;
    signal t_o_rdata : std_logic_vector(31 downto 0);
    signal t_o_wdata : std_logic_vector(31 downto 0);
    signal t_o_wstrb : std_logic_vector(3 downto 0);
    signal t_o_error : std_logic;
    signal t_o_valid : std_logic;
    signal t_o_ready : std_logic;
    signal t_alarm   : std_logic;
    signal t_ext_wr   : std_logic;
    signal t_ext_data_in : std_logic_vector(DW-1 downto 0);
    signal t_ext_act_in : std_logic_vector(DW2-1 downto 0);
    signal t_ext_addr : unsigned(2 downto 0);
    signal t_re_ext_wr  :  std_logic;
    signal t_re_ext_data_in :  std_logic_vector(DW3-1 downto 0);
    signal t_re_ext_addr :  unsigned(1 downto 0);
    signal t_redirection   :  std_logic;
    signal t_source          :  unsigned (3 downto 0);
    signal t_target          :  unsigned(3 downto 0);

    signal t_cnt : integer := 0;
    -- for abstracted memory mapped IP
    type tb_memory is array(0 to 7) of std_logic_vector(31 downto 0);
    signal t_memory_element : tb_memory := (others=>(others=>'0'));
    
    signal passtest : std_logic;
    signal alarmtest : std_logic;

    begin

        clk_p : process
        begin
            t_clk <= '0';
            wait for 10 ns;
            t_clk <= '1';
            wait for 10 ns;
        end process;

        stim: process
        begin
            -- toggle test here
            passtest <= '1';
            alarmtest <= '0';


            t_reset <= '1';
            t_ext_wr <= '0';
           
            -- simulated master
            t_i_addr    <= (others=>'0');
            t_i_write   <= '0';
            t_i_wdata   <= (others=>'0');
            t_i_wstrb   <= (others=>'0');
            t_i_valid   <= '0';

        wait for 33 ns;
            t_reset <= '0';
        
        if (passtest = '1') then
        -- no trigger
        wait until (rising_edge(t_clk));
        wait for 13 ns;
            t_cnt <= 1;
            t_i_addr    <= x"00000000";
            t_i_wdata   <= x"000000FF";
            t_i_write   <= '1';
            t_i_valid   <= '1';
        wait until (falling_edge(t_clk));
        wait until (rising_edge(t_clk) and t_o_ready = '1');
        wait for 3 ns;
            t_i_addr    <= (others=>'0');
            t_i_wdata   <= x"00000000";
            t_i_write   <= '0';
            t_i_valid   <= '0';

        wait for 100 ns;

        -- START TEST
        report "START TEST";
        -- emulate password entry, response is OK
        wait until (rising_edge(t_clk));
        wait for 13 ns;
            t_cnt <= 2;
            t_i_addr    <= x"00000000";
            t_i_wdata   <= x"0000BBBB";
            t_i_write   <= '0';
            t_i_valid   <= '1';
        wait until (falling_edge(t_clk));
        wait until (rising_edge(t_clk) and t_o_ready = '1');
        wait for 3 ns;
            t_i_addr    <= (others=>'0');
            t_i_wdata   <= x"00000000";
            t_i_write   <= '0';
            t_i_valid   <= '0';
        -- emulate BSY
        wait until (rising_edge(t_clk));
        wait for 13 ns;
            t_cnt <= 3;
            t_i_addr    <= x"00000010";
            t_i_wdata   <= x"0000000A";
            t_i_write   <= '1';
            t_i_valid   <= '1';
        wait until (falling_edge(t_clk));
        wait until (rising_edge(t_clk) and t_o_ready = '1');
        wait for 3 ns;
            t_i_addr    <= (others=>'0');
            t_i_wdata   <= x"00000000";
            t_i_write   <= '0';
            t_i_valid   <= '0';
        -- -- emulate BSY
        wait until (rising_edge(t_clk));
        wait for 13 ns;
            t_cnt <= 4;
            t_i_addr    <= x"00000010";
            t_i_wdata   <= x"000F0000";
            t_i_write   <= '1';
            t_i_valid   <= '1';
        wait until (falling_edge(t_clk));
        wait until (rising_edge(t_clk) and t_o_ready = '1');
        wait for 3 ns;
            t_i_addr    <= (others=>'0');
            t_i_wdata   <= x"00000000";
            t_i_write   <= '0';
            t_i_valid   <= '0';
        -- close Connection
        wait until (rising_edge(t_clk));
        wait for 13 ns;
            t_cnt <= 5;
            t_i_addr    <= x"00000010";
            t_i_wdata   <= x"000000AA";
            t_i_write   <= '1';
            t_i_valid   <= '1';
        wait until (falling_edge(t_clk));
        wait until (rising_edge(t_clk) and t_o_ready = '1');
        wait for 3 ns;
            t_i_addr    <= (others=>'0');
            t_i_wdata   <= x"00000000";
            t_i_write   <= '0';
            t_i_valid   <= '0';
        
        -- wait
        wait for 100 ns;

        -- emulate GOOD password entry, response is OK
        wait until (rising_edge(t_clk));
        wait for 13 ns;
            t_cnt <= 2;
            t_i_addr    <= x"00000000";
            t_i_wdata   <= x"0000BBBB";
            t_i_write   <= '0';
            t_i_valid   <= '1';
        wait until (falling_edge(t_clk));
        wait until (rising_edge(t_clk) and t_o_ready = '1');
        wait for 3 ns;
            t_i_addr    <= (others=>'0');
            t_i_wdata   <= x"00000000";
            t_i_write   <= '0';
            t_i_valid   <= '0';
        
        wait for 50 ns;

        -- emulate CLOSE
        wait until (rising_edge(t_clk));
        wait for 13 ns;
            t_cnt <= 2;
            t_i_addr    <= x"00000010";
            t_i_wdata   <= x"000000AA";
            t_i_write   <= '0';
            t_i_valid   <= '1';
        wait until (falling_edge(t_clk));
        wait until (rising_edge(t_clk) and t_o_ready = '1');
        wait for 3 ns;
            t_i_addr    <= (others=>'0');
            t_i_wdata   <= x"00000000";
            t_i_write   <= '0';
            t_i_valid   <= '0';
        
        wait for 50 ns;
        
        -- emulate BAD password entry, response is OK
        wait until (rising_edge(t_clk));
        wait for 13 ns;
            t_cnt <= 2;
            t_i_addr    <= x"00000000";
            t_i_wdata   <= x"0000EEEE";
            t_i_write   <= '0';
            t_i_valid   <= '1';
        wait until (falling_edge(t_clk));
        wait until (rising_edge(t_clk) and t_o_ready = '1');
        wait for 3 ns;
            t_i_addr    <= (others=>'0');
            t_i_wdata   <= x"00000000";
            t_i_write   <= '0';
            t_i_valid   <= '0';

        end if;

        if(alarmtest = '1') then
            -- START TEST
            report "START TEST";
            -- emulate password entry, response is OK
            wait until (rising_edge(t_clk));
            wait for 13 ns;
                t_cnt <= 3;
                t_i_addr    <= x"00000000";
                t_i_wdata   <= x"0000BBBB";
                t_i_write   <= '1';
                t_i_valid   <= '1';
            wait until (falling_edge(t_clk));
            wait until (rising_edge(t_clk) and t_o_ready = '1');
            wait for 3 ns;
                t_i_addr    <= (others=>'0');
                t_i_wdata   <= x"00000000";
                t_i_write   <= '0';
                t_i_valid   <= '0';
            -- read, no trigger
            wait until (rising_edge(t_clk));
            wait for 13 ns;
                t_cnt <= 4;
                t_i_addr    <= x"00000010";
                t_i_wdata   <= x"00000000";
                t_i_write   <= '0';
                t_i_valid   <= '1';
            wait until (falling_edge(t_clk));
            wait until (rising_edge(t_clk) and t_o_ready = '1');
            wait for 3 ns;
                t_i_addr    <= (others=>'0');
                t_i_wdata   <= x"00000000";
                t_i_write   <= '0';
                t_i_valid   <= '0';
            -- read trigger?
            wait until (rising_edge(t_clk));
            wait for 13 ns;
                t_cnt <= 2;
                t_i_addr    <= x"00000000";
                t_i_wdata   <= x"00000000";
                t_i_write   <= '0';
                t_i_valid   <= '1';
            wait until (falling_edge(t_clk));
            wait until (rising_edge(t_clk) and t_o_ready = '1');
            wait for 3 ns;
                t_i_addr    <= (others=>'0');
                t_i_wdata   <= x"00000000";
                t_i_write   <= '0';
                t_i_valid   <= '0';
            wait until (rising_edge(t_clk));
            wait for 13 ns;
                t_cnt <= 2;
                t_i_addr    <= x"00000000";
                t_i_wdata   <= x"00000000";
                t_i_write   <= '0';
                t_i_valid   <= '1';
            wait until (falling_edge(t_clk));
            wait until (rising_edge(t_clk) and t_o_ready = '1');
            wait for 3 ns;
                t_i_addr    <= (others=>'0');
                t_i_wdata   <= x"00000000";
                t_i_write   <= '0';
                t_i_valid   <= '0';
            wait until (rising_edge(t_clk));
            wait for 13 ns;
                t_cnt <= 2;
                t_i_addr    <= x"00000000";
                t_i_wdata   <= x"0000FFFF";
                t_i_write   <= '1';
                t_i_valid   <= '1';
            wait until (falling_edge(t_clk));
            wait until (rising_edge(t_clk) and t_o_ready = '1');
            wait for 3 ns;
                t_i_addr    <= (others=>'0');
                t_i_wdata   <= x"00000000";
                t_i_write   <= '0';
                t_i_valid   <= '0';
            wait until (rising_edge(t_clk));
            wait for 13 ns;
                t_cnt <= 2;
                t_i_addr    <= x"00000010";
                t_i_wdata   <= x"0000FFFF";
                t_i_write   <= '1';
                t_i_valid   <= '1';
            wait until (falling_edge(t_clk));
            wait until (rising_edge(t_clk) and t_o_ready = '1');
            wait for 3 ns;
                t_i_addr    <= (others=>'0');
                t_i_wdata   <= x"00000000";
                t_i_write   <= '0';
                t_i_valid   <= '0';
        end if;

        wait;
        end process;
        
        dut : newmop_5
        port map(
            clk     => t_clk,
            reset   => t_reset,
            i_addr  => t_i_addr,
            i_write => t_i_write,
            i_rdata => t_i_rdata,
            i_wdata => t_i_wdata,
            i_wstrb => t_i_wstrb,
            i_error => t_i_error,
            i_valid => t_i_valid,
            i_ready => t_i_ready,
            o_addr  => t_o_addr,
            o_write => t_o_write,
            o_rdata => t_o_rdata,
            o_wdata => t_o_wdata,
            o_wstrb => t_o_wstrb,
            o_error => t_o_error,
            o_valid => t_o_valid,
            o_ready => t_o_ready,
            alarm   => t_alarm,
            ext_wr  => t_ext_wr,
            ext_data_in => t_ext_data_in,
            ext_act_in => t_ext_act_in,
            ext_addr => t_ext_addr,
            re_ext_wr => t_re_ext_wr,
            re_ext_data_in => t_re_ext_data_in,
            re_ext_addr => t_re_ext_addr,
            redirection => t_redirection,
            source => t_source,
            target => t_target
        );


        -- basicIP : process(t_clk)
        -- begin
        --     t_i_error <= '0';
        --     t_i_ready <= '1';
        --     if (rising_edge(t_clk)) then
        --         -- REG_BUS READ
        --         if t_o_write = '0' and t_o_valid = '1' then
        --             t_i_rdata <= t_memory_element(to_integer(unsigned(t_o_addr(4 downto 2))));
        --         end if;

        --         -- REG_BUS WRITE
        --         if (t_o_write = '1' and t_o_valid = '1') then
        --             t_memory_element(to_integer(unsigned(t_o_addr(4 downto 2)))) <= t_o_wdata;
        --         end if;
        --     end if;
        -- end process;

        basicIP : process(t_clk)
        begin
            t_i_error <= '0';
            
            -- wait until (rising_edge(t_clk));
            if (rising_edge(t_clk)) then
                t_i_ready <= '0';
                if (passtest = '1') then
                    t_i_rdata <= (others=>'0'); -- simulating debug protocol
                end if;
            -- REG_BUS READ
            if t_o_write = '0' and t_o_valid = '1' then
                -- wait for 5 ns;
                t_i_rdata <= t_memory_element(to_integer(unsigned(t_o_addr(6 downto 4))));
                t_i_ready <= '1';
            end if;

            -- REG_BUS WRITE
            if (t_o_write = '1' and t_o_valid = '1') then
                t_memory_element(to_integer(unsigned(t_o_addr(6 downto 4)))) <= t_o_wdata;
                t_i_ready <= '1';
            end if;
            end if;

            t_i_ready <= '1';

        end process;

end architecture tb;