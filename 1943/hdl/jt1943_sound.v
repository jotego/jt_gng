/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 19-2-2019 */

// 1943 Sound
// Schematics page 3/9

module jt1943_sound(
    input           clk,    // 24   MHz
    input           cen3   /* synthesis direct_enable = 1 */,   //  3   MHz
    input           cen1p5, //  1.5 MHz
    input           rst,
    // Interface with main CPU
    input           sres_b,
    input   [ 7:0]  main_dout,
    input           main_latch_cs,
    input           snd_int,
    // Sound control
    input           enable_psg,
    input           enable_fm,
    // ROM access
    output  [14:0]  rom_addr,
    input   [ 7:0]  rom_data,
    // Sound output
    output reg [15:0]  snd
);

// posedge of snd_int
reg snd_int_last;
wire snd_int_edge = !snd_int_last && snd_int;
always @(posedge clk) if(cen3) begin
    snd_int_last <= snd_int;
end

// interrupt latch
reg int_n;
wire iorq_n;
always @(posedge clk) 
    if( rst ) int_n <= 1'b1;
    else if(cen3) begin
        if(!iorq_n) int_n <= 1'b1;
        else if( snd_int_edge ) int_n <= 1'b0;
    end

wire [15:0] A;
assign rom_addr = A[14:0];

reg reset_n=1'b0;

always @(posedge clk) if(cen3)
    reset_n <= ~( rst | ~sres_b );

reg rom_cs, fm1_cs, fm0_cs, latch_cs, ram_cs, SECWR_cs;

reg [7:0] latch;

always @(*) begin
    rom_cs   = 1'b0;
    ram_cs   = 1'b0;
    latch_cs = 1'b0;
    fm0_cs   = 1'b0;
    fm1_cs   = 1'b0;
    SECWR_cs = 1'b0;
    casez(A[15:13])
        3'b0??: rom_cs   = 1'b1;
        3'b110:
            case( A[12:11] )
                2'd0: ram_cs   = 1'b1;
                2'd1: latch_cs = 1'b1;
                2'd3: SECWR_cs = 1'b1;
            endcase
        3'b111: begin
            fm0_cs = ~A[1];
            fm1_cs =  A[1];
        end
        default:;
    endcase
end

reg [1:0] cs_wait;
always @(posedge clk)
    if( rst )
        cs_wait <= 2'b11;
    else if(cen3) begin
        cs_wait <= { cs_wait[0], ~(fm0_cs|fm1_cs) };
    end // else if(cen3)

wire wait_n = ~cs_wait[1] | cs_wait[0];

reg [7:0] latch0, latch1;

always @(posedge clk) 
if( rst ) begin
    latch <= 8'd0;
end else if(cen3) begin
    if( main_latch_cs ) latch <= main_dout;
end

wire rd_n;
wire wr_n;

wire RAM_we = ram_cs && !wr_n;
wire [7:0] ram_dout, dout;

jtgng_ram #(.aw(11)) u_ram(
    .clk    ( clk      ),
    .cen    ( 1'b1     ),
    .data   ( dout     ),
    .addr   ( A[10:0]  ),
    .we     ( RAM_we   ),
    .q      ( ram_dout )
);

reg [7:0] din, security;
wire [7:0] fm1_dout, fm0_dout;

always @(*)
    case( 1'b1 )
        fm1_cs:   din = fm1_dout;
        fm0_cs:   din = fm0_dout;
        latch_cs: din = latch;
        rom_cs:   din = rom_data;
        ram_cs:   din = ram_dout;
        default:  din = 8'hff;
    endcase // {latch_cs,rom_cs,ram_cs}

jt1943_security u_security(
    .clk    ( clk      ),
    .cen    ( cen3     ),
    .wr_n   ( wr_n     ),
    .cs     ( SECWR_cs ),
    .din    ( dout     ),
    .dout   ( security )
);

// Select the Z80 core to use
`ifdef SIMULATION
`define Z80_ALT_CPU
`endif

// `ifdef NCVERILOG
// `undef Z80_ALT_CPU
// `endif

`ifdef VERILATOR_LINT 
`define Z80_ALT_CPU
`endif

`ifndef Z80_ALT_CPU
// This CPU is used for synthesis
T80s u_cpu(
    .RESET_n    ( reset_n     ),
    .CLK        ( clk         ),
    .CEN        ( cen3        ),
    .WAIT_n     ( wait_n      ),
    .INT_n      ( int_n       ),
    .RD_n       ( rd_n        ),
    .WR_n       ( wr_n        ),
    .A          ( A           ),
    .DI         ( din         ),
    .DO         ( dout        ),
    .IORQ_n     ( iorq_n      ),
    .NMI_n      ( 1'b1        ),
    .BUSRQ_n    ( 1'b1        ),
    .out0       ( 1'b0        )
);
`else
tv80s #(.Mode(0)) u_cpu (
    .reset_n(reset_n ),
    .clk    (clk     ), // 3 MHz, clock gated
    .cen    (cen3    ),
    .wait_n (wait_n  ),
    .int_n  (int_n   ),
    .nmi_n  (1'b1    ),
    .busrq_n(1'b1    ),
    .rd_n   (rd_n    ),
    .wr_n   (wr_n    ),
    .A      (A       ),
    .di     (din     ),
    .dout   (dout    ),
    .iorq_n ( iorq_n ),
    // unused
    .mreq_n (),
    .m1_n   (),
    .busak_n(),
    .halt_n (),
    .rfsh_n ()
);
`endif

wire signed [15:0] fm0_snd,  fm1_snd;
wire        [ 9:0] psg0_snd, psg1_snd;
wire        [10:0] psg01 = psg0_snd + psg1_snd;
// wire signed [15:0] 
//     psg0_signed = {1'b0, psg0_snd, 4'b0 },
//     psg1_signed = {1'b0, psg1_snd, 4'b0 };

wire signed [10:0] psg2x; // DC-removed version of psg01

jt49_dcrm2 #(.sw(11)) u_dcrm (
    .clk    (  clk    ),
    .cen    (  cen1p5 ),
    .rst    (  rst    ),
    .din    (  psg01  ),
    .dout   (  psg2x  )
);

wire signed [7:0] psg_gain = enable_psg ? 8'hd0 : 8'h0;
wire signed [7:0]  fm_gain = enable_fm  ? 8'h06 : 8'h0;

jt12_mixer #(.w0(16),.w1(16),.w2(13),.w3(8),.wout(16)) u_mixer(
    .clk    ( clk          ),
    .cen    ( cen1p5       ),
    .ch0    ( fm0_snd      ),
    .ch1    ( fm1_snd      ),
    .ch2    ( {psg2x, 2'b0}),
    .ch3    ( 8'd0         ),
    .gain0  ( fm_gain      ), // unity gain for FM
    .gain1  ( fm_gain      ),
    .gain2  ( psg_gain     ), // larger gain for PSG
    .gain3  ( 8'd0         ),
    .mixed  ( snd          )
);

jt03 u_fm0(
    .rst    ( ~reset_n  ),
    // CPU interface
    .clk    ( clk        ),
    .cen    ( cen1p5     ),
    .din    ( dout       ),
    .addr   ( A[0]       ),
    .cs_n   ( ~fm0_cs    ),
    .wr_n   ( wr_n       ),
    .psg_snd( psg0_snd   ),
    .fm_snd ( fm0_snd    ),
    .snd_sample ( sample ),
    // unused outputs
    .dout   (),
    .irq_n  (),
    .psg_A  (),
    .psg_B  (),
    .psg_C  (),
    .snd    ()
);

jt03 u_fm1(
    .rst    ( ~reset_n  ),
    // CPU interface
    .clk    ( clk       ),
    .cen    ( cen1p5    ),
    .din    ( dout      ),
    .addr   ( A[0]      ),
    .cs_n   ( ~fm1_cs   ),
    .wr_n   ( wr_n      ),
    .psg_snd( psg1_snd  ),
    .fm_snd ( fm1_snd   ),
    // unused outputs
    .dout   (),
    .irq_n  (),
    .psg_A  (),
    .psg_B  (),
    .psg_C  (),
    .snd    (),
    .snd_sample()
);

endmodule // jtgng_sound