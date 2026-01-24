`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.01.2026 22:38:30
// Design Name: 
// Module Name: relu
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module relu #(parameter WIDTH = 8)(
    input wire signed [WIDTH-1:0] data,
    output wire signed [WIDTH-1:0] out
);
    assign out = (data < 0) ? 0 : data;
endmodule
