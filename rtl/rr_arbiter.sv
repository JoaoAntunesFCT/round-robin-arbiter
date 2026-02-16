// rtl/rr_arbiter.sv
module rr_arbiter #(
    parameter N = 4 // Number of Clients
)(
    input  logic           clk,
    input  logic           rst_n,
    input  logic [N-1:0]   req,   // Request Vector (e.g., 4'b1010)
    output logic [N-1:0]   grant  // One-Hot Grant (e.g., 4'b0010)
);

    // Pointer Register: Points to the LAST winner.
    // Acts as the "barrier" for the circular priority.
    logic [N-1:0] last_winner_ptr;

    // Internal signals for arbitration logic
    logic [N-1:0] req_masked;
    logic [N-1:0] grant_masked;
    logic [N-1:0] grant_raw;
    logic [N-1:0] next_grant;

    // ============================================================
    // 1. MASKING LOGIC
    // ============================================================
    // We want to prioritize requests that have an index higher than 'last_winner_ptr'.
    // To do this, we create a 'thermometer' mask that blocks bits <= last_winner_ptr.
    
    logic [N-1:0] mask_thermometer;
    
    // Example: If last_winner_ptr is at bit 1 (0010),
    // mask_thermometer should be 1100 (allowing bits 2 and 3).
    // The standard trick: ~( (pointer << 1) - 1 ) does not work easily with One-Hot.
    // Instead, we can use a simpler double-width generated mask or a loop.
    // For clarity and synthesis, we use a combinatorial loop for the mask generation:
    
    always_comb begin
        mask_thermometer = '0;
        for (int i = 0; i < N; i++) begin
            if (i > last_winner_ptr) begin // This assumes last_winner_ptr is an index? No, it's one-hot.
                // Let's refine the approach for One-Hot Pointer.
                // We create a "mask_upper" that fills 1s above the current pointer bit.
            end
        end
    end
    
    // --- REFINED APPROACH: DOUBLE PRIORITY ARBITER ---
    // This is the standard industrial way to implement Round Robin cleanly.
    
    // Step A: Create a "Masked Request" vector.
    // Valid requests are only those strictly HIGHER than the current pointer.
    // Implementation:
    // 1. Create a "thermometer code" from the one-hot pointer.
    //    If pointer is 0010, thermometer is 0011.
    //    Invert it: 1100. AND with req.
    
    logic [N-1:0] pointer_thermometer;
    
    // Generate thermometer code (fill 1s from LSB up to pointer)
    assign pointer_thermometer[0] = last_winner_ptr[0];
    genvar i;
    generate
        for (i = 1; i < N; i++) begin : gen_therm
            assign pointer_thermometer[i] = last_winner_ptr[i] | pointer_thermometer[i-1];
        end
    endgenerate

    // Mask requests: Only keep requests ABOVE the current pointer
    assign req_masked = req & ~pointer_thermometer;

    // ============================================================
    // 2. FIXED PRIORITY ARBITERS (LSB Priority)
    // ============================================================
    // Function to find the first set bit (LSB)
    function automatic logic [N-1:0] get_first_one(logic [N-1:0] data_in);
        // "Isolate rightmost 1" trick: x & (-x)
        // Note: -x in 2's complement is (~x + 1)
        return data_in & (-data_in);
    endfunction

    assign grant_masked = get_first_one(req_masked); // Winner if we don't wrap around
    assign grant_raw    = get_first_one(req);        // Winner if we wrap around

    // ============================================================
    // 3. FINAL SELECTION & STATE UPDATE
    // ============================================================
    always_comb begin
        if (req_masked != 0) begin
            next_grant = grant_masked; // Someone higher is waiting
        end else begin
            next_grant = grant_raw;    // Wrap around to the beginning
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            last_winner_ptr <= 1; // Default reset: Point to bit 0
            grant           <= 0;
        end else begin
            grant <= next_grant;
            
            // Only update the pointer if a grant was actually issued
            if (next_grant != 0) begin
                last_winner_ptr <= next_grant;
            end
        end
    end

endmodule