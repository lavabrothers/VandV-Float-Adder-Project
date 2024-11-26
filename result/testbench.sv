`timescale 1ns / 1ps

module tb_um_btflv_8bit_fp_adder;
 
// inputs 
  reg [7:0] a;
  reg [7:0] b;
  reg ena, clk, rst_n;
  
// outputs
  wire [7:0] out;
  wire [7:0] uio_oe; // IOs: Enable path (active high: 0=input, 1=output)
  wire [7:0] uio_out; // IOs: Output path
  
  // test counts and variables 
  real total = 175;
  real correct = 0;
  real percentage;
  real tolerance = 0.125;
  
  real expected;
  real decimal_a;
  real decimal_b;
  real result;
  
  // Test summary variables
  integer test_number = 0;
  integer failed_tests[$];  // Queue to store failed test numbers
  real failed_inputs[$];    // Queue to store input values for failed tests
  real failed_expected[$];  // Queue to store expected values for failed tests
  real failed_results[$];   // Queue to store actual results for failed tests
  
  // Define covergroup types first
  typedef struct {
    logic sign;
    logic [3:0] exponent;
    logic [2:0] mantissa;
  } fp_components;
  
  // Coverage group for floating point components
  covergroup fp_components_cov;
      option.per_instance = 1;
      option.goal = 100;
      
      cp_sign: coverpoint fp_components_a.sign {
          bins negative = {1'b1};
          bins positive = {1'b0};
      }
      
      cp_exponent: coverpoint fp_components_a.exponent {
          bins zero = {4'h0};
          bins low = {[4'h1:4'h3]};
          bins mid = {[4'h4:4'h7]};
          bins high = {[4'h8:4'hB]};
          bins max = {[4'hC:4'hF]};
      }
      
      cp_mantissa: coverpoint fp_components_a.mantissa {
          bins zero = {3'h0};
          bins low = {[3'h1:3'h3]};
          bins high = {[3'h4:3'h7]};
      }
      
      cp_special_cases: cross cp_sign, cp_exponent, cp_mantissa {
          bins zero_value = binsof(cp_mantissa.zero) && binsof(cp_exponent.zero);
          bins max_value = binsof(cp_mantissa.high) && binsof(cp_exponent.max);
      }
  endgroup

  // Control signals coverage group
  covergroup ctrl_signals_cov;
      option.per_instance = 1;
      
      cp_ena: coverpoint ena {
          bins disabled = {1'b0};
          bins enabled = {1'b1};
      }
      
      cp_rst_n: coverpoint rst_n {
          bins reset = {1'b0};
          bins active = {1'b1};
      }
      
      cp_control_combo: cross cp_ena, cp_rst_n {
          bins valid_combinations = binsof(cp_ena) && binsof(cp_rst_n);
      }
  endgroup
  
  // Instantiate coverage
  fp_components fp_components_a, fp_components_b, fp_components_result;
  fp_components_cov fp_cov_a, fp_cov_b, fp_cov_result;
  ctrl_signals_cov ctrl_cov;
  
  tt_um_btflv_8bit_fp_adder adder(
    .ui_in(a),
    .uio_in(b),
    .ena(ena),
    .clk(clk),
    .rst_n(rst_n),
    .uo_out(out),
    .uio_out(uio_out),
    .uio_oe(uio_oe)
  );
      
  // Function to convert 8-bit input to decimal floating point
  function real convert_to_decimal(input logic [7:0] fp_input);
      real decimal_value = 0;
      real mantissa_value = 0;
      real exponent_value = 0;
      logic sign;
      logic [3:0] exponent;
      logic [2:0] mantissa;
      integer expo = 1;
      
      // Extract the sign, exponent, and mantissa from the 8-bit input
      sign = fp_input[7];              // MSB is the sign bit
      exponent = fp_input[6:3];        // Next 4 bits are the exponent
      mantissa = fp_input[2:0];        // Last 3 bits are the mantissa
    
      // Convert mantissa to real (normalized: 1.mantissa in binary)
      mantissa_value = 1.0;            // Implicit leading 1 in normalized form
      for (int i = 2; i >= 0; i--) begin
        if(mantissa[i] == 1) begin
          mantissa_value += ((2.0 ** -(expo)));
        end 
        expo++;
      end
      expo = 1;
      
      // Convert exponent to real, applying bias of 7 for 4-bit exponent
      exponent_value = exponent - 7.0;

      // Calculate the decimal value (with sign)
      decimal_value = (sign ? -1 : 1) * mantissa_value * (2.0 ** exponent_value);

      return decimal_value;
  endfunction
  
  class testNums;
    rand bit sign_a;
    rand bit sign_b;
    rand bit [3:0] exponent_a;
    rand bit [3:0] exponent_b;
    rand bit [2:0] mantissa_a;
    rand bit [2:0] mantissa_b;
    
    // constraints
    constraint distro {
      mantissa_a dist{0 :/ 30, [1:3] :/ 30 , [4:7] :/ 40 };
      mantissa_b dist{0 :/ 30, [1:3] :/ 30 , [4:7] :/ 40 };
      exponent_a dist{0 :/ 30, [1:7] :/ 30 , [8:16]:/ 40 };
      exponent_b dist{0 :/ 30, [1:7] :/ 30 , [8:16]:/ 40 };
    }
    
    // Function to combine sign, exponent, and mantissa into an 8-bit number
    function bit [7:0] combine_to_8bit_a();
      combine_to_8bit_a = {sign_a, exponent_a, mantissa_a}; // Concatenate fields
    endfunction

    // Function to combine sign, exponent, and mantissa into an 8-bit number for 'b'
    function bit [7:0] combine_to_8bit_b();
      combine_to_8bit_b = {sign_b, exponent_b, mantissa_b}; // Concatenate fields
    endfunction
  endclass
  
  // create the clock
  always #10 clk = ~clk;
  
  // Function to extract components
  function void extract_components(input logic [7:0] value, output fp_components comp);
    comp.sign = value[7];
    comp.exponent = value[6:3];
    comp.mantissa = value[2:0];
  endfunction

  // Function to print test summary
  function void print_test_summary();
    $display("\n=== Test Summary ===");
    $display("Total Tests Run: %0d", total);
    $display("Tests Passed: %0d", correct);
    $display("Tests Failed: %0d", total - correct);
    $display("Pass Rate: %0.2f%%", percentage);
    
    if (failed_tests.size() > 0) begin
      $display("\n=== Failed Test Details ===");
      for (int i = 0; i < failed_tests.size(); i++) begin
        $display("\nTest #%0d:", failed_tests[i]);
        $display("Input A: %f", failed_inputs[2*i]);
        $display("Input B: %f", failed_inputs[2*i+1]);
        $display("Expected: %f", failed_expected[i]);
        $display("Actual: %f", failed_results[i]);
        $display("Difference: %f", $abs(failed_expected[i] - failed_results[i]));
      end
    end
    
    if (percentage == 100)
      $display("\nTEST PASSED: All calculations within tolerance");
    else
      $display("\nTEST FAILED: Some calculations exceeded tolerance");
  endfunction
  
  // Main test sequence
  initial begin
    testNums nums = new();
    
    // Initialize coverage
    fp_cov_a = new();
    fp_cov_b = new();
    fp_cov_result = new();
    ctrl_cov = new();
    
    // Initialize inputs
    repeat (total) begin
      test_number++;
      assert(nums.randomize()) else $error("Randomization failed");
      clk = 0;
      rst_n = 0;       // Start with reset active
      ena = 0;
      a = 0;
      b = 0;

      // Sample control coverage
      ctrl_cov.sample();

      // Wait 20 time units then de-assert reset
      rst_n = 1;
      #20;

      // Apply test values and enable
      ena = 1;
      #20;

      a = nums.combine_to_8bit_a();
      b = nums.combine_to_8bit_b();
      
      // Extract components and sample coverage
      extract_components(a, fp_components_a);
      extract_components(b, fp_components_b);
      fp_cov_a.sample();
      fp_cov_b.sample();
      
      // Sample control coverage after changes
      ctrl_cov.sample();
      
      #60;
      
      decimal_a = convert_to_decimal(a);
      decimal_b = convert_to_decimal(b);
      expected = decimal_a + decimal_b;
      result = convert_to_decimal(out);

      // Sample result coverage
      extract_components(out, fp_components_result);
      fp_cov_result.sample();

      if ($abs(expected - result) < tolerance) begin
        correct++;
      end else begin
        // Store failed test information
        failed_tests.push_back(test_number);
        failed_inputs.push_back(decimal_a);
        failed_inputs.push_back(decimal_b);
        failed_expected.push_back(expected);
        failed_results.push_back(result);
      end          
    end
    
    percentage = (correct / total) * 100;
    
    // Print final test summary
    print_test_summary();
    
    // Print coverage report
    $display("\n=== Coverage Report ===");
    $display("Control Coverage: %0.2f%%", $get_coverage());
    
    #100 $finish;
  end
  
endmodule