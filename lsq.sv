// RTL for Load/Store Queue (LSQ) with WAR and RAW hazard handling
//Author:Praveen Saravanan
module lsq #(
    parameter WIDTH = 32, 
    parameter DEPTH = 8,
    parameter ADDR_BITS = $clog2(DEPTH)
) (
    input  logic              clk,
    input  logic              rst,
    
    // Request interface
    input  logic              req_valid,
    input  logic [3:0]        opcode,   // 0000 = LOAD, 0001 = STORE
    input  logic [WIDTH-1:0]  addr,
    input  logic [WIDTH-1:0]  data_in,
    
    // Load response
    output logic              load_valid,
    output logic [WIDTH-1:0]  data_out,
    
    // Status outputs
    output logic              store_full,
    output logic              load_full
);

    // Queue entry types
    typedef struct packed {
        logic [WIDTH-1:0] addr;
        logic [WIDTH-1:0] data;
        logic             valid;
    } store_entry_t;
    
    typedef struct packed {
        logic [WIDTH-1:0] addr;
        logic             valid;
    } load_entry_t;

    // Queue storage
    store_entry_t store_q[DEPTH];
    load_entry_t  load_q[DEPTH];
    
    // Queue pointers - properly sized
    logic [ADDR_BITS:0] store_head, store_tail;  // Extra bit for full detection
    logic [ADDR_BITS:0] load_head, load_tail;
    
    // Memory array 
    logic [WIDTH-1:0] memory[2**10];  
    
    // Internal signals
    logic [WIDTH-1:0] pending_data;
    logic             forwarding_hit;
    logic             store_queue_empty, load_queue_empty;
    
    // Queue status
    assign store_full = ((store_tail + 1'b1) == store_head);
    assign load_full = ((load_tail + 1'b1) == load_head);
    assign store_queue_empty = (store_head == store_tail);
    assign load_queue_empty = (load_head == load_tail);

    
    always_ff @(posedge clk) begin
        if (rst) begin
            // Reset all pointers
            store_head <= '0;
            store_tail <= '0;
            load_head  <= '0;
            load_tail  <= '0;
            
            // Reset load outputs
            load_valid <= 1'b0;
            data_out   <= '0;
            
            // Initialize all queue entries
            for (int i = 0; i < DEPTH; i++) begin
                store_q[i].valid <= 1'b0;
                store_q[i].addr  <= '0;
                store_q[i].data  <= '0;
                load_q[i].valid  <= 1'b0;
                load_q[i].addr   <= '0;
            end
            
            // Initialize memory (optional)
            for (int i = 0; i < 2**10; i++) begin
                memory[i] <= '0;
            end
            
        end else begin
            load_valid <= 1'b0;
          
            if (req_valid) begin
                if (opcode == 4'b0001 && !store_full) begin // STORE
                    store_q[store_tail[ADDR_BITS-1:0]].addr  <= addr;
                    store_q[store_tail[ADDR_BITS-1:0]].data  <= data_in;
                    store_q[store_tail[ADDR_BITS-1:0]].valid <= 1'b1;
                    store_tail <= store_tail + 1'b1;
                end else if (opcode == 4'b0000 && !load_full) begin // LOAD
                    load_q[load_tail[ADDR_BITS-1:0]].addr  <= addr;
                    load_q[load_tail[ADDR_BITS-1:0]].valid <= 1'b1;
                    load_tail <= load_tail + 1'b1;
                end
            end
            
            // === LOAD COMMIT LOGIC ===
            if (!load_queue_empty && load_q[load_head[ADDR_BITS-1:0]].valid) begin
                if (forwarding_hit) begin
                    data_out   <= pending_data;     // RAW bypass
                    load_valid <= 1'b1;
                end else begin
                    // Use only lower 10 bits for memory addressing
                    data_out   <= memory[load_q[load_head[ADDR_BITS-1:0]].addr[9:0]];
                    load_valid <= 1'b1;
                end
                
                // Mark entry as invalid and advance head
                load_q[load_head[ADDR_BITS-1:0]].valid <= 1'b0;
                load_head <= load_head + 1'b1;
            end
            
            // === STORE COMMIT LOGIC ===
            if (!store_queue_empty && store_q[store_head[ADDR_BITS-1:0]].valid) begin
                // Use only lower 10 bits for memory addressing
                memory[store_q[store_head[ADDR_BITS-1:0]].addr[9:0]] <= store_q[store_head[ADDR_BITS-1:0]].data;
                store_q[store_head[ADDR_BITS-1:0]].valid <= 1'b0;
                store_head <= store_head + 1'b1;
            end
        end
    end

    // === Hazard Checking (RAW forwarding) - COMBINATIONAL ===
    always_comb begin
        forwarding_hit = 1'b0;
        pending_data   = '0;
        
        // Only check if there's a valid load at head
        if (!load_queue_empty && load_q[load_head[ADDR_BITS-1:0]].valid) begin
            // Check all valid store entries for address match
            for (int i = 0; i < DEPTH; i++) begin
                if (store_q[i].valid && 
                    store_q[i].addr == load_q[load_head[ADDR_BITS-1:0]].addr) begin
                    forwarding_hit = 1'b1;
                    pending_data   = store_q[i].data;
                    // Break on first match (could prioritize newest)
                    break;
                end
            end
        end
    end

endmodule
