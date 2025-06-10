`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/MOV/ROM.hex";

  logic                  clk;
  logic                  reset;
  logic [DATA_WIDTH-1:0] computer_output;
  
  // Flag state storage for preservation tests
  logic saved_carry, saved_negative, saved_zero;

  computer uut (
        .clk(clk),
        .reset(reset),
        .output_port_1(computer_output),
        .uart_rx(1'b1),     // UART not used in this test - tie high
        .uart_tx()          // UART not used in this test - leave open
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

    // load the hex files into RAM
    $display("--- Loading hex file: %s ---", HEX_FILE);
    safe_readmemh_rom(HEX_FILE); 

    // Print ROM content     
    uut.u_rom.dump(); 

    // Apply reset and wait for it to release
    reset_and_wait(0); 

    // ============================ BEGIN TEST ==============================
    $display("\n\nRunning MOV instruction test ========================");

    // ==================== TEST SECTION 1: Basic MOV Operations ====================
    $display("\n=== TEST SECTION 1: Basic MOV Operations ===");
    
    // Initialize registers: A=0xAA, B=0x55, C=0xFF
    $display("\n--- Initializing registers with distinct values ---");
    
    // LDI A, $AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "Register A after LDI A,$AA", DATA_WIDTH);
    
    // LDI B, $55  
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h55, "Register B after LDI B,$55", DATA_WIDTH);
    
    // LDI C, $FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hFF, "Register C after LDI C,$FF", DATA_WIDTH);
    
    $display("\n--- Testing MOV A,B: B should become 0xAA ---");
    // MOV A,B (B = A = 0xAA)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hAA, "Register B after MOV A,B ($AA -> B)", DATA_WIDTH);
    inspect_register(uut.u_cpu.a_out, 8'hAA, "Register A unchanged after MOV A,B", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hFF, "Register C preserved after MOV A,B", DATA_WIDTH);
    
    $display("\n--- Testing MOV A,C: C should become 0xAA ---");
    // MOV A,C (C = A = 0xAA)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hAA, "Register C after MOV A,C ($AA -> C)", DATA_WIDTH);
    inspect_register(uut.u_cpu.a_out, 8'hAA, "Register A unchanged after MOV A,C", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hAA, "Register B preserved after MOV A,C", DATA_WIDTH);
    
    // LDI C, $33 (reload C for next test)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h33, "Register C after LDI C,$33", DATA_WIDTH);
    
    $display("\n--- Testing MOV B,A: A should become 0xAA ---");
    // MOV B,A (A = B = 0xAA)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "Register A after MOV B,A ($AA -> A)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hAA, "Register B unchanged after MOV B,A", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h33, "Register C preserved after MOV B,A", DATA_WIDTH);
    
    $display("\n--- Testing MOV B,C: C should become 0xAA ---");
    // MOV B,C (C = B = 0xAA)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hAA, "Register C after MOV B,C ($AA -> C)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hAA, "Register B unchanged after MOV B,C", DATA_WIDTH);
    inspect_register(uut.u_cpu.a_out, 8'hAA, "Register A preserved after MOV B,C", DATA_WIDTH);
    
    // LDI B, $77 (reload B for next test)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h77, "Register B after LDI B,$77", DATA_WIDTH);
    
    $display("\n--- Testing MOV C,A: A should become 0xAA ---");
    // MOV C,A (A = C = 0xAA)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "Register A after MOV C,A ($AA -> A)", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hAA, "Register C unchanged after MOV C,A", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h77, "Register B preserved after MOV C,A", DATA_WIDTH);
    
    $display("\n--- Testing MOV C,B: B should become 0xAA ---");
    // MOV C,B (B = C = 0xAA)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hAA, "Register B after MOV C,B ($AA -> B)", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hAA, "Register C unchanged after MOV C,B", DATA_WIDTH);
    inspect_register(uut.u_cpu.a_out, 8'hAA, "Register A preserved after MOV C,B", DATA_WIDTH);

    // ==================== TEST SECTION 2: Edge Case Values ====================
    $display("\n=== TEST SECTION 2: Edge Case Values ===");
    
    $display("\n--- Testing zero value transfer (0x00) ---");
    // LDI A, $00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "Register A after LDI A,$00", DATA_WIDTH);
    
    // LDI B, $FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hFF, "Register B after LDI B,$FF", DATA_WIDTH);
    
    // MOV A,B (B = A = 0x00)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h00, "Register B after MOV A,B (zero transfer: $00 -> B)", DATA_WIDTH);
    
    $display("\n--- Testing all-ones value transfer (0xFF) ---");
    // LDI A, $FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "Register A after LDI A,$FF", DATA_WIDTH);
    
    // LDI C, $00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h00, "Register C after LDI C,$00", DATA_WIDTH);
    
    // MOV A,C (C = A = 0xFF)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hFF, "Register C after MOV A,C (all-ones transfer: $FF -> C)", DATA_WIDTH);
    
    $display("\n--- Testing sign bit value transfer (0x80) ---");
    // LDI A, $80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "Register A after LDI A,$80", DATA_WIDTH);
    
    // LDI B, $00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h00, "Register B after LDI B,$00", DATA_WIDTH);
    
    // MOV A,B (B = A = 0x80)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h80, "Register B after MOV A,B (sign bit transfer: $80 -> B)", DATA_WIDTH);
    
    $display("\n--- Testing max positive value transfer (0x7F) ---");
    // LDI A, $7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "Register A after LDI A,$7F", DATA_WIDTH);
    
    // LDI C, $00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h00, "Register C after LDI C,$00", DATA_WIDTH);
    
    // MOV A,C (C = A = 0x7F)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h7F, "Register C after MOV A,C (max positive transfer: $7F -> C)", DATA_WIDTH);
    
    $display("\n--- Testing single bit value transfer (0x01) ---");
    // LDI A, $01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "Register A after LDI A,$01", DATA_WIDTH);
    
    // LDI B, $FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hFF, "Register B after LDI B,$FF", DATA_WIDTH);
    
    // MOV A,B (B = A = 0x01)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h01, "Register B after MOV A,B (single bit transfer: $01 -> B)", DATA_WIDTH);

    // ==================== TEST SECTION 3: Bit Pattern Variations ====================
    $display("\n=== TEST SECTION 3: Bit Pattern Variations ===");
    
    $display("\n--- Testing alternating bit patterns ---");
    // LDI A, $AA (10101010)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "Register A after LDI A,$AA (10101010)", DATA_WIDTH);
    
    // LDI B, $55 (01010101)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h55, "Register B after LDI B,$55 (01010101)", DATA_WIDTH);
    
    // MOV A,B (B = A = 0xAA)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hAA, "Register B after MOV A,B ($AA -> B, alternating pattern)", DATA_WIDTH);
    
    // MOV B,A (A = B = 0xAA) - round trip test
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hAA, "Register A after MOV B,A (round trip: $AA -> A)", DATA_WIDTH);
    
    $display("\n--- Testing nibble patterns ---");
    // LDI A, $0F (00001111 - low nibble set)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h0F, "Register A after LDI A,$0F (00001111)", DATA_WIDTH);
    
    // LDI C, $F0 (11110000 - high nibble set)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hF0, "Register C after LDI C,$F0 (11110000)", DATA_WIDTH);
    
    // MOV A,C (C = A = 0x0F)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h0F, "Register C after MOV A,C ($0F -> C, low nibble pattern)", DATA_WIDTH);
    
    // MOV C,A (A = C = 0x0F) - round trip test
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h0F, "Register A after MOV C,A (round trip: $0F -> A)", DATA_WIDTH);
    
    $display("\n--- Testing single bit edge patterns ---");
    // LDI A, $01 (00000001 - bit 0 set)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "Register A after LDI A,$01 (00000001)", DATA_WIDTH);
    
    // LDI B, $80 (10000000 - bit 7 set)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h80, "Register B after LDI B,$80 (10000000)", DATA_WIDTH);
    
    // MOV A,B (B = A = 0x01)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h01, "Register B after MOV A,B ($01 -> B, LSB transfer)", DATA_WIDTH);
    
    // MOV B,A (A = B = 0x01) - round trip test
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "Register A after MOV B,A (round trip: $01 -> A)", DATA_WIDTH);

    // ==================== TEST SECTION 4: Flag Preservation Tests ====================
    $display("\n=== TEST SECTION 4: Flag Preservation Tests ===");
    
    $display("\n--- Testing flag preservation with carry set ---");
    // SEC (Set carry flag)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "Carry flag set after SEC");
    
    // LDI A, $80 (Load negative value to set N flag, clear Z flag)
    // After this: A=0x80. Flags become: N=1, Z=0 (C is preserved from SEC, so C=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "Register A after LDI A,$80", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "Negative flag set after LDI A,$80");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "Zero flag clear after LDI A,$80");
        
    // LDI B, $7F (Positive value)
    // After this: B=0x7F. Flags become: N=0, Z=0 (C is preserved, so C=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h7F, "Register B after LDI B,$7F", DATA_WIDTH);
    
    // Store current flag state for comparison (Flags are C=1, N=0, Z=0 at this point)
    saved_carry = uut.u_cpu.flag_carry_o;
    saved_negative = uut.u_cpu.flag_negative_o;
    saved_zero = uut.u_cpu.flag_zero_o;
    
    // MOV B,A (A_old=0x80, B_curr=0x7F => A_new=0x7F)
    // Flags should NOT change from MOV. So they should remain C=1, N=0, Z=0.
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h7F, "Register A after MOV B,A ($7F -> A)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, saved_carry, "Carry flag preserved after MOV B,A");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, saved_negative, "Negative flag preserved after MOV B,A");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, saved_zero, "Zero flag preserved after MOV B,A");
    
    $display("\n--- Testing flag preservation with different flag state ---");
    // CLC (Clear carry flag)
    // After this: Flags become C=0 (N, Z preserved from previous state: N=0, Z=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "Carry flag clear after CLC");
    
    // LDI A, $00 (Load zero to set Z flag, clear N flag)
    // After this: A=0x00. Flags become: N=0, Z=1 (C is preserved, so C=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "Register A after LDI A,$00", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "Zero flag set after LDI A,$00");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "Negative flag clear after LDI A,$00");
        
    // LDI C, $FF (Negative value)
    // After this: C_reg=0xFF. Flags become: N=1, Z=0 (C is preserved, so C=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hFF, "Register C after LDI C,$FF", DATA_WIDTH);

    // Store current flag state for comparison (Flags are C=0, N=1, Z=0 at this point)
    saved_carry = uut.u_cpu.flag_carry_o;
    saved_negative = uut.u_cpu.flag_negative_o;
    saved_zero = uut.u_cpu.flag_zero_o;
    
    // MOV C,A (A_old=0x00, C_curr=0xFF => A_new=0xFF)
    // Flags should NOT change from MOV. So they should remain C=0, N=1, Z=0.
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "Register A after MOV C,A ($FF -> A)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, saved_carry, "Carry flag preserved after MOV C,A");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, saved_negative, "Negative flag preserved after MOV C,A");
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, saved_zero, "Zero flag preserved after MOV C,A");

    // ==================== TEST SECTION 5: Register Preservation Tests ====================
    $display("\n=== TEST SECTION 5: Register Preservation Tests ===");
    
    $display("\n--- Testing uninvolved register preservation ---");
    // LDI A, $11; LDI B, $22; LDI C, $33
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h11, "Register A after LDI A,$11", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h22, "Register B after LDI B,$22", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h33, "Register C after LDI C,$33", DATA_WIDTH);
    
    // MOV A,B (B = A = 0x11) - C should remain 0x33
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h11, "Register B after MOV A,B ($11 -> B)", DATA_WIDTH);
    inspect_register(uut.u_cpu.a_out, 8'h11, "Register A unchanged after MOV A,B", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h33, "Register C preserved during MOV A,B", DATA_WIDTH);
    
    // MOV A,C (C = A = 0x11) - B should remain 0x11
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h11, "Register C after MOV A,C ($11 -> C)", DATA_WIDTH);
    inspect_register(uut.u_cpu.a_out, 8'h11, "Register A unchanged after MOV A,C", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h11, "Register B preserved during MOV A,C", DATA_WIDTH);
    
    // MOV B,C (C = B = 0x11) - A should remain 0x11
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h11, "Register C after MOV B,C ($11 -> C)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h11, "Register B unchanged after MOV B,C", DATA_WIDTH);
    inspect_register(uut.u_cpu.a_out, 8'h11, "Register A preserved during MOV B,C", DATA_WIDTH);

    // ==================== TEST SECTION 6: Chained MOV Operations ====================
    $display("\n=== TEST SECTION 6: Chained MOV Operations ===");
    
    $display("\n--- Testing circular transfer: A -> B -> C -> A ---");
    // LDI A, $A1; LDI B, $B2; LDI C, $C3
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hA1, "Register A after LDI A,$A1", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hB2, "Register B after LDI B,$B2", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hC3, "Register C after LDI C,$C3", DATA_WIDTH);
    
    // MOV A,B (B = A = 0xA1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hA1, "Register B after MOV A,B ($A1 -> B)", DATA_WIDTH);
    inspect_register(uut.u_cpu.a_out, 8'hA1, "Register A unchanged", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hC3, "Register C unchanged", DATA_WIDTH);
    
    // MOV B,C (C = B = 0xA1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hA1, "Register C after MOV B,C ($A1 -> C)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hA1, "Register B unchanged", DATA_WIDTH);
    inspect_register(uut.u_cpu.a_out, 8'hA1, "Register A unchanged", DATA_WIDTH);
    
    // MOV C,A (A = C = 0xA1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hA1, "Register A after MOV C,A ($A1 -> A)", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hA1, "Register C unchanged", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'hA1, "Register B unchanged", DATA_WIDTH);
    $display("Circular transfer complete: All registers now contain $A1");
    
    $display("\n--- Testing reverse chain: C -> B -> A ---");
    // LDI A, $1A; LDI B, $2B; LDI C, $3C
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h1A, "Register A after LDI A,$1A", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h2B, "Register B after LDI B,$2B", DATA_WIDTH);
    
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h3C, "Register C after LDI C,$3C", DATA_WIDTH);
    
    // MOV C,B (B = C = 0x3C)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h3C, "Register B after MOV C,B ($3C -> B)", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h3C, "Register C unchanged", DATA_WIDTH);
    inspect_register(uut.u_cpu.a_out, 8'h1A, "Register A unchanged", DATA_WIDTH);
    
    // MOV B,A (A = B = 0x3C)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h3C, "Register A after MOV B,A ($3C -> A)", DATA_WIDTH);
    inspect_register(uut.u_cpu.b_out, 8'h3C, "Register B unchanged", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h3C, "Register C unchanged", DATA_WIDTH);
    $display("Reverse chain complete: All registers now contain $3C");

    // ==================== END OF TESTS ====================
    $display("\n=== Waiting for HALT ===");
    run_until_halt(50);  // Increased timeout for comprehensive test suite
    
    // Visual buffer for waveform inspection
    repeat(5) @(posedge clk);

    $display("MOV test finished.===========================\n\n");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule