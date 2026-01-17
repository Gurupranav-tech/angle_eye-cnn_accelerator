module vgg_block_pe (
    input  wire clk,
    input  wire reset_n,
    input  wire start,
    input  wire [7:0] pixel_in,
    input  wire pixel_in_valid,
    output wire [7:0] pixel_out,
    output wire pixel_out_valid
);

    // Signals from FSM
    wire win_ready;
    wire [1:0] state;
    
    // Internal 3x3 window data (needs sliding window logic)
    wire signed [7:0] window_data [0:8];
    wire signed [7:0] kernel_weights [0:8]; // Hardcoded or from BRAM

    // 1. Instantiate the FSM Controller
    pe_controller controller_inst (
        .clk(clk),
        .reset_n(reset_n),
        .start(start),
        .pixel_in_valid(pixel_in_valid),
        .window_ready(win_ready),
        .output_valid(), // Handled by pipe delay
        .current_state(state)
    );

    // 2. Instantiate your MAC module
    mac #(.WIDTH(8), .ACCM_WIDTH(24), .KERNEL_SIZE(3)) mac_inst (
        .clk(clk),
        .reset(!reset_n),
        .acc_clear(!win_ready), // Clear when window isn't ready
        .weights(kernel_weights),
        .data(window_data),
        .q_shift(5'd8),         // Example shift
        .value(pixel_out)
    );

    // 3. Pipeline the valid signal
    // Your MAC code has a 1-cycle delay for the accumulator 
    // and another for the 'value' output.
    reg [1:0] v_pipe;
    always @(posedge clk) v_pipe <= {v_pipe[0], win_ready};
    assign pixel_out_valid = v_pipe[1];

endmodule