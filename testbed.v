// Code your testbench here
// or browse Examples

`timescale 1ns / 1ps

module testbench;
    reg  [7:0] ui_in, uio_in;
    reg        ena, clk, rst_n;
    wire [7:0] uo_out;

    // Instantiate the DUT
    tt_um_btflv_8bit_fp_adder dut (
        .ui_in(ui_in),
        .uo_out(uo_out),
        .uio_in(uio_in),
        .uio_out(),
        .uio_oe(),
        .ena(ena),
        .clk(clk),
        .rst_n(rst_n)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Generate random input values
    integer i;
    reg [7:0] expected_output;

    initial begin
        // Initialize inputs
        rst_n = 0;
        ena = 0;
        ui_in = 8'd0;
        uio_in = 8'd0;
        
        // Reset the DUT
        #10 rst_n = 1;
        ena = 1;

        // Test multiple random values
        for (i = 0; i < 10; i = i + 1) begin
            // Generate random inputs
            ui_in = $random % 256;
            uio_in = $random % 256;

            // Wait for a clock edge to update the output
            #10;

            // Calculate the expected output
            expected_output = calculate_expected_output(ui_in, uio_in);

            // Print both results
            $display(
                "Test %0d: ui_in = %b, uio_in = %b | Expected = %b, DUT Output = %b | %s",
                i, ui_in, uio_in, expected_output, uo_out,
                (uo_out === expected_output) ? "PASS" : "FAIL"
            );
        end

        // End simulation
        $finish;
    end

    // Reference model for expected output
    function [7:0] calculate_expected_output(
        input [7:0] a,
        input [7:0] b
    );
        reg sign_a, sign_b, sign_res;
        reg [3:0] expo_a, expo_b, expo_res;
        reg [3:0] mant_a, mant_b, mant_res;
        reg add_sub; // 0 = add, 1 = subtract
        begin
            sign_a = a[7];
            sign_b = b[7];
            expo_a = a[6:3];
            expo_b = b[6:3];
            mant_a = {1'b1, a[2:0]};
            mant_b = {1'b1, b[2:0]};

            add_sub = (sign_a ^ sign_b); // XOR to determine operation type
            
            if (expo_a > expo_b) begin
                expo_res = expo_a;
                mant_b = mant_b >> (expo_a - expo_b);
            end else begin
                expo_res = expo_b;
                mant_a = mant_a >> (expo_b - expo_a);
            end

            if (add_sub) begin
                if (mant_a >= mant_b) begin
                    mant_res = mant_a - mant_b;
                    sign_res = sign_a;
                end else begin
                    mant_res = mant_b - mant_a;
                    sign_res = sign_b;
                end
            end else begin
                mant_res = mant_a + mant_b;
                if (mant_res[4]) begin
                    mant_res = mant_res >> 1;
                    expo_res = expo_res + 1;
                end
                sign_res = sign_a;
            end

            calculate_expected_output = {sign_res, expo_res, mant_res[2:0]};
        end
    endfunction
endmodule
