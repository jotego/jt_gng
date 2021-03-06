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
    Date: 27-10-2017 */

// 2-word tile memory

//////////////////////////////////////////////////////////////////
// Original board behaviour
// Commando / G&G / 1942 / 1943
// Scroll: when CPU tries to access hold the CPU until H==4, then
//         release the CPU and keep it in control of the bus until
//         the CPU releases the CS signal


module jtgng_tilemap #(parameter
    DW          = 8,
    INVERT_SCAN = 0,
    DATAREAD    = 3'd2,
    LAYOUT      = 0, // 0: all games, 8: Side Arms
    SCANW       = 10,
    BUSY_ON_H0  = 0,    // if 1, the busy signal is asserted only at H0 posedge, otherwise it uses the regular clock
    SIMID       = "",
    VW          = 8,
    HW          = (LAYOUT==8 || LAYOUT==9 || LAYOUT==10) ? 9 : 8
) (
    input                  clk,
    input                  pxl_cen,
    input                  Asel,  // This is the address bit that selects
                            // between the low and high tile map
    input            [1:0] dseln,
    input                  layout,  // use by Black Tiger to change scan
    input      [SCANW-1:0] AB,
    input         [VW-1:0] V,
    input         [HW-1:0] H,
    input                  flip,
    input         [DW-1:0] din,
    output    reg [DW-1:0] dout,
    // Bus arbitrion
    input                  cs,
    input                  wr_n,
    output       reg       busy,
    // Pause screen
    input                  pause,
    output reg [SCANW-1:0] scan,
    input            [7:0] msg_low,
    input            [7:0] msg_high,
    // Current tile
    output           [7:0] dout_low,
    output           [7:0] dout_high
);

wire [7:0] scan_low, scan_high;
reg        scan_sel = 1'b1;

assign dout_low  = pause ? msg_low  : scan_low;
assign dout_high = pause ? msg_high : scan_high;

always @(*) begin
    if( SCANW <= 10) begin
        scan = (INVERT_SCAN ? { {SCANW{flip}}^{H[7:3],V[7:3]}}
            : { {SCANW{flip}}^{V[7:3],H[7:3]}}) >> (10-SCANW);
    end else begin
        if( SCANW==13 ) begin // Black Tiger
            // 1 -> tile map 8x4
            // 0 -> tile map 4x8
            scan =  layout ?
                { V[8:7], H[9:7], V[6:3], H[6:3] } :
                { V[9:7], H[8:7], V[6:3], H[6:3] };
        end else if( LAYOUT==8 || LAYOUT==9 ) begin // Side Arms/Street Fighter
            scan = { V[7:3], H[8:3] }; // SCANW assumed to be 11
        end else if( LAYOUT==10 ) begin // The Speed Rumbler (SCANW=11 or 12)
            scan = {SCANW{flip}}^{ H[8:3], V[7:(SCANW==12?2:3)] };
        end else // other games
            scan = { V[7:2], H[7:2] }; // SCANW assumed to be 12
    end
end

reg [SCANW-1:0] addr;
reg we_low, we_high;
wire [7:0] mem_low, mem_high;

reg last_H0;
wire posedge_H0 = BUSY_ON_H0 ? (!last_H0 && H[0] && pxl_cen) : 1'b1;

// Although a dual port memory is used for easy synthesis
// the bus wait state is complied by means of the 'busy' signal
always @(posedge clk) begin : busy_latch
    last_H0 <= H[0];
    if( cs && scan_sel && posedge_H0 )
        busy <= 1'b1;
    else busy <= 1'b0;
end

always @(posedge clk) if(pxl_cen) begin : scan_select
    if( !cs )
        scan_sel <= 1'b1;
    else if(H[2:0]==DATAREAD)
        scan_sel <= 1'b0;
end

reg [7:0] udlatch, ldlatch;
reg last_scan, last_Asel;

always @(posedge clk) begin
    addr <= AB;
    if( DW == 16 ) begin
        we_low    <= cs && !wr_n && !dseln[0];
        we_high   <= cs && !wr_n && !dseln[1];
        udlatch   <= din[15:8];
        ldlatch   <= din[7:0];
    end else begin
        we_low    <= cs && !wr_n && !Asel;
        we_high   <= cs && !wr_n &&  Asel;
        udlatch   <= din;
        ldlatch   <= din;
    end
    last_Asel <= Asel;

    // Output latch
    last_scan <= scan_sel;
    if( !last_scan )
        if(DW==8)
            dout <= last_Asel ? mem_high : mem_low;
        else
            dout <= { mem_high, mem_low };
end

// Use these macros to add simulation files
// like
// ',.simhexfile("sim.hex")' or
// ',.simfile("sim.bin")'
// when calling the simulation script:
// go.sh \
//    -d JTCHAR_LOWER_SIMFILE=',.simfile("scr0.bin")' \
//    -d JTCHAR_UPPER_SIMFILE=',.simfile("scr1.bin")'


`ifndef JTCHAR_UPPER_SIMFILE
`define JTCHAR_UPPER_SIMFILE
`endif

`ifndef JTCHAR_LOWER_SIMFILE
`define JTCHAR_LOWER_SIMFILE
`endif

jtframe_dual_ram #(.aw(SCANW) `JTCHAR_LOWER_SIMFILE) u_ram_low(
    .clk0   ( clk      ),
    .clk1   ( clk      ),
    // CPU
    .data0  ( ldlatch  ),
    .addr0  ( addr     ),
    .we0    ( we_low   ),
    .q0     ( mem_low  ),
    // GFX
    .data1  ( 8'd0     ),
    .addr1  ( scan     ),
    .we1    ( 1'b0     ),
    .q1     ( scan_low )
);

// attributes
// the default value for synthesis will display a ROM load message using
// the palette attributes
jtframe_dual_ram #(.aw(SCANW) `JTCHAR_UPPER_SIMFILE) u_ram_high(
    .clk0   ( clk      ),
    .clk1   ( clk      ),
    // CPU
    .data0  ( udlatch  ),
    .addr0  ( addr     ),
    .we0    ( we_high  ),
    .q0     ( mem_high ),
    // GFX
    .data1  ( 8'd0     ),
    .addr1  ( scan     ),
    .we1    ( 1'b0     ),
    .q1     ( scan_high)
);

endmodule
