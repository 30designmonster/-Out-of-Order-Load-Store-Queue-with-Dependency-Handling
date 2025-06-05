//Testbench for the design
//Author:Praveen Saravanan
module tb_lsq;

    parameter WIDTH = 32;
    parameter DEPTH = 8;
    
    logic              clk;
    logic              rst;
    logic              req_valid;
    logic [3:0]        opcode;
    logic [WIDTH-1:0]  addr;
    logic [WIDTH-1:0]  data_in;
    logic              load_valid;
    logic [WIDTH-1:0]  data_out;
    logic              store_full;
    logic              load_full;

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // DUT instantiation
    lsq #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH)
    ) u_lsq (
        .clk(clk),
        .rst(rst),
        .req_valid(req_valid),
        .opcode(opcode),
        .addr(addr),
        .data_in(data_in),
        .load_valid(load_valid),
        .data_out(data_out),
        .store_full(store_full),
        .load_full(load_full)
    );

    // Test stimulus
    initial begin
        // Initialize
        rst = 1;
        req_valid = 0;
        opcode = 0;
        addr = 0;
        data_in = 0;
        
        // Reset
        #20;
        rst = 0;
        #10;
        
        $display("=== LSQ Test Started ===");
        
        // Test 1: Simple store and load
        $display("\n--- Test 1: Simple Store/Load ---");
        @(posedge clk);
        req_valid = 1;
        opcode = 4'b0001;  // STORE
        addr = 32'h100;
        data_in = 32'hDEADBEEF;
        
        @(posedge clk);
        req_valid = 0;
        
        // Wait a cycle for store to commit
        #20;
        
        // Now load from same address
        @(posedge clk);
        req_valid = 1;
        opcode = 4'b0000;  // LOAD
        addr = 32'h100;
        
        @(posedge clk);
        req_valid = 0;
        
        // Wait for load response
        @(posedge clk);
        if (load_valid && data_out == 32'hDEADBEEF) begin
            $display("✓ Simple store/load passed: got 0x%08x", data_out);
        end else begin
            $display("✗ Simple store/load failed: expected 0xDEADBEEF, got 0x%08x", data_out);
        end
        
        // Test 2: RAW hazard (store followed immediately by load)
        $display("\n--- Test 2: RAW Hazard ---");
        @(posedge clk);
        req_valid = 1;
        opcode = 4'b0001;  // STORE
        addr = 32'h200;
        data_in = 32'h12345678;
        
        @(posedge clk);
        opcode = 4'b0000;  // LOAD (same address)
        addr = 32'h200;
        
        @(posedge clk);
        req_valid = 0;
        
        // Check if forwarding works
        @(posedge clk);
        if (load_valid && data_out == 32'h12345678) begin
            $display("✓ RAW forwarding passed: got 0x%08x", data_out);
        end else begin
            $display("✗ RAW forwarding failed: expected 0x12345678, got 0x%08x", data_out);
        end
        
        #100;
        $display("\n=== Test Completed ===");
        $finish;
    end
    
    // Monitor outputs
    always @(posedge clk) begin
        if (load_valid) begin
            $display("LOAD RESPONSE: data=0x%08x at time %0t", data_out, $time);
        end
    end

    // Generate VCD
    initial begin
        $dumpfile("lsq.vcd");
        $dumpvars(0, tb_lsq);
    end

endmodule
