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
    Date: 11-1-2019 */

module jtgng_objdraw #(parameter
    DW               = 8,   // data width of the DMA
    ROM_AW           = 16,
    LAYOUT           = 0,   // 0: GnG, Commando
                            // 1: 1943
                            // 2: GunSmoke
                            // 3: Bionic Commando, Tiger Road
                            // 4: Black Tiger
                            // 5: Section Z/Legendary Wings
                            // 6: Trojan
                            // 8: Side Arms
                            // 9: Street Fighter
    PALW             = 2,   // Define it in the video module
    PALETTE          = 0,   // 1 if the palette PROM is used
    PALETTE1_SIMFILE = "", // only for simulation
    PALETTE0_SIMFILE = "", // only for simulation

    parameter [8:0] XOUT = 9'h1F0 // non visible location in double-line buffer
) (
    (* direct_enable *) input cen,
    input              rst,
    input              clk,
    // screen
    input       [7:0]  VF,
    input       [3:0]  pxlcnt,
    output reg  [8:0]  posx,
    input              flip,
    input              pause,
    // per-line sprite data
    input       [4:0]  objcnt,
    input    [DW-1:0]  objbuf_data,
    // SDRAM interface
    output  reg [ROM_AW-1:0] obj_addr,
    input       [15:0] obj_data,
    input              rom_wait,
    input              draw_over,
    // Palette PROM
    input              OBJON,
    input       [7:0]  prog_addr,
    input              prom_hi_we,
    input              prom_lo_we,
    input       [3:0]  prog_din,
    // pixel data
    output reg  [PALW-1:0]       pospal,
    output reg  [(PALETTE?7:3):0]  new_pxl  // 8 bits if PROMs used, 4 bits otherwise
);

// Width of ID code
localparam IDW = LAYOUT==3 ? 12 : (ROM_AW-6);
// Width of ID code directly read from the buffer at step 0
localparam IDWDIRECT = IDW<DW ? IDW : DW;

reg  [ IDW-1:0] id;
reg  [PALW-1:0] objpal, objpal1;
reg  [     8:0] objx;
reg             obj_vflip, obj_hflip, hover;
wire            posvflip;
reg             poshflip;
reg             vinzone;
reg             resize;
reg             poshflip2;
reg  [     7:0] Vsum;


always @(*) begin
    Vsum = (~VF + { {7{~flip}}, 1'b1})+objbuf_data[7:0]; // this is equivalent to
    // 2's complement of VF plus object's Y, i.e. a subtraction
    // but flip is used to make it work with flipped screens
    // This is the same formula used on the schematics
end

reg [3:0] Vobj;

always @(posedge clk) if(cen) begin
if( rst ) begin
    id <= {IDW{1'b0}};
end else begin
    if(!rom_wait) case( pxlcnt[3:0] )
        4'd0: id[IDWDIRECT-1:0] <= objbuf_data[ IDWDIRECT-1: 0 ];
        4'd1: case( LAYOUT )
            default: begin // GnG, Commando
                id[9:8]     <= objbuf_data[7:6];
                objpal[1:0] <= objbuf_data[5:4];
                obj_vflip   <= objbuf_data[3];
                obj_hflip   <= objbuf_data[2];
                hover       <= objbuf_data[0];
            end
            1: begin // 1943
                id[10:8]  <= pause ? 3'd0 : objbuf_data[7:5];
                objpal    <= objbuf_data[3:0];
                obj_vflip <= 1'b0;
                obj_hflip <= 1'b0;
                hover     <= objbuf_data[4];
            end
            2: begin // GunSmoke
                id[9:8]   <= objbuf_data[7:6];
                objpal    <= objbuf_data[3:0];
                obj_vflip <= objbuf_data[4];
                obj_hflip <= 1'b0;
                hover     <= objbuf_data[5];
            end
            3: begin // Bionic Commando, Tiger Road
                obj_vflip <= objbuf_data[0];
                obj_hflip <= objbuf_data[1];
                objpal    <= objbuf_data[5:2];
            end
            4: begin // Black Tiger
                id[10:8]  <= objbuf_data[7:5];
                hover     <= objbuf_data[4];
                obj_hflip <= objbuf_data[3];
                obj_vflip <= 1'b0;
                objpal    <= objbuf_data[2:0];
            end
            5: begin // Section Z / Legendary Wings
                id[9:8]   <= objbuf_data[7:6];
                hover     <= objbuf_data[0];
                obj_hflip <= objbuf_data[1];
                obj_vflip <= objbuf_data[2];
                objpal    <= objbuf_data[5:3];
            end
            6: begin // Trojan
                id[10:8]  <= { objbuf_data[7], objbuf_data[5], objbuf_data[6] };
                hover     <= objbuf_data[0];
                obj_hflip <= objbuf_data[4];
                obj_vflip <= 1;
                objpal    <= objbuf_data[3:1];
            end
            8: begin // Side Arms
                id[10:8]  <= objbuf_data[7:5];
                hover     <= objbuf_data[4];
                obj_hflip <= 0;
                obj_vflip <= 0;
                objpal    <= objbuf_data[3:0];
            end
            9: begin // Street Fighter
                if(id[4]!=id[3]) begin
                    id[4:3] <= ~id[4:3]; // This might be needed just
                    // because of the ROM load order
                end
                obj_vflip <= objbuf_data[9];
                obj_hflip <= objbuf_data[8];
                objpal    <= objbuf_data[3:0];
                resize    <= objbuf_data[10];
            end
        endcase
        4'd2: begin // Object Y is on objbuf_data at this step
            if( LAYOUT == 9 ) begin // SF
                Vobj    <= Vsum[3:0];
                vinzone <= resize ? &Vsum[7:5] : &Vsum[7:4];
                if( resize )
                    id[4] <= ~Vsum[4];
            end else begin
                Vobj    <=  Vsum[3:0];
                vinzone <= &Vsum[7:4];
            end
        end
        4'd3: begin
            // DW-4 refers to bit 12 but it needs this indirect index
            // so verilator does not complaint about the 12 when DW is only 8
            objx <= vinzone ?
                { (LAYOUT==3 || LAYOUT==9) ? objbuf_data[8] : hover, objbuf_data[7:0] } // LAYOUT==3 implies DW=16
                : XOUT;
        end
        default:;
    endcase
end
end

always @(posedge clk) if(cen) begin
    if( rst ) begin
        obj_addr <= {ROM_AW{1'b0}};
    end else begin
        if( pxlcnt[1:0]==2'd3 && !rom_wait ) begin
            obj_addr <= !vinzone ? {ROM_AW{1'b0}} :
                { id, Vobj^{4{~obj_vflip}}, pxlcnt[3:2]^{2{obj_hflip}} };
        end
    end
end

reg [ 3:0] z,y,x,w;
reg [8:0] posx1;

// ROM data depacking
always @(posedge clk) if(cen) begin
    // only advance if we are not waiting for data
    if( draw_over ) begin
        posx1 <= XOUT;
        {z,y,x,w} <= 16'hFFFF;
    end else begin
        if( !rom_wait ) begin
            if( pxlcnt[3:0]==4'h7 ) begin
                objpal1   <= objpal;
                poshflip2 <= obj_hflip;
                posx1     <= objx;
            end else begin
                posx1     <= posx1 + 9'b1;
            end
            case( pxlcnt[1:0] )
                2'd3:  begin // new data
                        {z,y,x,w} <= obj_data;
                    end
                default:
                    if( poshflip2 ) begin
                        z <= z >> 1;
                        y <= y >> 1;
                        x <= x >> 1;
                        w <= w >> 1;
                    end else begin
                        z <= z << 1;
                        y <= y << 1;
                        x <= x << 1;
                        w <= w << 1;
                    end
            endcase
        end
    end
end

generate
    if( PALETTE == 1 ) begin
        wire [7:0] prom_dout;
        // 1943 has bits reversed for palette PROMs
        wire [3:0] new_col = { w[3],x[3],y[3],z[3] };
        wire [7:0] pal_addr = { objpal1, new_col };

        jtframe_prom #(.aw(8),.dw(4), .simfile(PALETTE1_SIMFILE) ) u_prom_msb(
            .clk    ( clk            ),
            .cen    ( cen            ),
            .data   ( prog_din       ),
            .rd_addr( pal_addr       ),
            .wr_addr( prog_addr      ),
            .we     ( prom_hi_we     ),
            .q      ( prom_dout[7:4] )
        );

        jtframe_prom #(.aw(8),.dw(4), .simfile(PALETTE0_SIMFILE) ) u_prom_lsb(
            .clk    ( clk            ),
            .cen    ( cen            ),
            .data   ( prog_din       ),
            .rd_addr( pal_addr       ),
            .wr_addr( prog_addr      ),
            .we     ( prom_lo_we     ),
            .q      ( prom_dout[3:0] )
        );

        reg  [8:0] posx2;

        `ifdef AVATARS
        `ifdef MISTER
        `define AVATAR_OBJDRAW
        `endif
        `endif

        `ifdef AVATAR_OBJDRAW
            reg  [7:0] avatar_pxl;
            always @(posedge clk) if(cen)
                avatar_pxl <= { 4'd0, new_col };
        `else
            wire [7:0] avatar_pxl = prom_dout;
        `endif

        always @(posedge clk ) if(cen && !rom_wait) begin
            pospal <= {PALW{1'b0}}; // it is actually unused on the upper level
            posx2 <= posx1; // 1-clk delay to match the PROM data
            if( OBJON ) begin
                new_pxl <= pause ? avatar_pxl : prom_dout;
                posx    <= posx2;
            end else begin
                new_pxl <= 8'hf;
                posx    <= XOUT;
            end
        end

    end else begin
        // No palette PROMs
        always @(posedge clk) if(cen && !rom_wait) begin
            new_pxl <= poshflip2 ? {w[0],x[0],y[0],z[0]} : {w[3],x[3],y[3],z[3]};
            posx    <= posx1;
            pospal  <= objpal1;
        end
    end
endgenerate

endmodule // jtgng_objdraw