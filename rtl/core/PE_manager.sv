`timescale 1ns / 1ps

module pe_controller #(
    parameter NUM_PE = 3   // must be 3*n for RGB
)(
    input              clk,
    input              rst_n,

    // Opcode interface
    input              opcode_valid,
    input      [63:0]  opcode,

    // Weight buffer status, 
    input              bufA_loaded,
    input              bufB_loaded,

    // PE done signals
    input      [NUM_PE-1:0] pe_done,

    // Outputs to PE array
    output reg [NUM_PE-1:0] pe_start,
    output reg              weight_buf_sel, // 0 = A, 1 = B

    // Tile indices
    output reg [15:0] cin_tile_idx,
    output reg [15:0] cout_tile_base,
    output reg [15:0] h_tile_idx,
    output reg [15:0] w_tile_idx,

    // Completion signal
    output reg              layer_done
);

    // Opcode decode (64-bit)
    wire [7:0] Cin_tiles;   // for 
    wire [7:0] Cout_tiles;
    wire [7:0] H_tiles;
    wire [7:0] W_tiles;
    
    // used for tiling purposes (in order to circumvent channel and spatial restrictions
    // Cin_tiles and Cout_tiles used for weights
    // H_tiles and W_tiles used for space
    assign Cin_tiles  = opcode[47:40];
    assign Cout_tiles = opcode[39:32];
    assign H_tiles    = opcode[31:24];
    assign W_tiles    = opcode[23:16];

    // FSM state encoding
    localparam IDLE       = 3'd0;
    localparam WAIT_BUF   = 3'd1;
    localparam START_TILE = 3'd2;
    localparam WAIT_PE    = 3'd3;
    localparam ADV_TILE   = 3'd4;
    localparam DONE       = 3'd5;

    reg [2:0] state, next_state;

    // Tile counters
    reg [15:0] cin_cnt;
    reg [15:0] cout_cnt;
    reg [15:0] h_cnt;
    reg [15:0] w_cnt;

    wire all_pe_done;
    assign all_pe_done = &pe_done;

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= IDLE;
            cin_cnt        <= 16'd0;
            cout_cnt       <= 16'd0;
            h_cnt          <= 16'd0;
            w_cnt          <= 16'd0;
            weight_buf_sel <= 1'b0;
        end else begin
            state <= next_state;

            // Initialize counters on new opcode
            if (state == IDLE && opcode_valid) begin
                cin_cnt  <= 16'd0;
                cout_cnt <= 16'd0;
                h_cnt    <= 16'd0;
                w_cnt    <= 16'd0;
            end

            // Advance tile counters
            if (state == ADV_TILE) begin
                if (cin_cnt + 1 < Cin_tiles) begin
                    cin_cnt <= cin_cnt + 1;
                end else begin
                    cin_cnt <= 16'd0;
                    if (cout_cnt + NUM_PE < Cout_tiles) begin
                        cout_cnt <= cout_cnt + NUM_PE;
                    end else begin
                        cout_cnt <= 16'd0;
                        if (w_cnt + 1 < W_tiles) begin
                            w_cnt <= w_cnt + 1;
                        end else begin
                            w_cnt <= 16'd0;
                            h_cnt <= h_cnt + 1;
                        end
                    end
                end
            end

            // Swap weight buffers after layer completes
            if (state == DONE) begin
                weight_buf_sel <= ~weight_buf_sel;
            end
        end
    end

    // Combinational FSM logic
    always @(*) begin
        next_state = state;
        pe_start   = {NUM_PE{1'b0}};
        layer_done = 1'b0;

        case (state)

            IDLE: begin
                if (opcode_valid)
                    next_state = WAIT_BUF;
            end

            WAIT_BUF: begin
                if ((weight_buf_sel == 1'b0 && bufA_loaded) ||
                    (weight_buf_sel == 1'b1 && bufB_loaded))
                    next_state = START_TILE;
            end

            START_TILE: begin
                pe_start   = {NUM_PE{1'b1}};
                next_state = WAIT_PE;
            end

            WAIT_PE: begin
                if (all_pe_done)
                    next_state = ADV_TILE;
            end

            ADV_TILE: begin
                if ((h_cnt + 1 >= H_tiles) &&
                    (w_cnt + 1 >= W_tiles) &&
                    (cout_cnt + NUM_PE >= Cout_tiles) &&
                    (cin_cnt + 1 >= Cin_tiles))
                    next_state = DONE;
                else
                    next_state = START_TILE;
            end

            DONE: begin
                layer_done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;

        endcase
    end

    // Tile index outputs
    always @(*) begin
        cin_tile_idx   = cin_cnt;
        cout_tile_base = cout_cnt;
        h_tile_idx     = h_cnt;
        w_tile_idx     = w_cnt;
    end
endmodule