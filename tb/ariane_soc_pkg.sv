// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Florian Zaruba, ETH Zurich
// Description: Contains SoC information as constants
package ariane_soc;
    // M-Mode Hart, S-Mode Hart
    localparam NumTargets = 2;
    localparam NumSources = 5; 
    localparam PLICIdWidth = 3;
    localparam ParameterBitwidth = PLICIdWidth;
    localparam      ERROR_REDIRECT = 64'hFFF0FFF00000000;
    localparam      ERROR_REDIRECT_STOP = 64'hFFFFFFF00000000;

    // typedef enum int unsigned {
    //     DRAM     = 0,
    //     GPIO     = 1,//General-purpose input/output
    //     Ethernet = 2,
    //     SPI      = 3,
    //     SHA256   = 4,    
    //     AES      = 5,    
    //     UART     = 6,    //Universal asynchronous receiver-transmitter
    //     PLIC     = 7,    
    //     CLINT    = 8,    
    //     DMA      = 9,    
    //     PKT      = 10,   
    //     AcCt     = 11,   
    //     REGLK    = 12,   
    //     ROM      = 13,   
    //     Debug    = 14
    // } axi_slaves_t;
        typedef enum int unsigned {
        DRAM     = 0,
        GPIO     = 1,//General-purpose input/output
        Ethernet = 2,
        SPI      = 3,
        SHA256   = 4,    
        AES      = 5,    
        UART     = 6,    //Universal asynchronous receiver-transmitter
        PLIC     = 7,    
        CLINT    = 8,    
        DMA      = 9,    
        PKT      = 10,   
        AcCt     = 11,   
        REGLK    = 12,   
        ROM      = 13,   
        AES2     = 14,    
        TEST     = 15,    
        Debug2   = 16,
        MOP      = 17,
        Debug    = 18
    } axi_slaves_t;

    localparam NB_PERIPHERALS = Debug + 1;
    localparam LOG_N_INIT = $clog2(NB_PERIPHERALS);
    // localparam NB_PERIPHERALS = 18;

    localparam logic[63:0] DebugLength    = 64'h1000;
    localparam logic[63:0] Debug2Length   = 64'h1000;
    localparam logic[63:0] AES2Length     = 64'h1000;
    localparam logic[63:0] TESTLength     = 64'h1000;
    localparam logic[63:0] MOPLength      = 64'h1000;
    localparam logic[63:0] ROMLength      = 64'h10000;
    localparam logic[63:0] REGLKLength    = 64'h10000;
    localparam logic[63:0] AcCtLength     = 64'h10000;
    localparam logic[63:0] PKTLength      = 64'h10000;
    localparam logic[63:0] DMALength      = 64'h10000;
    localparam logic[63:0] CLINTLength    = 64'hC0000;
    localparam logic[63:0] PLICLength     = 64'h3FF_FFFF;
    localparam logic[63:0] UARTLength     = 64'h1000;
    localparam logic[63:0] AESLength      = 64'h1000; 
    localparam logic[63:0] SHA256Length   = 64'h1000; 
    localparam logic[63:0] SPILength      = 64'h800000;
    localparam logic[63:0] EthernetLength = 64'h10000;
    localparam logic[63:0] GPIOLength     = 64'h1000;
    localparam logic[63:0] DRAMLength     = 64'h8000000; // 128 MByte of DDR
    localparam logic[63:0] SRAMLength     = 64'h1800000;  // 24 MByte of SRAM
    // Instantiate AXI protocol checkers
    localparam bit GenProtocolChecker = 1'b0;

    typedef enum logic [63:0] {
        DebugBase    = 64'h0000_0000,
        Debug2Base   = 64'h0000_2000,
        AES2Base     = 64'h0000_4000,
        TESTBase     = 64'h0000_6000,  
        MOPBase      = 64'h0000_8000,  
        MOP2Base      = 64'h0000_9000,  
        ROMBase      = 64'h0001_0000,
        REGLKBase    = 64'h0011_0000, 
        AcCtBase     = 64'h0021_0000, 
        PKTBase      = 64'h0041_0000, 
        DMAbase      = 64'h0051_0000, 
        CLINTBase    = 64'h0200_0000,
        PLICBase     = 64'h0C00_0000,
        UARTBase     = 64'h1000_0000,
        AESBase      = 64'h1010_0000,  
        SHA256Base   = 64'h1020_0000,  
        SPIBase      = 64'h2000_0000,
        EthernetBase = 64'h3000_0000,
        GPIOBase     = 64'h4000_0000,
        DRAMBase     = 64'h8000_0000
    } soc_bus_start_t;

    // Different AES Key ID's this information is public.
    localparam logic[63:0] AESKey0_0    = AESBase + 4*05;  // address for LSB 32 bits
    localparam logic[63:0] AESKey0_1    = AESBase + 4*06;
    localparam logic[63:0] AESKey0_2    = AESBase + 4*07;
    localparam logic[63:0] AESKey0_3    = AESBase + 4*08;
    localparam logic[63:0] AESKey0_4    = AESBase + 4*09;
    localparam logic[63:0] AESKey0_5    = AESBase + 4*10;
    localparam logic[63:0] AESKey1_0    = AESBase + 4*20;  // address for LSB 32 bits
    localparam logic[63:0] AESKey1_1    = AESBase + 4*21;
    localparam logic[63:0] AESKey1_2    = AESBase + 4*22;
    localparam logic[63:0] AESKey1_3    = AESBase + 4*23;
    localparam logic[63:0] AESKey1_4    = AESBase + 4*24;
    localparam logic[63:0] AESKey1_5    = AESBase + 4*25;
    localparam logic[63:0] AESKey2_0    = AESBase + 4*26;  // address for LSB 32 bits
    localparam logic[63:0] AESKey2_1    = AESBase + 4*27;
    localparam logic[63:0] AESKey2_2    = AESBase + 4*28;
    localparam logic[63:0] AESKey2_3    = AESBase + 4*29;
    localparam logic[63:0] AESKey2_4    = AESBase + 4*30;
    localparam logic[63:0] AESKey2_5    = AESBase + 4*31;
    localparam logic[63:0] SHAKey_0    = SHA256Base + 4*20 ;  // SHA has no key input, so, mapping to a invalid address as of now
    localparam logic[63:0] SHAKey_1    = SHA256Base + 4*20 ;  // SHA has no key input, so, mapping to a invalid address as of now
    localparam logic[63:0] SHAKey_2    = SHA256Base + 4*20 ;  // SHA has no key input, so, mapping to a invalid address as of now
    localparam logic[63:0] SHAKey_3    = SHA256Base + 4*20 ;  // SHA has no key input, so, mapping to a invalid address as of now
    localparam logic[63:0] SHAKey_4    = SHA256Base + 4*20 ;  // SHA has no key input, so, mapping to a invalid address as of now
    localparam logic[63:0] SHAKey_5    = SHA256Base + 4*20 ;  // SHA has no key input, so, mapping to a invalid address as of now
    localparam logic[63:0] AcCt_M_00   = AcCtBase + 4*0;
    localparam logic[63:0] AcCt_M_01   = AcCtBase + 4*1;
    localparam logic[63:0] AcCt_M_02   = AcCtBase + 4*2;
    localparam logic[63:0] AcCt_M_10   = AcCtBase + 4*3;
    localparam logic[63:0] AcCt_M_11   = AcCtBase + 4*4;
    localparam logic[63:0] AcCt_M_12   = AcCtBase + 4*5;
    localparam logic[63:0] AcCt_M_20   = AcCtBase + 4*6;
    localparam logic[63:0] AcCt_M_21   = AcCtBase + 4*7;
    localparam logic[63:0] AcCt_M_22   = AcCtBase + 4*8;
    localparam logic[63:0] JTAGKEY     = 64'hffffffff; // only a place holder, JTAG key is not mapped to AXI mem
endpackage
