module vgg_block_pe #(
    parameter IMG_WIDTH  = 224,
    parameter DATA_WIDTH = 8
)
(
    input  wire clk,
    input  wire reset_n,
    input  wire start,
    input  wire [7:0] pixel_in,
    input  wire pixel_in_valid,
    output wire [7:0] pixel_out,
    output wire pixel_out_valid,

    input  wire signed [7:0] flat_weights [0:8],
    output wire [7:0] pixel_out,
    output wire pixel_out_valid
);

// --- Internal Signals for Windowing ---
    wire [7:0] row0_out, row1_out;   // Outputs from line buffers
    reg  [7:0] w0, w1, w2;           // Top Row (Oldest)
    reg  [7:0] w3, w4, w5;           // Middle Row
    reg  [7:0] w6, w7, w8;           // Bottom Row (Newest/Input)

    // Instantiate Line Buffers
    // Line Buffer 0: Takes input pixel, outputs pixel from 1 row ago
    line_buffer #(.IMG_WIDTH(IMG_WIDTH)) lb0 (
        .clk(clk), 
        .ce(pixel_in_valid), 
        .din(pixel_in), 
        .dout(row0_out)
    );

    // Line Buffer 1: Takes row0 output, outputs pixel from 2 rows ago
    line_buffer #(.IMG_WIDTH(IMG_WIDTH)) lb1 (
        .clk(clk), 
        .ce(pixel_in_valid), 
        .din(row0_out), 
        .dout(row1_out)
    );

    //Create the 3x3 Sliding Window Registers
    always @(posedge clk) begin
        if (pixel_in_valid) begin
            // Shift every row to the left
            
            // Top Row (Data coming from Line Buffer 1)
            w0 <= row1_out;
            w1 <= w0;
            w2 <= w1;

            // Middle Row (Data coming from Line Buffer 0)
            w3 <= row0_out;
            w4 <= w3;
            w5 <= w4;

            // Bottom Row (Fresh Data coming directly from input)
            w6 <= pixel_in;
            w7 <= w6;
            w8 <= w7;
        end
    end

    // Mapping, apparently Gemini told me that MAC expects an array named 'window_data' so we give it that
    assign window_data[0] = w2; assign window_data[1] = w1; assign window_data[2] = w0;
    assign window_data[3] = w5; assign window_data[4] = w4; assign window_data[5] = w3;
    assign window_data[6] = w8; assign window_data[7] = w7; assign window_data[8] = w6;



    // Signals from FSM
    wire win_ready;
    wire [1:0] state;
    
    wire signed [7:0] window_data [0:8];
    wire signed [7:0] kernel_weights [0:8];     // From BRAM

    pe_controller controller_inst (
        .clk(clk),
        .reset_n(reset_n),
        .start(start),
        .pixel_in_valid(pixel_in_valid),
        .window_ready(win_ready),
        .output_valid(),    // Handled by pipe delay
        .current_state(state)
    );

    mac #(.WIDTH(8), .ACCM_WIDTH(24), .KERNEL_SIZE(3)) mac_inst (
        .clk(clk),
        .reset(!reset_n),
        .acc_clear(!win_ready),  // Clear when window isn't ready
        .weights(kernel_weights),
        .data(window_data),
        .q_shift(5'd8),            // Example shift
        .value(pixel_out)
    );

    reg [1:0] v_pipe;
    always @(posedge clk) v_pipe <= {v_pipe[0], win_ready};
    assign pixel_out_valid = v_pipe[1];

endmodule