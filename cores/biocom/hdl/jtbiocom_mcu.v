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
    Date: 14-9-2019 */


// Interface with sound CPU:
// The sound CPU can read and write to the MCU at a fixed
// address. The MCU only knows when data has been written to it
// The MCU responds by writting an answer. The MCU cannot
// know whether the sound CPU has read the value

// Interface with main CPU:
// The MCU takes control of the bus directly, including the bus decoder
// Because it doesn't drive AB[19:17], which will remain high, the MCU
// cannot access the PROM, OBJRAM, IO, scroll positions or char RAM
// It can drive both scrolls, palette and work RAM because it drives
// AB[16:14]. However, it doesn't have any bus arbitrion with the video
// components, so it wouldn't be able to access video components
// successfully. Thus, I am assuming that it only interacts with the
// work RAM

module jtbiocom_mcu(
    input                rst,
    input                clk_rom,
    input                clk,
    input                cen6a,       //  6   MHz
    // Main CPU interface
    (*keep*) input       DMAONn,
    output       [ 7:0]  mcu_dout,
    input        [ 7:0]  mcu_din,
    output               mcu_wr,   // always write to low bytes
    output       [16:1]  mcu_addr,
    (*keep*) output      mcu_brn,   // RQBSQn
    (*keep*) output      DMAn,
    // Sound CPU interface
    input        [ 7:0]  snd_dout,
    output reg   [ 7:0]  snd_din,
    input                snd_mcu_wr,
    input                snd_mcu_rd,
    // ROM programming
    input        [11:0]  prog_addr,
    input        [ 7:0]  prom_din,
    input                prom_we
);

(*keep*) wire [15:0] rom_addr;
wire [15:0] ext_addr;
wire [ 6:0] ram_addr;
wire [ 7:0] ram_data;
wire        ram_we;
wire [ 7:0] ram_q, rom_data;

wire [ 7:0] p1_o, p2_o, p3_o;
(*keep*) reg         int0, int1;

// interface with main CPU
assign mcu_addr[13:9] = ~5'b0;
assign { mcu_addr[16:14], mcu_addr[8:1] } = ext_addr[10:0];
assign mcu_brn  = int0;
assign DMAn     = p3_o[5];
reg    last_DMAONn;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        int0 <= 1'b1;
        last_DMAONn <= 1'b1;
    end else begin
        last_DMAONn <= DMAONn;
        if( !p3_o[0] ) // CLR
            int0 <= ~1'b0;
        else if(!p3_o[1]) // PR
            int0 <= ~1'b1;
        else if( DMAONn && !last_DMAONn )
            int0 <= ~1'b1;
    end
end

// interface with sound CPU
wire      int1_clrn = p3_o[4];

reg [7:0] snd_dout_latch;
reg       last_snd_mcu_wr, last_p3_6, last_snd_mcu_rd;
wire      posedge_snd    = snd_mcu_wr && !last_snd_mcu_wr;
wire      posedge_snd_rd = snd_mcu_rd && !last_snd_mcu_rd;
wire      posedge_p3_6 = p3_o[6] && !last_p3_6;
wire      snd_blank = p1_o == 8'hff;
reg       snd_done;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        snd_dout_latch   <= 8'd0;
        int1            <= 1'b1;
        last_snd_mcu_wr <= 1'b0;
        snd_done        <= 1'b1;
    end else begin
        last_snd_mcu_wr <= snd_mcu_wr;
        last_snd_mcu_rd <= snd_mcu_rd;
        last_p3_6       <= p3_o[6];
        if( posedge_snd )
            snd_dout_latch <= snd_dout;
        // interrupt line
        if( !int1_clrn )
            int1 <= 1'b1;
        else if( posedge_snd ) int1 <= 1'b0;
        // latch sound data
        if( posedge_snd_rd ) snd_done <= 1'b1;
        if( posedge_p3_6 && (snd_done || !snd_blank) ) begin
            snd_done <= snd_blank;
            snd_din  <= p1_o;
        end
    end
end

jtframe_8751mcu #(.ROMBIN("../../../../rom/biocom/ts.2f")) u_mcu(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen6a     ),
    // external memory: connected to main CPU
    .x_din      ( mcu_din   ),
    .x_dout     ( mcu_dout  ),
    .x_addr     ( ext_addr  ),
    .x_wr       ( mcu_wr    ),
    // interrupts
    .int0n      ( int0      ),
    .int1n      ( int1      ),
    // Ports
    .p0_i       (           ),
    .p0_o       (           ),

    .p1_i       ( snd_dout_latch   ),
    .p1_o       ( p1_o      ),

    .p2_i       (           ),
    .p2_o       ( p2_o      ),

    .p3_i       (           ),
    .p3_o       ( p3_o      ),

    .clk_rom    ( clk_rom   ),
    .prog_addr  ( prog_addr ),
    .prom_din   ( prom_din  ),
    .prom_we    ( prom_we   )
);

`ifdef SIMULATION
always @(negedge int0)
    $display ("MCU: int0 edge - main CPU");

always @(negedge int1)
    $display ("MCU: int1 edge - sound CPU");
`endif
endmodule