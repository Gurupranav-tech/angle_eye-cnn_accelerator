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
    output reg out_buf_clr,
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
            active_in_buf <= 0;
            out_buf_clr <= 0;
             layer_type <= 0;
             layer_idx <= 0;
             done <= 0;
        end
        else begin
            dma_start <= 0;
            pe_start <= 0;
            out_buf_clr <= 0;
            done <= 0;
            
            case (state)
                IDLE: layer_idx <= 0;
                
                LOAD_INPUT: dma_start <= 1'b1;
                
                START_PE: pe_start <= 1'b1;
                
                WAIT_PE: begin
                end
                
                SWAP_BUF: begin
                    active_in_buf <= ~active_in_buf;
                    out_buf_clr <= 1'b1;
                end
                
                NEXT_LAYER: layer_idx <= layer_idx + 1'b1;
                
                FINISH: done <= 1;
            endcase
        end    
    end           
    
endmodule
