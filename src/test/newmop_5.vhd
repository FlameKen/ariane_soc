-- this is the jumping mop
-- prototype by B. Tan
library ieee;
library work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.instr_pkg2.all;

entity newmop_5 is
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
        re_ext_addr : in unsigned(2 downto 0);
        redirection   : out std_logic;
        source          : out unsigned (3 downto 0);
        target          : out unsigned(3 downto 0);
        idle            : out std_logic

    );
end entity newmop_5;

architecture behavior of newmop_5 is
    component gencount is
        generic (COUNT_WIDTH : integer := 32);
        port(
            reset : in std_logic;
            clk : in std_logic;
            count_en : in std_logic;
            count_value : out unsigned(COUNT_WIDTH - 1 downto 0)
        );
    end component gencount;
    
    component comp is
		generic(DATA_SIZE : integer := 32);
		port(
            a : in unsigned(DATA_SIZE - 1 downto 0);
            b : in unsigned(DATA_SIZE - 1 downto 0);
            output : out std_logic_vector(3 downto 0) -- GT, LT, EQ, NE
        );
    end component comp;
    
    component generic_flow_mem is
        generic (initmem : flow_mem := (others=>(others=>'0')));
        port (
            clk		:	in std_logic;
            address	:	in unsigned(AL - 1 downto 0);
            data_in	:	in std_logic_vector(DW - 1 downto 0);
            rd		: 	in std_logic;
            wr		:	in std_logic;
            q		:	out std_logic_vector(DW - 1 downto 0);
            rdy		:	out std_logic
        );
    end component;

    component generic_act_mem is
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
    end component;

    component generic_red_mem is
        generic (initmem : flow_mem3 := (others=>(others=>'0')));
        port (
            clk		:	in std_logic;
            address	:	in unsigned(AL3 - 1 downto 0);
            data_in	:	in std_logic_vector(DW3 - 1 downto 0);
            rd		: 	in std_logic;
            wr		:	in std_logic;
            q		:	out std_logic_vector(DW3 - 1 downto 0);
            rdy		:	out std_logic
        );
    end component;
    signal fc, fc_address,next_fc : unsigned(2 downto 0); 
    signal current_instr : std_logic_vector(DW-1 downto 0);
    signal sel_nextA : std_logic_vector(1 downto 0) := "00";
    signal sel_nextB : std_logic_vector(2 downto 0) := "000";
    signal comp_mode : std_logic_vector(1 downto 0) := "00";
    signal transact_select : std_logic := '0';
    signal transact_event : std_logic := '0';
    signal rw_select : std_logic := '0';
    signal rw_event : std_logic := '0';
    signal r00, r01, r10, r11 : std_logic_vector(31 downto 0) := (others=>'0'); 
    signal r000, r001, r010, r011 : std_logic_vector(31 downto 0) := (others=>'0'); 
    signal r_i_addr  : std_logic_vector(31 downto 0);
    signal r_i_rdata : std_logic_vector(31 downto 0);
    signal r_i_wdata : std_logic_vector(31 downto 0);
    signal r_i_valid : std_logic;
    signal r_i_ready : std_logic;
    signal r_i_write : std_logic;
    signal c0n, r_c0n : std_logic;
    signal comp0 : std_logic_vector(3 downto 0);
    signal next_compA, next_compb : std_logic_vector(31 downto 0);
    -- second Comp next side
    signal sel2_nextA, sel2_nextB : std_logic_vector(1 downto 0) := "00";
    signal next2_compA, next2_compb : std_logic_vector(31 downto 0);
    signal comp2 : std_logic_vector(3 downto 0);
    signal c2n : std_logic;
    signal comp2_mode : std_logic_vector(1 downto 0) := "00";
    --- ASSERTION SIGNALS
    -- comp i/o
    signal ac0_compA    : std_logic_vector(31 downto 0);
    signal ac0_compB    : std_logic_vector(31 downto 0);
    signal ac0_out      : std_logic_vector(3 downto 0);
    signal ac0          : std_logic;
    -- comp mux
    signal sel_acA      : std_logic_vector(2 downto 0);
    signal sel_acB      : std_logic_vector(1 downto 0);
    signal ac0_mode     : std_logic_vector(1 downto 0);
    -- event/cycle counter
    signal counter      : unsigned(31 downto 0);
    signal cnt_reset    : std_logic;
    signal cnt_ctrl     : std_logic_vector(1 downto 0);
    -- event control
    signal ac0_event_select : std_logic_vector(1 downto 0);
    signal ac0_event : std_logic;
    signal ac0_rw_event : std_logic;
    signal ac0_rw_select : std_logic;
    -- pending action
    signal action_output : std_logic_vector(DW2 - 1 downto 0);
    signal pending_action : std_logic_vector(7 downto 0);
    -- register file
    signal rfA_wr : std_logic;
    signal rfB_wr : std_logic;
    signal rf_ext_sel : std_logic;
    signal rf_extin : std_logic_vector(31 downto 0);
    signal rf_rfin : std_logic_vector(31 downto 0);
    signal rfA_in : std_logic_vector(31 downto 0);
    signal rfB_in : std_logic_vector(31 downto 0);
    signal rfA_dest : std_logic_vector(1 downto 0);
    signal rfB_dest : std_logic_vector(1 downto 0);
    -- alarm
    signal int_alarm : std_logic;
    --- Redirection SIGNALS
    -- comp i/o
    signal red_compA    : std_logic_vector(31 downto 0);
    signal red_compB    : std_logic_vector(31 downto 0);
    signal red_out      : std_logic_vector(3 downto 0);
    signal red          : std_logic;
    -- comp mux
    signal sel_redA      : std_logic_vector(1 downto 0);
    signal sel_redB      : std_logic_vector(1 downto 0);
    signal red_mode     : std_logic_vector(1 downto 0);
    -- event/cycle counter
    -- signal counter      : unsigned(31 downto 0);
    -- signal cnt_reset    : std_logic;
    -- signal cnt_ctrl     : std_logic_vector(1 downto 0);
    -- event control
    signal red00, red01, red10, red11 : std_logic_vector(31 downto 0) := (others=>'0'); 
    signal red_event_select : std_logic := '0';
    signal red_event : std_logic;
    signal red_rw_event : std_logic;
    signal red_rw_select : std_logic;
    -- pending action
    signal redirection_output : std_logic_vector(DW3 - 1 downto 0);
    signal now_red, red_address,next_red : unsigned(2 downto 0); 
    -- signal source, target : unsigned (3 downto 0);
    begin

        o_addr   <= i_addr;
        o_write  <= i_write;
        
        o_rdata  <= r00 when ac0 = '1' and ac0_event = '1' and ac0_rw_event = '1' and pending_action(7 downto 6) = REPL and pending_action(3 downto 2) = "10" else i_rdata;
        
        o_wdata  <= r00 when ac0 = '1' and ac0_event = '1' and ac0_rw_event = '1' and pending_action(7 downto 6) = REPL and pending_action(3 downto 2) = "01" else i_wdata;

        o_wstrb  <= i_wstrb;
        o_error  <= i_error;

        o_valid  <= '0' when ac0 = '1' and ac0_event = '1' and ac0_rw_event = '1' and pending_action(7 downto 6) = REPL and pending_action(5 downto 4) = "10" else i_valid;

        o_ready  <= '1' when ac0 = '1' and ac0_event = '1' and ac0_rw_event = '1' and pending_action(7 downto 6) = REPL and pending_action(5 downto 4) = "10" else i_ready;

        fc_address <= ext_addr when ext_wr = '1' else fc;
        red_address <= re_ext_addr when re_ext_wr = '1' else now_red;

        -- let's start off with the datapath parts for the next side

        next_comp : comp
        generic map(DATA_SIZE => 32)
        port map (a => unsigned(next_compA), b => unsigned(next_compB), output => comp0);

        -- mux control
        with sel_nextA select
            next_compA <=   r_i_addr when "00",
                            r_i_rdata when "01",
                            r_i_wdata when "10",
                            (others => '0') when others;
        
        -- mux control
        with sel_nextB select
            next_compB <=   r00 when "000",
                            r01 when "001",
                            r10 when "010",
                            r11 when "011",
                            r000 when "100",
                            r001 when "101",
                            r010 when "110",
                            r011 when "111",
                            (others => '0') when others;
              
        -- next_comp2 : comp
        -- generic map(DATA_SIZE => 32)
        -- port map (a => unsigned(next2_compA), b => unsigned(next2_compB), output => comp2);

        -- -- mux control
        -- with sel2_nextA select
        --     next2_compA <=  r_i_addr when "00",
        --                     r_i_rdata when "01",
        --                     r_i_wdata when "10",
        --                     std_logic_vector(counter) when "11",
        --                     (others => '0') when others;
        
        -- -- mux control
        -- with sel2_nextB select
        --     next2_compB <=  r00 when "00",
        --                     r01 when "01",
        --                     r10 when "10",
        --                     r11 when "11",
        --                     (others => '0') when others;

        with comp_mode select
            c0n <=  comp0(3) when "00", 
                    comp0(2) when "01", 
                    comp0(1) when "10", 
                    comp0(0) when "11", 
                    '0' when others;
        
        -- with comp2_mode select
        --     c2n <=  comp2(3) when "00", 
        --             comp2(2) when "01", 
        --             comp2(1) when "10", 
        --             comp2(0) when "11", 
        --             '0' when others;
                        
        with transact_select select
            transact_event <=   r_i_valid when '0',
                                r_i_ready when '1',
                                '0' when others;

        with rw_select select
            rw_event <=     r_i_write when '0',
                            not r_i_write when '1',
                            '0' when others;

        process(clk, reset)
            variable delay : std_logic;
        begin
            if( fc = "000")then
                idle <= '1';
            else 
                idle <= '0';
            end if;
                    
            if (reset = '1') then
                fc <= (others=> '0');
                -- r00 <= x"00000010"; --(others => '0');
                -- r01 <= x"00000020"; --(others => '0');
                -- r10 <= x"00000000"; --(others => '0');
                -- r11 <= x"00000040"; --(others => '0');
                delay := '0';
            elsif(rising_edge(clk)) then
                if (i_valid = '1') then
                    r_i_addr  <= i_addr;
                    r_i_wdata <= i_wdata;
                    r_i_write <= i_write;
                end if;
                cnt_reset <= '0';
                r_i_valid <= i_valid;
                r_i_ready <= i_ready;

                if (i_ready = '1') then
                    r_i_rdata <= i_rdata;
                end if;

                if (delay = '1') then
                    delay := '0'; -- delay before making a decision as it takes a cycle to get the next set of control signals
                elsif (c0n = '1' and transact_event = '1') then --and c2n = '1' and transact_event = '1') then
                -- if (r_c0n = '1' and transact_event = '1') then
                    if(transact_select = '0') then
                        if (rw_event = '1') then
                            -- report "SAT MASTER REQ.";
                            fc <= next_fc;
                            delay := '1';
                            cnt_reset <= '1';
                        end if;
                    else
                        -- report "SAT SLAVE RESP.";
                        fc <= next_fc;
                        delay := '1';
                        cnt_reset <= '1';
                    end if;
                end if;
            end if;
        end process;
        
        -- next_fc <= unsigned(current_instr(10 downto 8));
        -- comp_mode       <= current_instr(7 downto 6);
        -- sel_nextA       <= current_instr(5 downto 4);
        -- sel_nextB       <= current_instr(3 downto 2);
        -- transact_select <= current_instr(1);
        -- rw_select       <= current_instr(0);
        next_fc <= unsigned(current_instr(11 downto 9));
        comp_mode       <= current_instr(8 downto 7);
        sel_nextA       <= current_instr(6 downto 5);
        sel_nextB       <= current_instr(4 downto 2);
        transact_select <= current_instr(1);
        rw_select       <= current_instr(0);

        
            

        gfm : generic_flow_mem
        generic map (initmem => 
        (
            "001100010000",
            "010100010100",
            "011100011000",
            "100100011100",
            "101101000100", -- set start  = 1
            "110100100101",--read start = 1
            "111101000000",-- write start  = 0
            "000100001001"--done = 1 ->finish
        )
        ) 
        port map (
            clk		=> clk,
            address	=> fc_address,
            data_in	=> ext_data_in,
            rd		=> '1',
            wr		=> ext_wr,
            q		=> current_instr,
            rdy		=> open
        );


        -------- Assertion Side ------------------------------------

        assert_comp0 : comp
        generic map(DATA_SIZE => 32)
        port map (a => unsigned(ac0_compA), b => unsigned(ac0_compB), output => ac0_out);

        -- mux control
        with sel_acA select
            ac0_compA <=    r00 when BIGSEL_r00,
                            r01 when BIGSEL_r01,
                            r10 when BIGSEL_r10,
                            r11 when BIGSEL_r11,
                            i_addr	when BIGSEL_addr,	
                            i_rdata	when BIGSEL_rdata,	
                            i_wdata	when BIGSEL_wdata,	
                            std_logic_vector(counter) when BIGSEL_count,
                            (others => '0') when others;
        -- mux control
        with sel_acB select
            ac0_compB <=    r00 when SEL_r00,
                            r01 when SEL_r01,
                            r10 when SEL_r10,
                            r11 when SEL_r11,
                            (others => '0') when others;
        -- comp control
        with ac0_mode select
            ac0 <=  ac0_out(3) when GT, 
                    ac0_out(2) when LT, 
                    ac0_out(1) when ET, 
                    ac0_out(0) when NE, 
                    '0' when others;
        -- event control
        with ac0_event_select select
            ac0_event <=    i_valid when A_EVENT_valid,
                            i_ready when A_EVENT_ready,
                            reset   when A_EVENT_reset,
                            clk     when A_EVENT_clock,
                            '0'     when others;
        -- read-write control -- only care if legit transaction
        with ac0_rw_select select
            ac0_rw_event <= i_write and i_valid when '0',
                            (not i_write) and i_valid  when '1',
                            '0' when others;

        cntr: process(clk, reset, cnt_reset)
        begin
            if (reset = '1' or cnt_reset = '1') then
                counter <= (others=>'0');
            elsif (rising_edge(clk)) then
                counter <= counter;
                case cnt_ctrl is
                    when CNTCTRL_dis =>
                        counter <= counter;
                    when CNTCTRL_clk =>
                        counter <= counter + 1;
                    when CNTCTRL_com =>
                        if (ac0 = '1' and ac0_event = '1' and ac0_rw_event = '1') then
                            counter <= counter + 1;
                        else
                            counter <= counter;
                        end if;
                    when others =>
                        counter <= counter;
                end case;
            end if;
        end process;      

        rf_block : process(clk)
                variable delay : std_logic;
            begin
            
            if (reset = '1') then
                r00 <= x"00000000"; --(others => '0');
                r01 <= x"00000001"; --(others => '0');
                r10 <= x"0000403c"; --(others => '0');
                r11 <= x"000000AA"; --(others => '0');
                r000 <= x"00004080";
                r001 <= x"00004004";
                r010 <= x"00004040";
                r011 <= x"00004000";
                delay := '0';
            elsif (rising_edge(clk)) then
                r00 <= r00;
                r01 <= r01;
                r10 <= r10;
                r11 <= r11;
                r000 <= r000;
                r001 <= r001;
                r010 <= r010;
                r011 <= r011;

                -- generally speaking, only catch the beginning (if working on request)
                -- or catch the end, if working on response
                if (ac0_event = '1' and ac0_rw_event = '1') then -- and delay = '0') then
                    report "yes";
                    if (rfA_wr = '1') then
                        report "SAVE A";
                        case rfA_dest is
                            when SEL_r00 =>
                                r00 <= rfA_in;
                            when SEL_r01 =>
                                r01 <= rfA_in;
                            when SEL_r10 =>
                                r10 <= rfA_in;
                            when SEL_r11 =>
                                r11 <= rfA_in;
                            when others =>
                        end case;
                    end if;

                    if (rfB_wr = '1') then
                        report "SAVE B";
                        case rfB_dest is
                            when SEL_r00 =>
                                r00 <= rfB_in;
                            when SEL_r01 =>
                                r01 <= rfB_in;
                            when SEL_r10 =>
                                r10 <= rfB_in;
                            when SEL_r11 =>
                                r11 <= rfB_in;
                            when others =>
                        end case;
                    end if;
                    delay := '1';
                else 
                    delay := '0';
                end if;
            end if;

        end process;

        with pending_action(7 downto 6) select
            int_alarm <= ac0 when ALRM,
                     '0' when others;

        alrm_latch: process(clk,reset)
            variable delay : std_logic := '0';
        begin
            if (reset = '1') then
                alarm <= '0';
            elsif (rising_edge(clk))then
                -- only raise the alarm on the second cycle, i.e., after the result is actually returned...?
                
                if (int_alarm = '1' and ac0_event = '1' and ac0_rw_event = '1') then-- and delay = '1') then
                    alarm <= '1';
                    delay := '0';
                elsif (int_alarm = '1' and delay = '0') then
                    delay := '1';
                end if;
            end if;
        end process;
        

        with pending_action(7 downto 6) select
            rfA_wr <=   ac0 and '1' when STOR,
                        ac0 and '1' when STMV,
                                    -- when ALRM,
                                    -- when REPL,
                        '0' when others;

        with pending_action(7 downto 6) select
            rfB_wr <=   ac0 and '1' when STMV,
                                    -- when ALRM,
                                    -- when REPL,
                        '0' when others;

        rf_ext_sel <=   '1' when (((pending_action(7 downto 6) = STOR) and pending_action(0) = '1') or pending_action(7 downto 6) = STMV) else '0';

        with pending_action(5 downto 4) select
            rf_extin <= i_addr when SEL_addr,
                        i_rdata when SEL_rdata,
                        i_wdata when SEL_wdata,
                        std_logic_vector(counter) when SEL_count,
                        (others=>'0') when others;

        with pending_action(5 downto 4) select
            rf_rfin <=  r00  when SEL_r00,
                        r01  when SEL_r01,
                        r10  when SEL_r10,
                        r11  when SEL_r11,
                        (others=>'0') when others;
                                    
        with rf_ext_sel select
            rfA_in <= rf_extin when '1', rf_rfin when others;

        with pending_action(3 downto 2) select
            rfB_in <=   r00  when SEL_r00,
                        r01  when SEL_r01,
                        r10  when SEL_r10,
                        r11  when SEL_r11,
                        (others=>'0') when others;
        
        rfA_dest <= pending_action(3 downto 2);
        rfB_dest <= pending_action(1 downto 0);

        gam : generic_act_mem
        generic map (initmem => 
        (
            "10101100010000100101",
            "10110110000010000000",
            "10101100010000100101",
            "11000011000000000011",
            "00000000000000000000",
            "00000000000000000000",
            "00000000000000000000",
            "00000000000000000000"
        )
        ) 
        port map (
            clk		=> clk,
            address	=> fc_address,
            data_in	=> ext_act_in,
            rd		=> '1',
            wr		=> ext_wr,
            q		=> action_output,
            rdy		=> open
        );

        ac0_mode            <= action_output(19 downto 18);   
        sel_acA             <= action_output(17 downto 15);
        sel_acB             <= action_output(14 downto 13);
        pending_action      <= action_output(12 downto 5);
        cnt_ctrl            <= action_output(4 downto 3);
        ac0_rw_select       <= action_output(2);
        ac0_event_select    <= action_output(1 downto 0);

        -- action		src	dest	
        -- STOR	store	00	xxx	xx	?
        -- STMV	store & move	01	xx	xx	xx
        -- ALRM	alarm	10	-	-	-
        -- REPL	replace	11	A	B	C
                            
        --             A	B	C
        --         00	none	none	none
        --         01	o_valid	o_wdata	o_addr
        --         10	o_ready	o_rdata	-
        --         11	-	-	-
--------------redirection side--------------------------------------------------------

        redirect_comp0 : comp
        generic map(DATA_SIZE => 32)
        port map (a => unsigned(red_compA), b => unsigned(red_compB), output => red_out);

        -- mux control
        with sel_redA select
            red_compA <=    r_i_addr when "00",
                            r_i_rdata when "01",
                            r_i_wdata when "10",
                            (others => '0') when others;
        -- mux control
        with sel_redB select
            red_compB <=    red00 when "00",
                            red01 when "01",
                            red10 when "10",
                            red11 when "11",
                            (others => '0') when others;
        -- comp control
        with red_mode select
            red <=  red_out(3) when GT, 
                    red_out(2) when LT, 
                    red_out(1) when ET, 
                    red_out(0) when NE, 
                    '0' when others;
        -- event control
        with red_event_select select
            red_event <=    r_i_valid when '0',
                            r_i_ready when '1',
                            '0' when others;
        -- read-write control -- only care if legit transaction
        with red_rw_select select
            red_rw_event <= i_write and i_valid when '0',
                            (not i_write) and i_valid  when '1',
                            '0' when others;
        

        grm : generic_red_mem
        generic map (initmem => 
        (
            "0110000100011011110",
            "1010011011001100000",
            "1110110001000011001",
            "1100001100000001011",
            "0110000100010111110",
            "1010011011001000010",
            "1110110001000010011",
            "1100001100000000111"
        )
        ) 
        port map (
            clk		=> clk,
            address	=> red_address,
            data_in	=> re_ext_data_in,
            rd		=> '1',
            wr		=> re_ext_wr,
            q		=> redirection_output,
            rdy		=> open
        );
        process(clk, reset)
            variable delay : std_logic;
        begin
            if (reset = '1') then
                now_red <= (others=> '0');
                redirection <= '0';
                red00 <= x"00000001"; --(others => '0');
                red01 <= x"00000010"; --(others => '0');
                red10 <= x"000000FF"; --(others => '0');
                red11 <= x"00000004"; --(others => '0');
            elsif(rising_edge(clk)) then
                red00 <= red00;
                red01 <= red01;
                red10 <= red10;
                red11 <= red11;
                if (red = '1' and red_event = '1') then --and c2n = '1' and transact_event = '1') then
                    if(red_event_select = '0') then
                        if (red_rw_event = '1') then
                            -- report "SAT MASTER REQ.";
                            now_red <= next_red;
                            redirection <= '1';
                        else
                            redirection <= '0';
                        end if;
                    else
                        now_red <= next_red;
                        redirection <= '1';
                    end if;
                else 
                    redirection <= '0';
                end if;
            end if;
        end process;

        next_red            <= unsigned (redirection_output(18 downto 16));   
        red_mode            <= redirection_output(15 downto 14);   
        sel_redA             <= redirection_output(13 downto 12);
        sel_redB             <= redirection_output(11 downto 10);
        red_event_select    <= redirection_output(9);
        red_rw_select       <= redirection_output(8);
        source              <= unsigned(redirection_output(7 downto 4));
        target              <= unsigned(redirection_output(3 downto 0));
end architecture behavior;