`timescale 1ns / 1ps

module mac #(
    parameter WIDTH = 8,
    parameter ACCM_WIDTH = 24,
    parameter KERNEL_SIZE = 3
)(
    input  wire clk,
    input  wire reset,
    input  wire acc_clear,   // clear accumulator for new output pixel
    input  wire signed [WIDTH-1:0] weights [0:KERNEL_SIZE*KERNEL_SIZE-1],
    input  wire signed [WIDTH-1:0] data    [0:KERNEL_SIZE*KERNEL_SIZE-1],
    input  wire [4:0] q_shift,
    output reg  signed [WIDTH-1:0] value
);

    integer i;

    reg signed [ACCM_WIDTH-1:0] accumulator;
    wire signed [ACCM_WIDTH-1:0] shifted;
    reg signed [ACCM_WIDTH-1:0] temp_sum;
    
    assign shifted = accumulator <<< q_shift;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            accumulator <= 0;
        end else begin
            temp_sum = acc_clear ? 0 : accumulator;

            // 3x3 MAC
            for (i = 0; i < KERNEL_SIZE*KERNEL_SIZE; i = i + 1)
                temp_sum = temp_sum + (weights[i] * data[i]);

            accumulator <= temp_sum;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            value <= 0;
        end else begin
            if ((accumulator >>> q_shift) > 127)
                value <= 127;
            else if ((accumulator >>> q_shift) < -128)
                value <= -128;
            else
                value <= shifted[7:0];
        end
    end

endmodule
