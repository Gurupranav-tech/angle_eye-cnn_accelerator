// Sits inside PE_manger, recieves opcode memory part

module memory_controller #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 64,  // change to 8
    parameter BUF_DEPTH  = 1024
)(
    input  wire                 clk,
    input  wire                 reset,

    // Control from PE controller
    input  wire                   load_weights,     // signal to load weights from DDR to buffer
    input  wire                   load_residual,    // used for residuals
    input  wire                   buf_sel,          // 0 = A, 1 = B
    input  wire [ADDR_WIDTH-1:0]  base_addr,        // Address of 
    input  wire [15:0]            word_count,       // number of words to count

    output reg                  load_done,          // data loaded signal sent to PE_controller

    // DDR Read Interface
    output reg                   ddr_rd_req,        // signal to DDR to send data
    output reg  [ADDR_WIDTH-1:0] ddr_rd_addr,       // data address
    input  wire                  ddr_rd_valid,      // AXI has something similar. idk
    input  wire [DATA_WIDTH-1:0] ddr_rd_data,       // the actual word recieved

    // On-chip Buffers
    output reg  [DATA_WIDTH-1:0] bufA   [0:BUF_DEPTH-1],
    output reg  [DATA_WIDTH-1:0] bufB   [0:BUF_DEPTH-1],
    output reg  [DATA_WIDTH-1:0] resBuf [0:BUF_DEPTH-1]
);

    // FSM states (memory_manager can exist in 3 possible states:
    // IDLE: decide what to load
    // READ: actual reading of data
    // DONE: 
    localparam IDLE  = 2'b00;
    localparam READ  = 2'b01;
    localparam DONE  = 2'b10;

    reg [1:0] state;
    reg [15:0] count;

    // FSM to mannage state memory_manager is in
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state        <= IDLE;
            ddr_rd_req   <= 1'b0;
            ddr_rd_addr  <= {ADDR_WIDTH{1'b0}};
            count        <= 16'd0;
            load_done    <= 1'b0;
        end 
        
        else begin
            case (state)
                // IDLE state
                IDLE: begin
                    load_done  <= 1'b0;
                    count      <= 16'd0;
                    if (load_weights || load_residual) begin
                        ddr_rd_req  <= 1'b1;
                        ddr_rd_addr <= base_addr;
                        state       <= READ;
                    end
                end

                // READ
                READ: begin
                    if (ddr_rd_valid) begin
                        // Store data
                        if (load_residual) begin
                            resBuf[count] <= ddr_rd_data;
                        end else if (!buf_sel) begin
                            bufA[count] <= ddr_rd_data;
                        end else begin
                            bufB[count] <= ddr_rd_data;
                        end

                        count <= count + 1;
                        ddr_rd_addr <= ddr_rd_addr + (DATA_WIDTH/8);

                        if (count == word_count - 1) begin
                            ddr_rd_req <= 1'b0;
                            state      <= DONE;
                        end
                    end
                end

                // DONE
                DONE: begin
                    load_done <= 1'b1;
                    state     <= IDLE;
                end

            endcase
        end
    end
endmodule