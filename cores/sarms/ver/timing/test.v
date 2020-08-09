// Side Arms Timing Model, Jose Tejada, 8/8/2020

`timescale 1ns / 1ps

module test;

reg clk, rst;

initial begin
    clk=0;
    forever #62.5 clk=~clk;
end

initial begin
    rst = 1;
    #500 rst=0;
end

wire LHBL, LVBL, intrq, hsync, vsync, sync;

timing_model u_model(
    .rst    ( rst   ),
    .clk    ( clk   ),
    .LHBL   ( LHBL  ),
    .LVBL   ( LVBL  ),
    .intrq  ( intrq ),
    .hsync  ( hsync ),
    .vsync  ( vsync ),
    .sync   ( sync  )
);

jtframe_vtimer #(
    .HB_START ( 9'h0C7 ),
    .HB_END   ( 9'h147 ),
    .HCNT_END ( 9'h1FF ),
    .VB_START ( 9'hF0  ),
    .VB_END   ( 9'h10  ),
    .VCNT_END ( 9'hFF  ),
    .VS_START ( 9'h0   ),
    .VS_END   ( 9'h8   ),
    .HS_START ( 9'he7  ),
    .HS_END   ( 9'h127 ),
    .H_VB     ( 9'h7   ),
    .H_VS     ( 9'h1FF ),
    .HINIT    ( 9'h0FC )
) u_timer(
    .clk        ( clk   ),
    .pxl_cen    ( 1'b1  ),
    .vdump      (       ),
    .vrender    (       ),
    .vrender1   (       ),
    .H          (       ),
    .Hinit      (       ),
    .Vinit      (       ),
    .LHBL       (       ),
    .LVBL       (       ),
    .HS         (       ),
    .VS         (       )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars(0,test);
    $dumpon;
end

initial begin
    #60_000_000 $finish;
end

endmodule

module timing_model(
    input      rst,
    input      clk,
    output reg LHBL,
    output reg LVBL,
    output     intrq,
    output     hsync,
    output     vsync,
    output     sync
);

reg [8:0] H;
reg [7:0] V;
reg henb;

reg  [2:0] hout;
wire [3:0] vout;

assign intrq = vout[2];
wire   hinit = hout[2];
assign hsync = hout[1];
assign vsync = vout[1];
assign sync  = hsync & vsync;

reg [3:0] prom_h[0:255]; // 15h
reg [3:0] prom_v[0:255]; // 16h

assign vout = prom_v[V];

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        H <= 9'd0;
        V <= 9'd0;
        LHBL <= 1;
        LVBL <= 1;
    end else begin
        H <= H+1'd1;
        if( &H ) V<= V+1'd1;
        if( &H[2:0] ) begin
            LHBL <= hout[0];
            LVBL <= vout[0];
        end
    end
end

always @(posedge H[7] ) henb<=H[8];


integer f, cnt;

initial begin
    f=$fopen("63s141.15h","rb");
    cnt=$fread(prom_h,f);
    $fclose(f);
    f=$fopen("63s141.16h","rb");
    cnt=$fread(prom_v,f);
    $fclose(f);
end

always @(*) begin
    hout = !henb ? prom_h[H[7:0]^8'd1][2:0] : 3'd7;
end

endmodule