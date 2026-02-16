// model/cpp/arbiter_model.cpp
#include <cstdint>

// We use 'extern "C"' to prevent Name Mangling, allowing Python to call these functions via ctypes.
extern "C" {

    // Internal state: stores the index of the last winner (0 to 31)
    // Static ensures this variable persists between function calls.
    static int last_winner_bit = 0; 
    
    // Function to reset the model state
    void cpp_reset() {
        last_winner_bit = 0;
    }

    // Main function: Takes requests (req) and returns the grant (one-hot)
    // Assumes an Arbiter width of up to 32 bits.
    // req: Bitmask of requests (e.g., 4'b1010)
    // return: One-hot grant (e.g., 4'b0010)
    uint32_t cpp_eval_arbiter(uint32_t req) {
        
        // If there are no requests, grant is 0 and state does not change.
        if (req == 0) {
            return 0;
        }

        uint32_t next_winner_bit = last_winner_bit;

        // 1. Create a mask to isolate bits having HIGHER index than the last winner.
        // Logic: (1 << (last + 1)) - 1 creates a mask of 1s covering the last winner and below.
        // Inverting it (~) gives us 1s only for the upper bits.
        // Example: last_winner=1 (bit 1). Mask covers bits 0,1. Inverse covers 2,3...
        uint32_t mask_higher = ~((1 << (last_winner_bit + 1)) - 1);
        
        // 2. Apply mask to current requests
        uint32_t masked_req = req & mask_higher;

        // 3. Determine the winner
        if (masked_req != 0) {
            // Case A: There is a request with higher priority (no wrap-around needed).
            // __builtin_ctz returns the number of trailing zeros (finds the first '1' bit).
            // This is a highly optimized GCC/Clang built-in function.
            next_winner_bit = __builtin_ctz(masked_req);
        } else {
            // Case B: No higher priority requests. We wrap around to the beginning.
            // We just find the first '1' in the original request vector.
            next_winner_bit = __builtin_ctz(req);
        }

        // 4. Update state and return One-Hot Grant
        last_winner_bit = next_winner_bit;
        return (1 << next_winner_bit);
    }
}