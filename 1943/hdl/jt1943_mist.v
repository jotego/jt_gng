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
    Date: 22-2-2019 */

module jt1943_mist(
    input   [1:0]   CLOCK_27,
    output  [5:0]   VGA_R,
    output  [5:0]   VGA_G,
    output  [5:0]   VGA_B,
    output          VGA_HS,
    output          VGA_VS,
    // SDRAM interface
    inout  [15:0]   SDRAM_DQ,       // SDRAM Data bus 16 Bits
    output [12:0]   SDRAM_A,        // SDRAM Address bus 13 Bits
    output          SDRAM_DQML,     // SDRAM Low-byte Data Mask
    output          SDRAM_DQMH,     // SDRAM High-byte Data Mask
    output          SDRAM_nWE,      // SDRAM Write Enable
    output          SDRAM_nCAS,     // SDRAM Column Address Strobe
    output          SDRAM_nRAS,     // SDRAM Row Address Strobe
    output          SDRAM_nCS,      // SDRAM Chip Select
    output [1:0]    SDRAM_BA,       // SDRAM Bank Address
    output          SDRAM_CLK,      // SDRAM Clock
    output          SDRAM_CKE,      // SDRAM Clock Enable   
   // SPI interface to arm io controller
    output          SPI_DO,
    input           SPI_DI,
    input           SPI_SCK,
    input           SPI_SS2,
    input           SPI_SS3,
    input           SPI_SS4,
    input           CONF_DATA0,
    // sound
    output          AUDIO_L,
    output          AUDIO_R,
    // user LED
    output          LED
);


localparam CONF_STR = {
    //   00000000011111111112222222222333333333344444444445
    //   12345678901234567890123456789012345678901234567890
        "JT1943;;", //8
        "O1,Pause,OFF,ON;", // 16
        "O23,Difficulty,Normal,Easy,Hard,Very hard;", // 42
        "O4,Test mode,OFF,ON;", // 20
        "O7,PSG,ON,OFF;", // 14
        "O8,FM ,ON,OFF;", // 14
        "O9,Screen filter,ON,OFF;", // 24
        "OA,Invincibility,OFF,ON;", // 24
        "OB,Flip screen,OFF,ON;", // 22
        "TF,RST ,OFF,ON;", // 15
        "V,patreon.com/topapate;" // 23
};

localparam CONF_STR_LEN = 8+16+42+20+15+14*2+24+24+22+23;

wire          rst, clk_rgb, clk_vga, clk_rom;
wire          cen12, cen6, cen3, cen1p5;
wire [31:0]   status, joystick1, joystick2;
wire          ps2_kbd_clk, ps2_kbd_data;
wire [ 5:0]   board_r, board_g, board_b;
wire          board_hsync, board_vsync, hs, vs;
wire [21:0]   sdram_addr;
wire [15:0]   data_read;
wire          loop_rst, autorefresh, sdram_re; 
wire          downloading;
wire [21:0]   ioctl_addr;
wire [ 7:0]   ioctl_data;
wire          ioctl_wr;
wire          coin_cnt;

assign LED = ~downloading | coin_cnt | rst;
wire rst_req = status[32'hf];
wire cheat_invincible = status[32'd10];
wire dip_flip = status[32'hb];

wire enable_fm = ~status[8], enable_psg = ~status[7];

wire dip_test  = ~status[4];
wire dip_pause = ~status[1];
wire dip_upright = 1'b1;
wire dip_credits2p = 1'b1;
reg [3:0] dip_level;
wire dip_demosnd = 1'b1;
wire dip_continue = 1'b0;
wire [2:0] dip_price2 = 3'b100;
wire [2:0] dip_price1 = ~3'b0;

wire [21:0]   prog_addr;
wire [ 7:0]   prog_data;
wire [ 1:0]   prog_mask;
wire          prog_we;

wire [3:0] red;
wire [3:0] green;
wire [3:0] blue;

// play level
always @(*)
    case( status[3:2] )
        2'b00: dip_level = 4'b0111; // normal
        2'b01: dip_level = 4'b1111; // easy
        2'b10: dip_level = 4'b0011; // hard
        2'b11: dip_level = 4'b0000; // very hard
    endcase // status[3:2]


jtgng_mist_base #(.CONF_STR(CONF_STR), .CONF_STR_LEN(CONF_STR_LEN)) u_base(
    .rst            ( rst           ),
    .clk_rgb        ( clk_rgb       ),
    .clk_vga        ( clk_vga       ),
    .clk_rom        ( clk_rom       ),
    .SDRAM_CLK      ( SDRAM_CLK     ),
    .cen12          ( cen12         ),
    .sdram_re       ( sdram_re      ),
    // Base video
    .game_r         ( red           ),
    .game_g         ( green         ),
    .game_b         ( blue          ),    
    .board_r        ( board_r       ),
    .board_g        ( board_g       ),
    .board_b        ( board_b       ),
    .board_hsync    ( board_hsync   ),
    .board_vsync    ( board_vsync   ),
    .hs             ( hs            ),
    .vs             ( vs            ),
    // VGA
    .CLOCK_27       ( CLOCK_27      ),
    .VGA_R          ( VGA_R         ),
    .VGA_G          ( VGA_G         ),
    .VGA_B          ( VGA_B         ),
    .VGA_HS         ( VGA_HS        ),
    .VGA_VS         ( VGA_VS        ),
    // SDRAM interface
    .SDRAM_DQ       ( SDRAM_DQ      ),
    .SDRAM_A        ( SDRAM_A       ),
    .SDRAM_DQML     ( SDRAM_DQML    ),
    .SDRAM_DQMH     ( SDRAM_DQMH    ),
    .SDRAM_nWE      ( SDRAM_nWE     ),
    .SDRAM_nCAS     ( SDRAM_nCAS    ),
    .SDRAM_nRAS     ( SDRAM_nRAS    ),
    .SDRAM_nCS      ( SDRAM_nCS     ),
    .SDRAM_BA       ( SDRAM_BA      ),
    .SDRAM_CKE      ( SDRAM_CKE     ),
    // SPI interface to arm io controller
    .SPI_DO         ( SPI_DO        ),
    .SPI_DI         ( SPI_DI        ),
    .SPI_SCK        ( SPI_SCK       ),
    .SPI_SS2        ( SPI_SS2       ),
    .SPI_SS3        ( SPI_SS3       ),
    .SPI_SS4        ( SPI_SS4       ),
    .CONF_DATA0     ( CONF_DATA0    ),
    // control
    .status         ( status        ), 
    .joystick1      ( joystick1     ), 
    .joystick2      ( joystick2     ),
    .ps2_kbd_clk    ( ps2_kbd_clk   ),
    .ps2_kbd_data   ( ps2_kbd_data  ),
    // ROM
    .ioctl_addr     ( ioctl_addr    ),
    .ioctl_data     ( ioctl_data    ),
    .ioctl_wr       ( ioctl_wr      ),
    .prog_addr      ( prog_addr     ),
    .prog_data      ( prog_data     ),
    .prog_mask      ( prog_mask     ),
    .prog_we        ( prog_we       ),
    .downloading    ( downloading   ),
    .loop_rst       ( loop_rst      ),
    .autorefresh    ( autorefresh   ),
    .sdram_addr     ( sdram_addr    ),
    .data_read      ( data_read     )
);


jtgng_cen #(.CLK_SPEED(12)) u_cen(
    .clk    ( clk_rgb   ),
    .cen12  ( cen12     ),
    .cen6   ( cen6      ),
    .cen3   ( cen3      ),
    .cen1p5 ( cen1p5    )
);

    wire LHBL;
    wire LVBL;
    wire [8:0] snd;

wire [6:0] game_joystick1, game_joystick2;
wire [1:0] game_coin, game_start;
wire game_pause;

reg game_rst;
always @(negedge clk_rgb)
    game_rst <= downloading | rst | rst_req;

jt1943_game u_game(
    .rst         ( game_rst      ),
    .clk_rom     ( clk_rom       ),
    .clk         ( clk_rgb       ),
    .cen12       ( cen12         ),
    .cen6        ( cen6          ),
    .cen3        ( cen3          ),
    .cen1p5      ( cen1p5        ),
    .red         ( red           ),
    .green       ( green         ),
    .blue        ( blue          ),
    .LHBL        ( LHBL          ),
    .LVBL        ( LVBL          ),
    .HS          ( hs            ),
    .VS          ( vs            ),

    .start_button( game_start     ),
    .coin_input  ( game_coin      ),
    .joystick1   ( game_joystick1 ),
    .joystick2   ( game_joystick2 ),

    // Sound control
    .enable_fm   ( enable_fm      ),
    .enable_psg  ( enable_psg     ),
    // PROM programming
    .ioctl_addr  ( ioctl_addr     ),
    .ioctl_data  ( ioctl_data     ),
    .ioctl_wr    ( ioctl_wr       ),
    .prog_addr   ( prog_addr      ),
    .prog_data   ( prog_data      ),
    .prog_mask   ( prog_mask      ),
    .prog_we     ( prog_we        ),

    // ROM load
    .downloading ( downloading   ),
    .loop_rst    ( loop_rst      ),
    .sdram_re    ( sdram_re      ),
    .sdram_addr  ( sdram_addr    ),
    .data_read   ( data_read     ),
    // Cheat
    .cheat_invincible( cheat_invincible ),
    // DIP switches
    .dip_test    ( dip_test       ),
    .dip_pause   ( dip_pause      ),
    .dip_upright ( dip_upright    ),
    .dip_credits2p( dip_credits2p ),
    .dip_level   ( dip_level      ),
    .dip_demosnd ( dip_demosnd    ),
    .dip_continue( dip_continue   ),
    .dip_price2  ( dip_price2     ),
    .dip_price1  ( dip_price1     ),    
    .dip_flip    ( dip_flip       ),

    .coin_cnt    ( coin_cnt       ),
    // sound
    .snd         ( snd            ),
    .sample      (                )
);

assign AUDIO_R = AUDIO_L;

jtgng_board u_board(
    .rst            ( rst             ),
    .clk_rgb        ( clk_rgb         ),
    .clk_dac        ( clk_rom         ),
    // audio
    .snd            ( { snd, 7'd0 }   ),
    .snd_pwm        ( AUDIO_L         ),
    // VGA
    .cen6           ( cen6            ),
    .clk_vga        ( clk_vga         ),
    .en_mixing      ( ~status[9]      ),    
    .game_r         ( red             ),
    .game_g         ( green           ),
    .game_b         ( blue            ),
    .LHBL           ( LHBL            ),
    .LVBL           ( LVBL            ),
    .vga_r          ( board_r         ),
    .vga_g          ( board_g         ),
    .vga_b          ( board_b         ),    
    .vga_hsync      ( board_hsync     ),
    .vga_vsync      ( board_vsync     ),
    // joystick
    .ps2_kbd_clk    ( ps2_kbd_clk     ),
    .ps2_kbd_data   ( ps2_kbd_data    ),
    .board_joystick1( joystick1[8:0]  ),
    .board_joystick2( joystick2[8:0]  ),
    .game_joystick1 ( game_joystick1  ),
    .game_joystick2 ( game_joystick2  ),
    .game_coin      ( game_coin       ),
    .game_start     ( game_start      ),
    .game_pause     ( game_pause      )
);
endmodule // jtgng_mist