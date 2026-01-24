`timescale 1ns / 1ps

module maxpool #(parameter KERNEL_SIZE=3, parameter WIDTH=8)(
    input wire clk,
    input wire reset,
    input  wire signed [WIDTH-1:0] data [0:KERNEL_SIZE*KERNEL_SIZE-1],
    output reg  signed [WIDTH-1:0] max_out
);
    reg signed [WIDTH-1:0] max;
    
    always @(*) begin
        max = data[0];
        for (integer i = 0; i < KERNEL_SIZE*KERNEL_SIZE; i = i + 1) begin
            if (max < data[i])
                max = data[i];
        end
    end
    
    always @(posedge clk) begin
        if (reset)
            max_out <= 0;
        else
            max_out <= max;
    end
endmodule
