`timescale 1ns / 1ps

module control_unit #(parameter NUM_LAYERS = 7)(
    input wire clk,
    input wire reset,
    input wire start,
    input wire dma_done,
    input wire pe_done,
    output reg dma_start,
    output reg pe_start,
    output reg active_in_buf, //A=0, B=1
    output reg [2:0] layer_type,
    output reg done
    );
    
    localparam [2:0]
        IDLE = 3'b0,
        LOAD_INPUT = 3'b001,
        START_PE = 3'b010,
        WAIT_PE = 3'b011,
        SWAP_BUF = 3'b100,
        NEXT_LAYER = 3'b101,
        FINISH = 3'b110;
    
    reg [2:0] state;
    reg [2:0] next_state;
    reg [$clog2(NUM_LAYERS)-1:0] layer_idx;
    reg dma_busy;
    
    always@(posedge clk or posedge reset) begin
        if (reset)
            state <= IDLE;
        else
            state <= next_state;
    end
    
    always@(*) begin
        next_state = state;
        case(state)
            IDLE:
                if (start) next_state = LOAD_INPUT;
                
             LOAD_INPUT:
                if (dma_done) next_state = START_PE;
                
             START_PE:
                next_state = WAIT_PE;
                
             WAIT_PE:
                if (pe_done) next_state = SWAP_BUF;
                
              SWAP_BUF:
                next_state = NEXT_LAYER;
                
              NEXT_LAYER:
                if (layer_idx == NUM_LAYERS - 1) next_state = FINISH;
                else next_state = LOAD_INPUT;
                
              FINISH:
                next_state = FINISH;
               
        endcase
    end
    
    always@(posedge clk or posedge reset) begin
        if (reset) begin
            dma_start <= 0;
            pe_start <= 0;
            dma_busy <= 0;
            active_in_buf <= 0;
             layer_type <= 0;
             layer_idx <= 0;
             done <= 0;
        end
        else begin
            dma_start <= 0;
            pe_start <= 0;
            done <= 0;
            
            case (state)
                IDLE: begin
                    layer_idx <= 0;
                    dma_busy <= 0;
                end
                
                LOAD_INPUT: begin
                    if (!dma_busy) begin
                        dma_start <= 1;
                        dma_busy <= 1;
                    end
                end
                
                START_PE: pe_start <= 1'b1;
                
                WAIT_PE: begin
                    if (!dma_busy && layer_idx < NUM_LAYERS - 1) begin
                        dma_start <= 1;
                        dma_busy <= 1;
                    end
                end
                
                SWAP_BUF: begin
                    active_in_buf <= ~active_in_buf;
                    dma_busy <= 0;
                end
                
                NEXT_LAYER: layer_idx <= layer_idx + 1'b1;
                
                FINISH: done <= 1;
            endcase
            
            if (dma_done) dma_busy <= 0;
        end    
    end           
    
endmodule
