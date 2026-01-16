`timescale 1ns / 1ps

module mac_tb #(parameter WIDTH = 8, parameter ACCM_WIDTH = 24, parameter KERNEL_SIZE = 3) (
    input wire clk,
    input wire reset,
    input wire signed [WIDTH-1:0] weights[KERNEL_SIZE * KERNEL_SIZE - 1:0],
    input wire signed [WIDTH-1:0] data[KERNEL_SIZE * KERNEL_SIZE - 1:0],
    input wire [WIDTH/2:0] q_shift,
    output reg signed [WIDTH-1:0] value
);
    reg signed [ACCM_WIDTH-1:0] accumulator;
    
    always @(posedge clk) begin
        if (reset)
            accumulator = 0;
            
        for (integer i = 0; i < WIDTH; i = i + 1)
            accumulator = accumulator + weights[i] * data[i];
            
        if ((accumulator >>> q_shift) > 127)
            value <= 127;
        else if ((accumulator >>> q_shift) < -128)
            value <= -128;
        else
            value <= (accumulator >>> q_shift)[7:0];
    end
endmodule
