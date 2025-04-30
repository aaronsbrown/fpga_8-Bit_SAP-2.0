`timescale 1ns / 1ps

// Import necessary packages
import test_utils_pkg::*;
import arch_defs_pkg::*;

module alu_tb;

    // Testbench signals
    logic clk;
    logic reset;
    logic [DATA_WIDTH-1:0] tb_a_in;
    logic [DATA_WIDTH-1:0] tb_b_in;
    logic [2:0]            tb_alu_op;
    logic                  tb_carry_in;

    // DUT outputs
    wire [DATA_WIDTH-1:0] dut_latched_result;
    wire                  dut_zero_flag;
    wire                  dut_carry_flag;
    wire                  dut_negative_flag;

    // Instantiate the DUT
    alu uut (
        .clk(clk),
        .reset(reset),
        .in_one(tb_a_in),
        .in_two(tb_b_in),
        .in_carry(tb_carry_in),
        .alu_op(tb_alu_op),
        .latched_result(dut_latched_result),
        .zero_flag(dut_zero_flag),
        .carry_flag(dut_carry_flag),
        .negative_flag(dut_negative_flag)
    );

    // Clock generation (e.g., 10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Helper task for applying stimulus and checking results
    // CORRECTED: Removed op.name(), added string op_name argument
    task apply_and_check (
        input [DATA_WIDTH-1:0]  a,
        input [DATA_WIDTH-1:0]  b,
        input logic             carry,
        input alu_op_t          op,
        input string            op_name, // <<< Added string for operation name
        input [DATA_WIDTH-1:0]  exp_result,
        input logic             exp_c,
        input logic             exp_z,
        input logic             exp_n,
        input string            description
    );
        // Use negedge to change inputs (setup time before posedge)
        @(negedge clk);
        tb_a_in   = a;
        tb_b_in   = b;
        tb_carry_in = carry;
        tb_alu_op = op;
        // CORRECTED: Use op_name string in display
        $display("Applying: %s (A=%h, B=%h, Carry=%h, Op=%s)", description, a, b, carry, op_name);

        // Wait for posedge clk - DUT calculates combinationally and latches result
        @(posedge clk);
        #1; // Small delay for waveform clarity / allow combinational flags to settle

        // Check results immediately after the clock edge
        pretty_print_assert_vec(dut_latched_result, exp_result, $sformatf("%s - Result", description));
        pretty_print_assert_vec(dut_carry_flag,     exp_c,      $sformatf("%s - Carry Flag", description));
        pretty_print_assert_vec(dut_zero_flag,      exp_z,      $sformatf("%s - Zero Flag", description));
        pretty_print_assert_vec(dut_negative_flag,  exp_n,      $sformatf("%s - Negative Flag", description));
        $display("----------------------------------------");

    endtask

    // Testbench stimulus sequence
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, alu_tb); // Dump all signals in this testbench module

        $display("--- ALU Testbench Start ---");

        // 1. Reset sequence
        reset = 1;
        tb_a_in = 'x; // Drive inputs to 'x' during reset
        tb_b_in = 'x;
        tb_carry_in = 'x;
        tb_alu_op = 'x;
        @(posedge clk);
        #1;
        pretty_print_assert_vec(dut_latched_result, {DATA_WIDTH{1'b0}}, "Reset - Result");
        $display("Reset Applied");
        @(negedge clk);
        reset = 0;
        $display("Reset Released");
        $display("----------------------------------------");

        // Wait a cycle for reset release to propagate if needed
        @(posedge clk);
        #1;

        // FLAGS: C / Z / N

        // 2. Test ADD operations
        apply_and_check(8'h05, 8'h03, 8'b0, ALU_ADD, "ADD", 8'h08, 1'b0, 1'b0, 1'b0, "ADD: 5 + 3");
        apply_and_check(8'h00, 8'h00, 1'b0, ALU_ADD, "ADD", 8'h00, 1'b0, 1'b1, 1'b0, "ADD: 0 + 0");
        apply_and_check(8'hFF, 8'h01, 1'b0, ALU_ADD, "ADD", 8'h00, 1'b1, 1'b1, 1'b0, "ADD: 255 + 1");
        apply_and_check(8'h80, 8'h01, 1'b0, ALU_ADD, "ADD", 8'h81, 1'b0, 1'b0, 1'b1, "ADD: 128 + 1");
        apply_and_check(8'h7F, 8'h01, 1'b0, ALU_ADD, "ADD", 8'h80, 1'b0, 1'b0, 1'b1, "ADD: 127 + 1");
        apply_and_check(8'hF0, 8'hF0, 1'b0, ALU_ADD, "ADD", 8'hE0, 1'b1, 1'b0, 1'b1, "ADD: 240 + 240");

        // 3. Test SUB operations
        apply_and_check(8'h08, 8'h03, 1'b0, ALU_SUB, "SUB", 8'h05, 1'b1, 1'b0, 1'b0, "SUB: 8 - 3");
        apply_and_check(8'h05, 8'h05, 1'b0, ALU_SUB, "SUB", 8'h00, 1'b1, 1'b1, 1'b0, "SUB: 5 - 5");
        apply_and_check(8'h03, 8'h05, 1'b0, ALU_SUB, "SUB", 8'hFE, 1'b0, 1'b0, 1'b1, "SUB: 3 - 5");
        apply_and_check(8'h00, 8'h01, 1'b0, ALU_SUB, "SUB", 8'hFF, 1'b0, 1'b0, 1'b1, "SUB: 0 - 1");
        apply_and_check(8'h80, 8'h01, 1'b0, ALU_SUB, "SUB", 8'h7F, 1'b1, 1'b0, 1'b0, "SUB: -128 - 1");

        // 4. Test AND operations
        apply_and_check(8'h55, 8'hAA, 1'b0, ALU_AND, "AND", 8'h00, 1'b0, 1'b1, 1'b0, "AND: 55 & AA");
        apply_and_check(8'hCD, 8'hFF, 1'b0, ALU_AND, "AND", 8'hCD, 1'b0, 1'b0, 1'b1, "AND: CD & FF");
        apply_and_check(8'hCD, 8'h0F, 1'b0, ALU_AND, "AND", 8'h0D, 1'b0, 1'b0, 1'b0, "AND: CD & 0F");
        apply_and_check(8'hF0, 8'h0F, 1'b0, ALU_AND, "AND", 8'h00, 1'b0, 1'b1, 1'b0, "AND: F0 & 0F");

        // 5. Test OR operations
        apply_and_check(8'h55, 8'hAA, 1'b0, ALU_OR,  "OR",  8'hFF, 1'b0, 1'b0, 1'b1, "OR: 55 | AA");
        apply_and_check(8'hCD, 8'h00, 1'b0, ALU_OR,  "OR",  8'hCD, 1'b0, 1'b0, 1'b1, "OR: CD | 00");
        apply_and_check(8'h0F, 8'h00, 1'b0, ALU_OR,  "OR",  8'h0F, 1'b0, 1'b0, 1'b0, "OR: 0F | 00");
        apply_and_check(8'hF0, 8'h0F, 1'b0, ALU_OR,  "OR",  8'hFF, 1'b0, 1'b0, 1'b1, "OR: F0 | 0F");

        // 6. Test INR operations
        apply_and_check(8'h00, 8'hxx, 1'b0, ALU_INR,  "INR",  8'h01, 1'b0, 1'b0, 1'b0, "INR: 00"); 
        apply_and_check(8'h0F, 8'hxx, 1'b0, ALU_INR,  "INR",  8'h10, 1'b0, 1'b0, 1'b0, "INR: 0F"); 
        apply_and_check(8'hF0, 8'hxx, 1'b0, ALU_INR,  "INR",  8'hF1, 1'b0, 1'b0, 1'b1, "INR: F0"); 
        apply_and_check(8'hFF, 8'hxx, 1'b0, ALU_INR,  "INR",  8'h00, 1'b1, 1'b1, 1'b0, "INR: FF"); 

         // 6. Test DCR operations
         // Subtraction implies *opposite* Carry flag expected output; i.e. C = 1 implies no borrow, C = 0 implies borrow
        apply_and_check(8'h00, 8'hxx, 1'b0, ALU_DCR,  "DCR",  8'hFF, 1'b0, 1'b0, 1'b1, "DCR: 00"); 
        apply_and_check(8'h0F, 8'hxx, 1'b0, ALU_DCR,  "DCR",  8'h0E, 1'b1, 1'b0, 1'b0, "DCR: 0F"); 
        apply_and_check(8'hF0, 8'hxx, 1'b0, ALU_DCR,  "DCR",  8'hEF, 1'b1, 1'b0, 1'b1, "DCR: F0"); 
        apply_and_check(8'hFF, 8'hxx, 1'b0, ALU_DCR,  "DCR",  8'hFE, 1'b1, 1'b0, 1'b1, "DCR: FF"); 

        // 7. Test ADC operations
        apply_and_check(8'h01, 8'h01, 1'b1, ALU_ADC,  "ADC",  8'h03, 1'b0, 1'b0, 1'b0, "ADC: 01 / 01 / 01");
        apply_and_check(8'h01, 8'h01, 1'b0, ALU_ADC,  "ADC",  8'h02, 1'b0, 1'b0, 1'b0, "ADC: 01 / 01 / 00");
        apply_and_check(8'h00, 8'h00, 1'b1, ALU_ADC,  "ADC",  8'h01, 1'b0, 1'b0, 1'b0, "ADC: 00 / 00 / 01"); 
        apply_and_check(8'hFF, 8'h01, 1'b1, ALU_ADC,  "ADC",  8'h01, 1'b1, 1'b0, 1'b0, "ADC: FF / 01 / 01"); 
        apply_and_check(8'h0F, 8'h0F, 1'b1, ALU_ADC,  "ADC",  8'h1F, 1'b0, 1'b0, 1'b0, "ADC: 0F / 0F / 1");  


        // FLAGS: C / Z / N

        // End simulation
        $display("--- ALU Testbench Complete ---");
        @(posedge clk); // Allow last checks to print fully
        $finish;
    end

endmodule