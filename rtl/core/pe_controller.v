`timescale 1ns / 1ps

module pe_controller #(
    parameter IMG_WIDTH  = 224,
    parameter IMG_HEIGHT = 224
)(
    input  wire        clk,
    input  wire        reset_n,
    input  wire        start,
    input  wire        pixel_in_valid,  // Comes from AXI Stream (tvalid)
    
    // Control Signals for Datapath
    output reg         window_ready,    // Enables the MAC calculations
    output reg         acc_clear,       // Resets your mac.v accumulator
    output reg         output_valid,    // Signals that the output pixel is valid
    output reg [2:0]   current_state    // Debugging state output
);

    // --- State Encoding ---
    localparam START   = 3'd0;
    localparam LOAD    = 3'd1; // Filling line buffers
    localparam CONV    = 3'd2; // Valid 3x3 window available
    localparam PADDING = 3'd3; // Handling edge cases (optional)
    localparam END     = 3'd4;

    reg [2:0] state, next_state;

    // --- Counters ---
    // Total count determines when we have enough data to start
    reg [31:0] total_pixel_cnt; 
    
    // Row/Col counters determine X,Y position for boundary checks
    reg [10:0] col_cnt;
    reg [10:0] row_cnt;

    // --- State Machine Update ---
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) 
            state <= START;
        else 
            state <= next_state;
    end

    // --- Next State Logic ---
    always @(*) begin
        case (state)
            START: begin
                if (start) next_state = LOAD;
                else       next_state = START;
            end

            LOAD: begin
                // Wait until we have 2 full rows + 3 pixels (minimum for 3x3)
                if (total_pixel_cnt >= (IMG_WIDTH * 2 + 3)) 
                    next_state = CONV;
                else 
                    next_state = LOAD;
            end

            CONV: begin
                // Stay in CONV as long as pixels are flowing and we aren't finished
                if (total_pixel_cnt >= (IMG_WIDTH * IMG_HEIGHT))
                    next_state = END;
                else if (!pixel_in_valid)
                    // If stream pauses, we might go to a STALL state, 
                    // or just stay here but disable window_ready (handled in output logic)
                    next_state = CONV; 
                else
                    next_state = CONV;
            end

            END: begin
                // Handshake to finish frame (tlast logic would go here)
                next_state = START;
            end

            default: next_state = START;
        endcase
    end

    // --- Output & Counter Logic ---
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            col_cnt <= 0;
            row_cnt <= 0;
            total_pixel_cnt <= 0;
            window_ready <= 0;
            acc_clear <= 1;
            output_valid <= 0;
        end else begin
            
            // Default Control Signals
            current_state <= state;
            
            // 1. Counter Updates (Only increment on valid input)
            if (pixel_in_valid && (state == LOAD || state == CONV)) begin
                total_pixel_cnt <= total_pixel_cnt + 1;
                
                if (col_cnt == IMG_WIDTH - 1) begin
                    col_cnt <= 0;
                    row_cnt <= row_cnt + 1;
                end else begin
                    col_cnt <= col_cnt + 1;
                end
            end else if (state == START) begin
                total_pixel_cnt <= 0;
                col_cnt <= 0;
                row_cnt <= 0;
            end

            // 2. Window Ready Logic (Enable MAC)
            // The MAC is active only when in CONV state AND we have a valid pixel coming in.
            if (state == CONV && pixel_in_valid) 
                window_ready <= 1'b1;
            else 
                window_ready <= 1'b0;

            // 3. Accumulator Clear Logic (For your mac.v)
            // We clear the accumulator if we are NOT ready to compute.
            // This ensures it stays at 0 until a valid window arrives.
            if (state == CONV && pixel_in_valid)
                acc_clear <= 1'b0; // Don't clear -> Accumulate
            else
                acc_clear <= 1'b1; // Clear -> Reset sum

            // 4. Output Valid Logic
            // The 3x3 convolution output is only valid if the center of the kernel 
            // is not on the padding border.
            // Valid region: Rows [1..H-2], Cols [1..W-2]
            if (state == CONV && pixel_in_valid && window_ready) begin
                // Assuming 'Same' padding output or 'Valid' cut
                // For 'Valid' convolution (image shrinks):
                if (row_cnt >= 2 && col_cnt >= 2) 
                    output_valid <= 1'b1;
                else 
                    output_valid <= 1'b0;
            end else begin
                output_valid <= 1'b0;
            end
        end
    end

endmodule