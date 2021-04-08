-- this is the jumping mop
-- prototype by B. Tan
library ieee;
library work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.instr_pkg2.all;

entity remop_redirec is
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





        override_in     : in std_logic;
        override_out    : out std_logic;
        override_dataout: out std_logic_vector(32 downto 0);
        override_datain : in std_logic_vector(32 downto 0); 
        ext_wr          : in std_logic;
        ext_data_in     : in std_logic_vector(DW-1 downto 0);
        ext_act_in      : in std_logic_vector(DW2-1 downto 0);
        ext_addr        : in unsigned(AL-1 downto 0);
        re_ext_wr       : in std_logic;
        re_ext_data_in  : in std_logic_vector(DW3-1 downto 0);
        re_ext_addr     : in unsigned(2 downto 0);
        redirection     : out std_logic;
        source          : out unsigned (3 downto 0);
        target          : out unsigned(3 downto 0);
        idle            : out std_logic

    );
end entity remop_redirec;

architecture behavior of remop_redirec is
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
    signal fc, fc_address,next_fc : unsigned(AL-1 downto 0); 
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
    signal next_compA, next_compB : std_logic_vector(31 downto 0);
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
    signal store_value : stored := (others=>(others=>'0'));
    signal stored_counter : unsigned(AL -1 downto 0);
    signal stored_counter2 : unsigned(AL -1 downto 0);
    signal rdata_override : std_logic;
    signal wdata_override : std_logic;
    signal save_counter : unsigned(AL -1 downto 0);
    signal save_value : stored := (others=>(others=>'0'));
    signal redirection_control : std_logic := '0';
    signal intermediate_o_addr : std_logic_vector(31 downto 0);
    signal intermediate_o_wdata : std_logic_vector(31 downto 0);
    signal intermediate_o_rdata : std_logic_vector(31 downto 0);
    signal intermediate_o_valid : std_logic;
    signal intermediate_o_write : std_logic;
    signal intermediate_o_ready : std_logic;
    signal check                : std_logic;
    signal spare_00,spare_01,spare_02,spare_03 : std_logic_vector(31 downto 0) := (others=>'0'); 
    signal start_to_redirect :std_logic;
    begin

        o_addr   <= next_compA when (rdata_override = '1' or wdata_override = '1') else i_addr;
        o_write  <= '1' when  wdata_override = '1'  else i_write;
        
        o_rdata  <= red00 when rdata_override = '1' else i_rdata;
        
        o_wdata  <= red00 when wdata_override='1'  else i_wdata;

        o_wstrb  <= i_wstrb;
        o_error  <= i_error;

        o_valid  <= '1' when (rdata_override = '1' or wdata_override='1')  else i_valid;

        o_ready  <= '1' when rdata_override = '1' else i_ready;

        fc_address <= ext_addr when ext_wr = '1' else fc;
        red_address <= re_ext_addr when re_ext_wr = '1' else now_red;

        -- let's start off with the datapath parts for the next side

        next_comp : comp
        generic map(DATA_SIZE => 32)
        port map (a => unsigned(next_compA), b => unsigned(next_compB), output => comp0);
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
              

        with comp_mode select
            c0n <=  comp0(3) when "00", 
                    comp0(2) when "01", 
                    comp0(1) when "10", 
                    comp0(0) when "11", 
                    '0' when others;

        process(clk, reset)
        begin
            if(wdata_override='1')then
                intermediate_o_wdata <= red00;
                intermediate_o_rdata <= i_rdata;
                intermediate_o_write <= '1';
                intermediate_o_ready <= i_ready;
            else 
                intermediate_o_wdata <= i_wdata;
                intermediate_o_rdata <= red00;
                intermediate_o_write <= i_write;
                intermediate_o_ready <= '1';
            end if;
            -- copy for o_addr
            intermediate_o_addr <= red01;    
            intermediate_o_valid <= '1';

            if (redirection_control = '1')then
                case sel_nextA is 
                when "00" =>
                    next_compA <= intermediate_o_addr;
                when "01" =>
                next_compA <= intermediate_o_rdata;
                when "10" =>
                next_compA <= intermediate_o_wdata;
                when others =>
                next_compA <= (others => '0');    
                end case;

                case (transact_select) is 
                when '0' =>
                transact_event <=   intermediate_o_valid;
                when '1'=>
                transact_event <=   intermediate_o_ready;
                when others =>
                transact_event <= '0';
                end case;

                case (rw_select) is 
                when '0' =>
                rw_event <=     intermediate_o_write;
                when '1'=>
                rw_event <=     not intermediate_o_write;
                when others =>
                rw_event <= '0';
                end case;
            else 
                case (sel_nextA) is 
                when "00" =>
                next_compA <= r_i_addr;
                when "01" =>
                next_compA <= r_i_rdata;
                when "10" =>
                next_compA <= r_i_wdata;
                when others =>
                next_compA <= (others => '0');   
                end case;

                case (transact_select) is 
                when '0' =>
                transact_event <=   r_i_valid;
                when '1'=>
                transact_event <=   r_i_ready;
                when others =>
                transact_event <= '0';
                end case;

                case (rw_select) is 
                when '0' =>
                rw_event <=     r_i_write;
                when '1'=>
                rw_event <=     not r_i_write;
                when others =>
                rw_event <= '0';
                end case;

            end if;
        end process;

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
                delay := '0';
                stored_counter <= (others=>'0');
                wdata_override <= '0';
                rdata_override <= '0';
                check <= '0';
                red00 <= x"00000AAA"; --(others => '0');
                red01 <= x"00000010"; --(others => '0');
                red10 <= x"000000FF"; --(others => '0');
                red11 <= x"00000004"; --(others => '0');
            elsif(rising_edge(clk)) then
                if (i_valid = '1') then
                    r_i_addr  <= i_addr;
                    r_i_wdata <= i_wdata;
                    r_i_write <= i_write;
                end if;
                cnt_reset <= '0';
                r_i_valid <= i_valid;
                r_i_ready <= i_ready;
                -- red00<=red00;
                red10 <= red10;
                red11 <= red11;

                if (i_ready = '1') then
                    r_i_rdata <= i_rdata;
                end if;
                if (redirection_control = '1')then
                    -- get the right address
                    red01 <= next_compB;
                    red00 <= save_value(to_integer(stored_counter))(31 downto 0) ;
                    if(c0n = '1' and check = '0')then
                        check <= '1';
                        if(save_value(to_integer(stored_counter))(32) = '1')then
                            wdata_override <= '1';
                            rdata_override <='0';
                        else
                            rdata_override <='1';
                            wdata_override <= '0';
                        end if;
                        fc <= next_fc;
                        stored_counter <= unsigned(next_fc);
                    else 
                        rdata_override <='0';
                        check <= '0';
                        wdata_override <= '0';
                    end if;
                    
                    -- the 32th bit is to see it's a write or read transaction
                    
                    if(stored_counter = 2**AL - 3)then
                        redirection_control <= '0';
                    end if;
                else 
                        red01 <= r_i_addr;
                        rdata_override <='0';
                        wdata_override <= '0';
                end if;

                if (delay = '1') then
                    delay := '0'; -- delay before making a decision as it takes a cycle to get the next set of control signals
                elsif (c0n = '1' and transact_event = '1' and override_in = '0' and redirection_control = '0') then --and c2n = '1' and transact_event = '1') then
                -- if (r_c0n = '1' and transact_event = '1') then
                    if(transact_select = '0') then
                        if (rw_event = '1') then
                            -- report "SAT MASTER REQ.";
                            fc <= next_fc;
                            stored_counter <= stored_counter + 1;
                            delay := '1';
                            -- store the previous transactions
                            if(rw_select = '1')then
                                store_value(to_integer(stored_counter)) <= ('0' & r_i_rdata);
                            else 
                                store_value(to_integer(stored_counter)) <= ('1' & r_i_wdata);
                            end if;
                            cnt_reset <= '1';
                        end if;
                    else
                        -- report "SAT SLAVE RESP.";
                        fc <= next_fc;
                        stored_counter <= stored_counter + 1;
                        delay := '1';
                        cnt_reset <= '1';
                    end if;
                elsif (override_in = '1')then
                    -- accept redirected transactions
                    redirection_control <= '1';
                    delay := '1';
                end if;
            end if;
        end process;
        
        next_fc <= unsigned(current_instr(12 downto 9));
        comp_mode       <= current_instr(8 downto 7);
        sel_nextA       <= current_instr(6 downto 5);
        sel_nextB       <= current_instr(4 downto 2);
        transact_select <= current_instr(1);
        rw_select       <= current_instr(0);

        
            

        gfm : generic_flow_mem
        generic map (initmem => 
        (
            "0001100010000", -- key selection
            "0010100010100", -- write plain text
            "0011100000000", -- write plain text
            "0100100000000", -- write plain text
            "0101100000000", -- write plain text
            "0110100011000", -- write state text
            "0111100000000", -- write state text
            "1000100000000", -- write state text
            "1001100000000", -- write state text
            "1010100011100", -- set start = 0
            "1011100011100", -- set start  = 1
            "1100100011101", --read start = 1
            "1101100011100",-- write start  = 0
            "0000100001001",--done = 1 ->finish
            "0001100010000",
            "0010100010100"
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
                delay := '0';
                r00 <= x"00000000"; --(others => '0');
                r01 <= x"00000001"; --(others => '0');
                r10 <= x"1010002c"; --(others => '0');
                r11 <= x"000000AA"; --(others => '0');
                r000 <= x"10100080";
                r001 <= x"10100010";
                r010 <= x"1010004C";
                r011 <= x"10100000";
                
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
                if (ac0_event = '1' and ac0_rw_event = '1' and redirection_control = '0') then -- and delay = '0') then
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
                elsif (c0n = '1' and redirection_control = '1')then
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
            rf_extin <= std_logic_vector(unsigned(red01) - 4) when SEL_addr,
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
            "10000000000000000000",
            "11100000000000100001",
            "11100000000000100001",
            "11100000000000100001",
            "11100000000000100001",
            "11100000000000100001",
            "11100000000000100001",
            "11100000000000100001",
            "11100000000000100001",
            "11100000000000100001",
            "11100000000000100001",
            "11100000000000100001",
            "11100000000000100001",
            "11100000000000100001",
            "10000000000000000000",
            "10000000000000000000"
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
            red_rw_event <= r_i_write and r_i_valid when '0',
                            (not r_i_write) and r_i_valid  when '1',
                            '0' when others;
        

        grm : generic_red_mem
        generic map (initmem => 
        (
            "0011010000001011110",
            "1101001101100100000",
            "1111011000100001001",
            "1101000110000000011",
            "0110100010001011110",
            "1010011101100100000",
            "1110111000100001001",
            "1100001110000000011"
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
                save_counter <= (others=>'1');
                stored_counter2 <= (others=>'0');
                override_dataout <= (others=>'0');
                override_out <= '0';
                start_to_redirect <= '0';
            elsif(rising_edge(clk)) then
                -- override_out <= override_out;
                -- override_dataout <= override_dataout;
                save_counter <= save_counter;
                start_to_redirect <= start_to_redirect;
                stored_counter2 <= stored_counter2;
                if (red = '1' and red_event = '1') then --and c2n = '1' and transact_event = '1') then
                    if(red_event_select = '0') then
                        if (red_rw_event = '1') then
                            now_red <= next_red;
                            redirection <= '1';
                            override_out <= '1';
                            start_to_redirect <= '1';
                        -- else
                        --     redirection <= '0';
                        end if;
                    else
                        now_red <= next_red;
                        redirection <= '1';
                    end if;
                else 
                    redirection <= '0';
                end if;
                if(start_to_redirect = '1')then
                    stored_counter2 <= stored_counter2 + 1;
                    if(stored_counter2 = 2**AL - 1)then
                        override_out <= '0';
                        start_to_redirect <='0';
                    end if;
                    override_dataout <= store_value(to_integer(stored_counter2));
                end if;
                if(override_in = '1')then
                    save_counter <= save_counter+1;
                    save_value(to_integer(save_counter)) <= override_datain;
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