module line_buffer #(
    parameter DATA_WIDTH = 8,
    parameter IMG_WIDTH  = 224
)(
    input  wire clk,
    input  wire ce,            // Clock Enable
    input  wire [DATA_WIDTH-1:0] din,
    output wire [DATA_WIDTH-1:0] dout
);

    // RAM (either to BRAM or LUTRAM)
    reg [DATA_WIDTH-1:0] ram [0:IMG_WIDTH-1];
    reg [10:0] rd_ptr = 0;

    always @(posedge clk) begin
        if (ce) begin
            // Read the old pixel (from the row above)
            dout <= ram[rd_ptr];
            
            // Overwrite it with the new pixel (for the next time)
            ram[rd_ptr] <= din;
            
            // Increment pointer, wrap around at image width
            if (rd_ptr == IMG_WIDTH - 1)
                rd_ptr <= 0;
            else
                rd_ptr <= rd_ptr + 1;
        end
    end

endmodule