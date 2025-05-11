`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE_PROG = "../hardware/test/fixtures_manual/op_LDA_prog.hex";
  localparam string HEX_FILE_DATA = "../hardware/test/fixtures_manual/op_LDA_data.hex";

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
    $display("--- Loading hex file: %s ---", HEX_FILE_PROG);
    $readmemh(HEX_FILE_PROG, uut.u_rom.mem); 
    uut.u_rom.dump(); 

    // load the hex file into RAM
    $display("--- Loading hex file: %s ---", HEX_FILE_DATA);
    $readmemh(HEX_FILE_DATA, uut.u_ram.mem); 
    uut.u_ram.dump(); 

    // Apply reset and wait for it to release
    reset_and_wait(0); 

    // --- Execute the instruction ---
    $display("\n\nRunning LDI_A instruction test");

    // BYTE 1 =================================
    // ========================================
    $display("INIT");
    
    // Cycle 1: INIT
    repeat (1) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.load_origin, 1'b1, "INIT: cpu.load_origin");


    // BYTE 1 =================================
    // ========================================
    $display("BYTE 1");
    
    // Cycle 2: LATCH_ADDRESS
    repeat (1) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.counter_out, 16'hF000, "LATCH_ADDRESS: cpu.counter_out == xF000");
    pretty_print_assert_vec(uut.u_cpu.load_mar_pc, 1'b1, "LATCH_ADDRESS: cpu.load_mar_pc");

    // Cycle 3: READ_BYTE
    repeat (1) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.cpu_mem_read, 1'b1, "READ_BYTE: computer.cpu_mem_read");
    pretty_print_assert_vec(uut.cpu_mem_address, 16'hF000, "READ_BYTE: Read first byte @ F000"); 
    
    // Cycle 4: LATCH_BYTE
    repeat (1) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.oe_ram, 1'b1, "LATCH_BYTE: cpu.oe_ram");
    pretty_print_assert_vec(uut.u_cpu.load_ir, 1'b1, "LATCH_BYTE: cpu.load_ir"); 
    pretty_print_assert_vec(uut.u_cpu.pc_enable, 1'b1, "LATCH_BYTE: cpu.pc_enable");

    // Cycle 5: CHK_MORE_BYTES
    repeat (1) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.opcode, LDA, "CHK_MORE_BYTES: cpu.opcode == LDA"); 


    // BYTE 2 =================================
    // ========================================
    $display("BYTE 2");

    // Cycle 2: LATCH_ADDRESS
    repeat (1) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.counter_out, 16'hF001, "LATCH_ADDRESS: cpu.counter_out == xF001");
    pretty_print_assert_vec(uut.u_cpu.load_mar_pc, 1'b1, "LATCH_ADDRESS: cpu.load_mar_pc");

    // Cycle 3: READ_BYTE
    repeat (1) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.cpu_mem_read, 1'b1, "READ_BYTE: computer.cpu_mem_read");
    pretty_print_assert_vec(uut.cpu_mem_address, 16'hF001, "READ_BYTE: Read second byte @ F001");

    // Cycle 4: LATCH_BYTE
    repeat (1) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.oe_ram, 1'b1, "LATCH_BYTE: cpu.oe_ram");
    pretty_print_assert_vec(uut.u_cpu.load_temp_1, 1'b1, "LATCH_BYTE: cpu.load_temp_1"); 
    pretty_print_assert_vec(uut.u_cpu.pc_enable, 1'b1, "LATCH_BYTE: cpu.pc_enable");

    // Cycle 5: CHK_MORE_BYTES
    repeat (1) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.temp_1_out, 16'h34, "CHK_MORE_BYTES: cpu.temp_1_out = x34"); 

    // BYTE 3 =================================
    // ========================================
    $display("BYTE 3");

    // Cycle 2: LATCH_ADDRESS
    repeat (1) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.counter_out, 16'hF002, "LATCH_ADDRESS: cpu.counter_out == xF002");
    pretty_print_assert_vec(uut.u_cpu.load_mar_pc, 1'b1, "LATCH_ADDRESS: cpu.load_mar_pc");

    // Cycle 3: READ_BYTE
    repeat (1) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.cpu_mem_read, 1'b1, "READ_BYTE: computer.cpu_mem_read");
    pretty_print_assert_vec(uut.cpu_mem_address, 16'hF002, "READ_BYTE: Read second byte @ F002");

    // Cycle 4: LATCH_BYTE
    repeat (1) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.oe_ram, 1'b1, "LATCH_BYTE: cpu.oe_ram");
    pretty_print_assert_vec(uut.u_cpu.load_temp_2, 1'b1, "LATCH_BYTE: cpu.load_temp_2"); 
    pretty_print_assert_vec(uut.u_cpu.pc_enable, 1'b1, "LATCH_BYTE: cpu.pc_enable");

    // Cycle 5: CHK_MORE_BYTES
    repeat (1) @(posedge clk);  #0.1;
    pretty_print_assert_vec(uut.u_cpu.temp_2_out, 16'h12, "CHK_MORE_BYTES: cpu.temp_2_out = x12"); 

  // EXECUTE ====================================
  // ============================================ 
    $display("INSTRUCTION EXECUTION");

    // MS0
    repeat (1) @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.u_control_unit.current_microstep, MS0, "EXECUTE: MS0"); 
    pretty_print_assert_vec(uut.u_cpu.oe_temp_1, 1'b1, "MS0: cpu.oe_temp_1");
    
    // MS1
    repeat (1) @(posedge clk); #0.1; 
    pretty_print_assert_vec(uut.u_cpu.u_control_unit.current_microstep, MS1, "EXECUTE: MS1"); 
    pretty_print_assert_vec(uut.u_cpu.oe_temp_1, 1'b1, "MS1: cpu.oe_temp_1");
    pretty_print_assert_vec(uut.u_cpu.load_mar_addr_low, 1'b1, "MS1: cpu.load_mar_addr_low");
    
    // MS2
    repeat (1) @(posedge clk); #0.1; 
    pretty_print_assert_vec(uut.u_cpu.mar_out[7:0], 8'h34, "MS2: MAR Low"); 
    pretty_print_assert_vec(uut.u_cpu.u_control_unit.current_microstep, MS2, "EXECUTE: MS2"); 
    pretty_print_assert_vec(uut.u_cpu.oe_temp_2, 1'b1, "MS2: cpu.oe_temp_2"); 

    // MS3
    repeat (1) @(posedge clk); #0.1; 
    pretty_print_assert_vec(uut.u_cpu.u_control_unit.current_microstep, MS3, "EXECUTE: MS3"); 
    pretty_print_assert_vec(uut.u_cpu.oe_temp_2, 1'b1, "MS3: cpu.oe_temp_2"); 
    pretty_print_assert_vec(uut.u_cpu.load_mar_addr_high, 1'b1, "MS3: cpu.load_mar_addr_high");
    
    // MS4
    repeat (1) @(posedge clk); #0.1; 
    pretty_print_assert_vec(uut.u_cpu.mar_out[15:8], 8'h12, "MS3: MAR High"); 
    pretty_print_assert_vec(uut.u_cpu.u_control_unit.current_microstep, MS4, "EXECUTE: MS4"); 
    pretty_print_assert_vec(uut.u_cpu.oe_ram, 1'b1, "MS4: cpu.oe_ram");
    pretty_print_assert_vec(uut.cpu_mem_address, 16'hF1234, "READ_BYTE: Read data @ F1234"); 
     

    // MS5
    repeat (1) @(posedge clk); #0.1; 
    pretty_print_assert_vec(uut.u_cpu.u_control_unit.current_microstep, MS5, "EXECUTE: MS5"); 
    pretty_print_assert_vec(uut.u_cpu.oe_ram, 1'b1, "MS5: cpu.oe_ram"); 
    pretty_print_assert_vec(uut.u_cpu.load_a, 1'b1, "MS5: cpu.load_a");  
    pretty_print_assert_vec(uut.u_cpu.load_flags, 1'b1, "MS5: cpu.load_flags");  
    pretty_print_assert_vec(uut.u_cpu.load_sets_zn, 1'b1, "MS5: cpu.load_sets_zn");  


   
  // LAST STEP & HALT ========================
  // ========================================
    $display("POST_EXECUTION");

    // LATCH_ADDR
    repeat (1) @(posedge clk);  #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h55, "Register A", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "cpu.flag_zero_o == 0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "cpu.flag_negative_o == 0");  
  
    // READ_BYTE
    repeat (1) @(posedge clk);  #0.1;

    // LATCH_BYTE
    repeat (1) @(posedge clk);  #0.1;

    // CHK_MORE_BYTES
    repeat (1) @(posedge clk);  #0.1; 
    
    // EXECUTE
    repeat (1) @(posedge clk); #0.1; 

    // HALT
    pretty_print_assert_vec(uut.u_cpu.u_control_unit.opcode, HLT, "HALT: cpu.opcode == HLT"); 
    pretty_print_assert_vec(uut.u_cpu.counter_out, 16'hF004, "HALT: cpu.counter_out == xF004"); 

    $display("LDA instruction finished.\n\n");
    $finish;
  end

endmodule