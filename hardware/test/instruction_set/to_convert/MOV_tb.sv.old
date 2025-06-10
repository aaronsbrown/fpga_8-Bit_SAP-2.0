`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/fixtures_manual/op_MOV_xx_prog.hex";

  reg clk;
  reg reset;
  
  
  computer uut (
        .clk(clk),
        .reset(reset),
    );

  // --- Clock Generation: 10 ns period ---
  initial begin clk = 0;  forever #5 clk = ~clk; end

  // --- Testbench Stimulus ---
  initial begin

    // Setup waveform dumping
    $dumpfile("waveform.vcd");
    $dumpvars(0, computer_tb); // Dump all signals in this module and below

    // Init ram/rom to 00 
    uut.u_ram.init_sim_ram();
    uut.u_rom.init_sim_rom();

    // load the hex file into RAM
    $display("--- Loading hex file: %s ---", HEX_FILE);
    safe_readmemh_rom(HEX_FILE);  
    uut.u_rom.dump(); 

    // Apply reset and wait for it to release
    reset_and_wait(0); 

    // --- Execute the instruction ---
    $display("\n\nRunning MOV_AB instruction test");

    // LDI A
    $display("LDI_A ======");
    $display("BYTE 1");
    repeat (1 + 4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.opcode, LDI_A, "CHK_MORE_BYTES: cpu.opcode == LDI_A"); 

    $display("BYTE 2");
    repeat (4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.temp_1_out, 16'hAA, "CHK_MORE_BYTES: cpu.temp_1_out = xAA"); 

    $display("POST_EXECUTION");
    repeat (1 + 1) @(posedge clk);  #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "Register A", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "cpu.flag_zero_o == 0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "cpu.flag_negative_o == 1"); 

    // LDI B
    $display("LDI_B ======");
    $display("BYTE 1");
    repeat (1 + 4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.opcode, LDI_B, "CHK_MORE_BYTES: cpu.opcode == LDI_B"); 

    $display("BYTE 2");
    repeat (4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.temp_1_out, 16'h00, "CHK_MORE_BYTES: cpu.temp_1_out = x00"); 

    $display("POST_EXECUTION");
    repeat (1 + 1) @(posedge clk);  #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h00, "Register B", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "cpu.flag_zero_o == 1"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "cpu.flag_negative_o == 0");   
  
    // LDI C
    $display("LDI_C ======");
    $display("BYTE 1");
    repeat (1 + 4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.opcode, LDI_C, "CHK_MORE_BYTES: cpu.opcode == LDI_C"); 

    $display("BYTE 2");
    repeat (4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.temp_1_out, 16'h00, "CHK_MORE_BYTES: cpu.temp_1_out = x00"); 

    $display("POST_EXECUTION");
    repeat (1 + 1) @(posedge clk);  #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h00, "Register B", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "cpu.flag_zero_o == 1"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "cpu.flag_negative_o == 0");  

    // MOV_AB
    $display("MOV_AB ======");
    $display("BYTE 1");
    repeat (4 - 1) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.opcode, MOV_AB, "CHK_MORE_BYTES: cpu.opcode == MOV_AB"); 

    $display("POST_EXECUTION");
    repeat (1) @(posedge clk);  #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hAA, "Register B", DATA_WIDTH);
    
    // MOV_AC
    $display("MOV_AC ======");
    $display("BYTE 1");
    repeat (4 - 1) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.opcode, MOV_AC, "CHK_MORE_BYTES: cpu.opcode == MOV_AC"); 

    $display("POST_EXECUTION");
    repeat (1) @(posedge clk);  #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hAA, "Register C", DATA_WIDTH);
  
    // LDI B
    $display("LDI_B ======");
    $display("BYTE 1");
    repeat (1 + 4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.opcode, LDI_B, "CHK_MORE_BYTES: cpu.opcode == LDI_B"); 

    $display("BYTE 2");
    repeat (4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.temp_1_out, 16'hBB, "CHK_MORE_BYTES: cpu.temp_1_out = xBB"); 

    $display("POST_EXECUTION");
    repeat (1 + 1) @(posedge clk);  #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hBB, "Register B", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "cpu.flag_zero_o == 0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "cpu.flag_negative_o == 1");   
    
    // MOV_BA
    $display("MOV_BA ======");
    $display("BYTE 1");
    repeat (4 - 1) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.opcode, MOV_BA, "CHK_MORE_BYTES: cpu.opcode == MOV_BA"); 

    $display("POST_EXECUTION");
    repeat (1) @(posedge clk);  #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hBB, "Register A", DATA_WIDTH);

    // MOV_BC
    $display("MOV_BC ======");
    $display("BYTE 1");
    repeat (4 - 1) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.opcode, MOV_BC, "CHK_MORE_BYTES: cpu.opcode == MOV_BC"); 

    $display("POST_EXECUTION");
    repeat (1) @(posedge clk);  #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hBB, "Register C", DATA_WIDTH);

    // LDI C
    $display("LDI_C ======");
    $display("BYTE 1");
    repeat (1 + 4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.opcode, LDI_C, "CHK_MORE_BYTES: cpu.opcode == LDI_C"); 

    $display("BYTE 2");
    repeat (4) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.temp_1_out, 16'hCC, "CHK_MORE_BYTES: cpu.temp_1_out = xCC"); 

    $display("POST_EXECUTION");
    repeat (1 + 1) @(posedge clk);  #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hCC, "Register C", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "cpu.flag_zero_o == 0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "cpu.flag_negative_o == 1"); 

    // MOV_CA
    $display("MOV_CA ======");
    $display("BYTE 1");
    repeat (4 - 1) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.opcode, MOV_CA, "CHK_MORE_BYTES: cpu.opcode == MOV_CA"); 

    $display("POST_EXECUTION");
    repeat (1) @(posedge clk);  #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hCC, "Register A", DATA_WIDTH);

    // MOV_CB
    $display("MOV_CB ======");
    $display("BYTE 1");
    repeat (4 - 1) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.opcode, MOV_CB, "CHK_MORE_BYTES: cpu.opcode == MOV_CB"); 

    $display("POST_EXECUTION");
    repeat (1) @(posedge clk);  #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hCC, "Register B", DATA_WIDTH);

    // HALT
    repeat (3) @(posedge clk); #0.1; 
    pretty_print_assert_vec(uut.u_cpu.u_control_unit.opcode, HLT, "HALT: cpu.opcode == HLT"); 
    pretty_print_assert_vec(uut.u_cpu.counter_out, 16'hF011, "HALT: cpu.counter_out == xF011"); 

    $display("MOV_XX test finished.===========================\n\n");
    $finish;
  end

endmodule