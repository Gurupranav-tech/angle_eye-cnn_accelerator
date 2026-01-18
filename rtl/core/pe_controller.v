`timescale 1ns / 1ps

module pe_controller #(
    parameter IMG_WIDTH  = 224,
    parameter IMG_HEIGHT = 224
)(
    input  wire        clk,
    input  wire        reset_n,
    input  wire        start,
    input  wire        pixel_in_valid,
    
    // Control Signals for Datapath
    output reg         window_ready,    // Check if 3x3 window is formed
    output reg         acc_clear,       // Clears the memory used by previous mac
    output reg         output_valid,    // Checks if output is valid
    output reg [2:0]   current_state    // State var
);

    // --- State Encoding ---
    localparam START   = 3'd0;
    localparam LOAD    = 3'd1;
    localparam CONV    = 3'd2;
    localparam PADDING = 3'd3;
    localparam END     = 3'd4;

    reg [2:0] state, next_state;

    // --- Counters ---
    reg [31:0] total_pixel_cnt; 
    
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
                // Handshake to finish frame
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

            if (state == CONV && pixel_in_valid) 
                window_ready <= 1'b1;
            else 
                window_ready <= 1'b0;

            if (state == CONV && pixel_in_valid)
                acc_clear <= 1'b0; // Don't clear -> Accumulate
            else
                acc_clear <= 1'b1; // Clear -> Reset sum

            if (state == CONV && pixel_in_valid && window_ready) begin
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