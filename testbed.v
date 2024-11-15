module test_4bit_multiplier;
    // Define inputs and outputs
    reg [7:0] a, b;              // Inputs
    wire [7:0] output_byte;      // Output
    reg clock, reset;            // Clock and Reset

    // Instantiate the unit under test (UUT)
    pipelined_multiplier uut (
        .a(a),
        .b(b),
        .output_byte(output_byte),
        .clk(clock),
        .rst(reset)
    );

    // Clock generation
    initial begin
        clock = 0;
        forever #5 clock = ~clock; // 10ns clock period
    end

    // Reset sequence
    task reset_project;
        begin
            reset = 1;
            #10;
            reset = 0;
        end
    endtask

    // Convert custom floating-point to real number (Verilog equivalent of `to_float`)
    function real to_float(input [7:0] n);
        integer exp;
        real mant, val;
        begin
            exp = (n[6:3]);       // Extract exponent
            mant = n[2:0];       // Extract mantissa
            if (exp == 0) begin
                val = mant * 0.001953125; // Smallest representable value
            end else if (exp == 15) begin
                if (mant == 0) val = $realtobits(1.0/0.0); // Infinity
                else val = $realtobits(0.0/0.0);           // NaN
            end else begin
                mant = mant + 8;
                val = mant * 0.001953125 * (2.0 ** (exp - 1));
            end
            if (n[7] == 1) val = -val; // Apply sign
            to_float = val;
        end
    endfunction

    // Test all values
    initial begin
        reset_project(); // Reset the project
        integer i, j;
        real fa, fb, fo, max_diff;
        for (i = 0; i < 256; i = i + 1) begin
            for (j = 0; j < 256; j = j + 1) begin
                a = i;
                b = j;
                #10; // Wait for one clock cycle
                fa = to_float(a);
                fb = to_float(b);
                fo = to_float(output_byte);
                if ((fa + fb > 240 && fo == $realtobits(1.0/0.0)) || 
                    (fa + fb < -240 && fo == $realtobits(-1.0/0.0))) begin
                    // Correctly handled overflow
                    continue;
                end
                max_diff = max(abs(fa), abs(fb), abs(fa + fb)) / 8.0;
                if (abs(fo - (fa + fb)) > max_diff) begin
                    $display("%f + %f != %f (diff %f, raw %d, %d, %d)",
                             fa, fb, fo, abs(fo - (fa + fb)), a, b, output_byte);
                end
            end
        end
        $stop; // End the simulation
    end

    // Helper function: Maximum of three real numbers
    function real max(input real x, y, z);
        begin
            if (x > y && x > z) max = x;
            else if (y > z) max = y;
            else max = z;
        end
    endfunction
endmodule

// Example pipelined multiplier module (stub, replace with actual logic)
module pipelined_multiplier (
    input [7:0] a,
    input [7:0] b,
    output reg [7:0] output_byte,
    input clk,
    input rst
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            output_byte <= 0;
        end else begin
            // Add pipelined multiplier logic here
            output_byte <= a + b; // Placeholder for actual logic
        end
    end
endmodule
