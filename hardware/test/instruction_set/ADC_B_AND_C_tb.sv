`timescale 1ns/1ps
import test_utils_pkg::*; 
import arch_defs_pkg::*;  

module computer_tb;

  localparam string HEX_FILE = "../hardware/test/_fixtures_generated/ADC_B_AND_C/ROM.hex";

  logic                  clk;
  logic                  reset;
  logic [DATA_WIDTH-1:0] computer_output;

  computer uut (
        .clk(clk),
        .reset(reset),
        .output_port_1(computer_output),
        .uart_rx(1'b1),    // UART not needed for ADC microinstruction testing
        .uart_tx()         // Leave unconnected - not needed for this test
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

    // load the hex files into ROM
    $display("--- Loading hex file: %s ---", HEX_FILE);
    safe_readmemh_rom(HEX_FILE); 

    // Print ROM content     
    uut.u_rom.dump(); 

    // Apply reset and wait for it to release
    reset_and_wait(0); 

    // ============================ BEGIN TEST ==============================
    $display("\n\nRunning ADC_B and ADC_C Enhanced Test ========================");

    // ======================================================================
    // Test Group 1: ADC_B Basic Operations
    // ======================================================================
    $display("\n--- Test Group 1: ADC_B Basic Operations ---");
    
    // TEST 1: ADC_B with carry clear (C=0, no additional addition)
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: C=0 (cleared for no extra addition)"); 

    // LDI A, #$10
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h10, "A=$10 (16)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "LDI A: Z=0"); 
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "LDI A: N=0"); 

    // LDI B, #$05
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h05, "B=$05 (5)", DATA_WIDTH);

    // LDI C, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hAA, "C=$AA (preservation test)", DATA_WIDTH);

    // ADC B ($10 + $05 + 0 = $15)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h15, "ADC B: A=$10+$05+0=$15 (C=0 no extra add)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADC B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ADC B: N=0 (bit 7 clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADC B: C=0 (no carry generated)");
    inspect_register(uut.u_cpu.b_out, 8'h05, "ADC B: B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hAA, "ADC B: C register preserved", DATA_WIDTH);

    // TEST 2: ADC_B with carry set (C=1, adds additional 1)
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: C=1 (set for extra +1)"); 

    // LDI A, #$10
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h10, "A=$10 (16)", DATA_WIDTH);

    // LDI B, #$05
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h05, "B=$05 (5)", DATA_WIDTH);

    // ADC B ($10 + $05 + 1 = $16)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h16, "ADC B: A=$10+$05+1=$16 (C=1 extra add)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADC B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ADC B: N=0 (bit 7 clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADC B: C=0 (no carry generated)");
    inspect_register(uut.u_cpu.c_out, 8'hAA, "ADC B: C register preserved", DATA_WIDTH);

    // TEST 3: ADC_B resulting in zero
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: C=0"); 

    // LDI A, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A=$00 (0)", DATA_WIDTH);

    // LDI B, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h00, "B=$00 (0)", DATA_WIDTH);

    // ADC B ($00 + $00 + 0 = $00)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "ADC B: A=$00+$00+0=$00 (zero result)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "ADC B: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ADC B: N=0 (bit 7 clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADC B: C=0 (no carry generated)");

    // TEST 4: ADC_B with carry producing overflow
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: C=0"); 

    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A=$FF (255)", DATA_WIDTH);

    // LDI B, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h01, "B=$01 (1)", DATA_WIDTH);

    // ADC B ($FF + $01 + 0 = $00 with carry)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "ADC B: A=$FF+$01+0=$00 (overflow)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "ADC B: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ADC B: N=0 (bit 7 clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "ADC B: C=1 (carry generated)");

    // TEST 5: ADC_B with carry set causing overflow
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: C=1"); 

    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A=$FF (255)", DATA_WIDTH);

    // LDI B, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h00, "B=$00 (0)", DATA_WIDTH);

    // ADC B ($FF + $00 + 1 = $00 with carry)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "ADC B: A=$FF+$00+1=$00 (carry input overflow)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "ADC B: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ADC B: N=0 (bit 7 clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "ADC B: C=1 (carry generated)");

    // TEST 6: ADC_B producing negative result
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: C=0"); 

    // LDI A, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "A=$80 (128)", DATA_WIDTH);

    // LDI B, #$7F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h7F, "B=$7F (127)", DATA_WIDTH);

    // ADC B ($80 + $7F + 0 = $FF)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "ADC B: A=$80+$7F+0=$FF (negative result)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADC B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "ADC B: N=1 (bit 7 set)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADC B: C=0 (no carry generated)");

    // ======================================================================
    // Test Group 2: ADC_B Bit Pattern Tests
    // ======================================================================
    $display("\n--- Test Group 2: ADC_B Bit Pattern Tests ---");

    // TEST 7: ADC_B with alternating patterns and carry clear
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: C=0"); 

    // LDI A, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h55, "A=$55 (01010101)", DATA_WIDTH);

    // LDI B, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hAA, "B=$AA (10101010)", DATA_WIDTH);

    // ADC B ($55 + $AA + 0 = $FF)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "ADC B: A=$55+$AA+0=$FF (alternating pattern)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADC B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "ADC B: N=1 (bit 7 set)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADC B: C=0 (no carry)");

    // TEST 8: ADC_B with alternating patterns and carry set
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: C=1"); 

    // LDI A, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h55, "A=$55 (01010101)", DATA_WIDTH);

    // LDI B, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hAA, "B=$AA (10101010)", DATA_WIDTH);

    // ADC B ($55 + $AA + 1 = $00 with carry)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "ADC B: A=$55+$AA+1=$00 (overflow with carry)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "ADC B: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ADC B: N=0 (bit 7 clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "ADC B: C=1 (carry generated)");

    // ======================================================================
    // Test Group 3: ADC_C Basic Operations
    // ======================================================================
    $display("\n--- Test Group 3: ADC_C Basic Operations ---");

    // TEST 9: ADC_C with carry clear
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: C=0"); 

    // LDI A, #$20
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h20, "A=$20 (32)", DATA_WIDTH);

    // LDI B, #$BB
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hBB, "B=$BB (preservation test)", DATA_WIDTH);

    // LDI C, #$08
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h08, "C=$08 (8)", DATA_WIDTH);

    // ADC C ($20 + $08 + 0 = $28)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h28, "ADC C: A=$20+$08+0=$28 (C=0 no extra add)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADC C: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ADC C: N=0 (bit 7 clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADC C: C=0 (no carry generated)");
    inspect_register(uut.u_cpu.b_out, 8'hBB, "ADC C: B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h08, "ADC C: C operand preserved", DATA_WIDTH);

    // TEST 10: ADC_C with carry set
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: C=1"); 

    // LDI A, #$20
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h20, "A=$20 (32)", DATA_WIDTH);

    // LDI B, #$BB
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hBB, "B=$BB (preservation test)", DATA_WIDTH);

    // LDI C, #$08
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h08, "C=$08 (8)", DATA_WIDTH);

    // ADC C ($20 + $08 + 1 = $29)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h29, "ADC C: A=$20+$08+1=$29 (C=1 extra add)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADC C: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ADC C: N=0 (bit 7 clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADC C: C=0 (no carry generated)");
    inspect_register(uut.u_cpu.b_out, 8'hBB, "ADC C: B preserved", DATA_WIDTH);

    // TEST 11: ADC_C resulting in zero
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: C=0"); 

    // LDI A, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "A=$00 (0)", DATA_WIDTH);

    // LDI B, #$BB
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hBB, "B=$BB (preservation test)", DATA_WIDTH);

    // LDI C, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h00, "C=$00 (0)", DATA_WIDTH);

    // ADC C ($00 + $00 + 0 = $00)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "ADC C: A=$00+$00+0=$00 (zero result)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "ADC C: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ADC C: N=0 (bit 7 clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADC C: C=0 (no carry generated)");

    // ======================================================================
    // Test Group 4: ADC_C Advanced Operations
    // ======================================================================
    $display("\n--- Test Group 4: ADC_C Advanced Operations ---");

    // TEST 12: ADC_C with overflow
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: C=1"); 

    // LDI A, #$FE
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFE, "A=$FE (254)", DATA_WIDTH);

    // LDI B, #$BB
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hBB, "B=$BB (preservation test)", DATA_WIDTH);

    // LDI C, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h01, "C=$01 (1)", DATA_WIDTH);

    // ADC C ($FE + $01 + 1 = $00 with carry)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "ADC C: A=$FE+$01+1=$00 (overflow)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "ADC C: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ADC C: N=0 (bit 7 clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "ADC C: C=1 (carry generated)");

    // TEST 13: ADC_C producing negative result
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: C=0"); 

    // LDI A, #$70
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h70, "A=$70 (112)", DATA_WIDTH);

    // LDI B, #$BB
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hBB, "B=$BB (preservation test)", DATA_WIDTH);

    // LDI C, #$70
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h70, "C=$70 (112)", DATA_WIDTH);

    // ADC C ($70 + $70 + 0 = $E0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hE0, "ADC C: A=$70+$70+0=$E0 (negative result)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADC C: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "ADC C: N=1 (bit 7 set)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADC C: C=0 (no carry generated)");

    // TEST 14: ADC_C with complex bit patterns
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: C=0"); 

    // LDI A, #$B7
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hB7, "A=$B7 (10110111)", DATA_WIDTH);

    // LDI B, #$BB
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hBB, "B=$BB (preservation test)", DATA_WIDTH);

    // LDI C, #$29
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h29, "C=$29 (00101001)", DATA_WIDTH);

    // ADC C ($B7 + $29 + 0 = $E0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hE0, "ADC C: A=$B7+$29+0=$E0 (complex pattern)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADC C: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "ADC C: N=1 (bit 7 set)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADC C: C=0 (no carry generated)");

    // TEST 15: ADC_C with complex bit patterns and carry set
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: C=1"); 

    // LDI A, #$B7
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hB7, "A=$B7 (10110111)", DATA_WIDTH);

    // LDI B, #$BB
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hBB, "B=$BB (preservation test)", DATA_WIDTH);

    // LDI C, #$29
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h29, "C=$29 (00101001)", DATA_WIDTH);

    // ADC C ($B7 + $29 + 1 = $E1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hE1, "ADC C: A=$B7+$29+1=$E1 (with carry)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADC C: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "ADC C: N=1 (bit 7 set)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADC C: C=0 (no carry generated)");

    // ======================================================================
    // Test Group 5: Edge Cases and Boundary Conditions
    // ======================================================================
    $display("\n--- Test Group 5: Edge Cases and Boundary Conditions ---");

    // TEST 16: ADC_B single bit operations
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: C=0"); 

    // LDI A, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "A=$01 (00000001)", DATA_WIDTH);

    // LDI B, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h01, "B=$01 (00000001)", DATA_WIDTH);

    // LDI C, #$CC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hCC, "C=$CC (preservation test)", DATA_WIDTH);

    // ADC B ($01 + $01 + 0 = $02)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h02, "ADC B: A=$01+$01+0=$02 (single bit test)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADC B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ADC B: N=0 (bit 7 clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADC B: C=0 (no carry generated)");
    inspect_register(uut.u_cpu.c_out, 8'hCC, "ADC B: C register preserved", DATA_WIDTH);

    // TEST 17: ADC_C MSB operations with carry propagation
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: C=1"); 

    // LDI A, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h80, "A=$80 (10000000)", DATA_WIDTH);

    // LDI B, #$DD
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hDD, "B=$DD (preservation test)", DATA_WIDTH);

    // LDI C, #$80
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h80, "C=$80 (10000000)", DATA_WIDTH);

    // ADC C ($80 + $80 + 1 = $01 with carry)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h01, "ADC C: A=$80+$80+1=$01 (MSB operations)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADC C: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ADC C: N=0 (bit 7 clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "ADC C: C=1 (carry generated from MSB)");
    inspect_register(uut.u_cpu.b_out, 8'hDD, "ADC C: B preserved", DATA_WIDTH);

    // TEST 18: All ones pattern with ADC_B
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: C=0"); 

    // LDI A, #$FF
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "A=$FF (11111111)", DATA_WIDTH);

    // LDI B, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h00, "B=$00 (00000000)", DATA_WIDTH);

    // LDI C, #$EE
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hEE, "C=$EE (preservation test)", DATA_WIDTH);

    // ADC B ($FF + $00 + 0 = $FF)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "ADC B: A=$FF+$00+0=$FF (all ones test)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADC B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "ADC B: N=1 (bit 7 set)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADC B: C=0 (no carry generated)");
    inspect_register(uut.u_cpu.c_out, 8'hEE, "ADC B: C register preserved", DATA_WIDTH);

    // TEST 19: All ones pattern with ADC_C and carry set
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: C=1"); 

    // LDI A, #$FE
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFE, "A=$FE (11111110)", DATA_WIDTH);

    // LDI B, #$EE
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hEE, "B=$EE (preservation test)", DATA_WIDTH);

    // LDI C, #$00
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h00, "C=$00 (00000000)", DATA_WIDTH);

    // ADC C ($FE + $00 + 1 = $FF)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "ADC C: A=$FE+$00+1=$FF (all ones with carry)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADC C: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "ADC C: N=1 (bit 7 set)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADC C: C=0 (no carry generated)");
    inspect_register(uut.u_cpu.b_out, 8'hEE, "ADC C: B preserved", DATA_WIDTH);

    // ======================================================================
    // Test Group 6: Chain Operations and Register Preservation
    // ======================================================================
    $display("\n--- Test Group 6: Chain Operations and Register Preservation ---");

    // TEST 20: Chain multiple ADC operations
    // CLC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "CLC: C=0 (start chain)"); 

    // LDI A, #$FE
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFE, "A=$FE (254)", DATA_WIDTH);

    // LDI B, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h01, "B=$01 (1)", DATA_WIDTH);

    // LDI C, #$01
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h01, "C=$01 (1)", DATA_WIDTH);

    // ADC B ($FE + $01 + 0 = $FF, sets C=0)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hFF, "ADC B: A=$FE+$01+0=$FF (first in chain)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADC B: C=0 (no carry for next)");

    // ADC C ($FF + $01 + 0 = $00, C=1)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h00, "ADC C: A=$FF+$01+0=$00 (second in chain)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b1, "ADC C: Z=1 (result is zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ADC C: N=0 (bit 7 clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "ADC C: C=1 (carry generated)");
    inspect_register(uut.u_cpu.b_out, 8'h01, "Chain: B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h01, "Chain: C preserved", DATA_WIDTH);

    // TEST 21: Final register preservation verification for ADC_B
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: C=1 (final test)"); 

    // LDI A, #$0F
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h0F, "A=$0F (00001111)", DATA_WIDTH);

    // LDI B, #$AA
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'hAA, "B=$AA (preservation test)", DATA_WIDTH);

    // LDI C, #$F0
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'hF0, "C=$F0 (11110000)", DATA_WIDTH);

    // ADC B ($0F + $AA + 1 = $BA)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'hBA, "ADC B: A=$0F+$AA+1=$BA (final preservation)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADC B: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b1, "ADC B: N=1 (bit 7 set)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADC B: C=0 (no carry generated)");
    inspect_register(uut.u_cpu.b_out, 8'hAA, "Final ADC_B: B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'hF0, "Final ADC_B: C register preserved", DATA_WIDTH);

    // Final register preservation verification for ADC_C
    // SEC
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b1, "SEC: C=1 (final test)"); 

    // LDI A, #$30
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h30, "A=$30 (00110000)", DATA_WIDTH);

    // LDI B, #$55
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.b_out, 8'h55, "B=$55 (preservation test)", DATA_WIDTH);

    // LDI C, #$0C
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.c_out, 8'h0C, "C=$0C (00001100)", DATA_WIDTH);

    // ADC C ($30 + $0C + 1 = $3D)
    wait(uut.cpu_instr_complete); @(posedge clk); #0.1;
    inspect_register(uut.u_cpu.a_out, 8'h3D, "ADC C: A=$30+$0C+1=$3D (final preservation)", DATA_WIDTH);
    pretty_print_assert_vec(uut.u_cpu.flag_zero_o, 1'b0, "ADC C: Z=0 (result non-zero)");
    pretty_print_assert_vec(uut.u_cpu.flag_negative_o, 1'b0, "ADC C: N=0 (bit 7 clear)");
    pretty_print_assert_vec(uut.u_cpu.flag_carry_o, 1'b0, "ADC C: C=0 (no carry generated)");
    inspect_register(uut.u_cpu.b_out, 8'h55, "Final ADC_C: B preserved", DATA_WIDTH);
    inspect_register(uut.u_cpu.c_out, 8'h0C, "Final ADC_C: C operand preserved", DATA_WIDTH);

    // Wait for HLT
    wait(uut.cpu_halt);
    $display("CPU halted - test program completed");
    
    // Visual buffer for waveform inspection
    repeat(10) @(posedge clk);

    $display("\n=== ADC_B and ADC_C Enhanced Test Summary ===");
    $display("✓ ADC_B basic operations with carry clear/set");
    $display("✓ ADC_B bit pattern testing (alternating, single bits)");
    $display("✓ ADC_B edge cases (zero results, negative results, overflow)");
    $display("✓ ADC_C basic operations with carry clear/set");
    $display("✓ ADC_C advanced operations and complex bit patterns");
    $display("✓ ADC_C edge cases and boundary conditions");
    $display("✓ Chain operations testing cascading carry behavior");
    $display("✓ Comprehensive register preservation verification");
    $display("✓ All flag states (Zero, Negative, Carry) thoroughly tested");
    $display("✓ Carry generation and propagation mechanics validated");
    $display("ADC_B_AND_C test finished.===========================\n\n");
    $finish;
    // ============================ END TEST ==============================
  
  end

endmodule