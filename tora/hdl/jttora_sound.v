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

module jttora_sound(
    input           rst,
    input           clk,
    input           cen3,    //  3   MHz
    input           cenfm,   //  3.57   MHz
    input           cenp384, //  384 kHz
    input           jap,
    // Interface with main CPU
    input   [7:0]   snd_latch,
    // Sound control
    input           enable_psg,
    input           enable_fm,
    input   [7:0]   psg_gain,
    // ROM
    output  [14:0]  rom_addr,
    output          rom_cs,
    input   [ 7:0]  rom_data,
    input           rom_ok,
    // ADPCM ROM
    output  [14:0]  rom2_addr,
    output          rom2_cs,
    input   [ 7:0]  rom2_data,
    input           rom2_ok,    

    // Sound output
    output  reg signed [15:0] ym_snd,
    output  sample
);

wire signed [15:0] fm_snd, adpcm_snd;
wire               cen_cpu3  = jap & cen3;
wire               cen_adpcm = jap & cenp384;
wire        [ 7:0] snd2_latch;

always @(posedge clk) begin
    ym_snd <= jap ? fm_snd + adpcm_snd : fm_snd;
end

jtgng_sound #(.LAYOUT(3)) u_fmcpu (
    .rst        (  rst          ),
    .clk        (  clk          ),
    .cen3       (  cenfm        ),
    .cen1p5     (  1'b0         ), // unused
    .sres_b     (  1'b1         ),
    .snd_latch  (  snd_latch    ),
    .snd2_latch (  snd2_latch   ),
    .snd_int    (  1'b1         ), // unused
    .enable_psg (  enable_psg   ),
    .enable_fm  (  enable_fm    ),
    .psg_gain   (  psg_gain     ),
    .rom_addr   (  rom_addr     ),
    .rom_cs     (  rom_cs       ),
    .rom_data   (  rom_data     ),
    .rom_ok     (  rom_ok       ),
    .ym_snd     (  fm_snd       ),
    .sample     (  sample       )
);

jttora_adpcm u_adpcmcpu(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen3       ( cen3          ),
    .cenp384    ( cenp384       ),
    .jap        ( jap           ),
    // Interface with second CPU
    .snd2_latch ( snd2_latch    ),
    // ADPCM ROM
    .rom2_addr  ( rom2_addr     ),
    .rom2_cs    ( rom2_cs       ),
    .rom2_data  ( rom2_data     ),
    .rom2_ok    ( rom2_ok       ),    
    // Sound output
    .snd        ( adpcm_snd     )
);

endmodule // jtgng_sound