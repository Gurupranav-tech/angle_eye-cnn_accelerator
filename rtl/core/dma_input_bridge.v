`timescale 1ns / 1ps

module dma_input_bridge #(
    parameter DATA_W = 8,
    parameter ADDR_W = 12
)(
    input  wire                 clk,
    input  wire                 reset,

    // AXI-Stream from DMA (MM2S)
    input  wire [DATA_W-1:0]    s_axis_tdata,
    input  wire                 s_axis_tvalid,
    input  wire                 s_axis_tlast,
    output wire                 s_axis_tready,

    // From control unit
    input  wire                 active_in_buf, // 0 = A, 1 = B

    // Write ports to input buffer A
    output reg  [ADDR_W-1:0]    bufA_addr,
    output reg  [DATA_W-1:0]    bufA_data,
    output reg                  bufA_we,

    // Write ports to input buffer B
    output reg  [ADDR_W-1:0]    bufB_addr,
    output reg  [DATA_W-1:0]    bufB_data,
    output reg                  bufB_we,

    // Status back to control unit
    output reg                  dma_done
);

    // Always ready to accept stream
    assign s_axis_tready = 1'b1;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            bufA_addr <= 0;
            bufB_addr <= 0;
            bufA_we   <= 0;
            bufB_we   <= 0;
            dma_done  <= 0;
        end else begin
            bufA_we  <= 0;
            bufB_we  <= 0;
            dma_done <= 0;

            if (s_axis_tvalid) begin
                if (active_in_buf == 1'b0) begin
                    bufA_data <= s_axis_tdata;
                    bufA_we   <= 1'b1;
                    bufA_addr <= bufA_addr + 1'b1;
                end else begin
                    bufB_data <= s_axis_tdata;
                    bufB_we   <= 1'b1;
                    bufB_addr <= bufB_addr + 1'b1;
                end

                if (s_axis_tlast) begin
                    dma_done  <= 1'b1;
                    bufA_addr <= 0;
                    bufB_addr <= 0;
                end
            end
        end
    end

endmodule
