import arch_defs_pkg::*;


`ifndef UUT_PATH
  `define UUT_PATH uut // Default fallback
`endif

package test_utils_pkg;

  // Task to compare two 32-bit vectors.
  task pretty_print_assert_vec;
    // Keep using fixed width arguments
    input [31:0] actual;
    input [31:0] expected;
    input string msg;
    begin
      // Comparison '===' works correctly even if actual vectors are smaller
      // (they get implicitly zero-extended).
      if (actual !== expected) begin
        $display("[%0t] \033[0;31mAssertion Failed: %s. Actual: %h, Expected: %h\033[0m", $time, msg, actual, expected); // Use %h for hex
      end else begin
        $display("[%0t] \033[0;32mAssertion Passed: %s\033[0m", $time, msg);
      end
    end
  endtask

  task clear_ram;
    input int start_addr;
    input int end_addr;
    begin
      for (int i = start_addr; i <= end_addr; i++) begin
        if (i < RAM_DEPTH) begin
          `UUT_PATH.u_ram.mem[i] = 8'h00;
        end else begin
          $display("Warning: clear_ram attempted to access out-of-bounds address %0d (RAM Depth: %0d)", i, RAM_DEPTH);
        end
      end
    end
  endtask
  

  // Task to run simulation until halt is asserted or a cycle timeout occurs
   task run_until_halt;
    input int max_cycles;
    int cycle;
    begin // Task begin
      cycle = 0;
      while (cycle < max_cycles) begin 
        #1ps; 
        if (`UUT_PATH.cpu_halt == 1) begin 
            $display("HALT signal detected high at start of cycle %0d.", cycle + 1);
            break; 
        end 
        @(posedge clk); // Wait for next edge if not halted
        cycle++;
      end 

      #1ps; // Allow final state signals to settle
      if (`UUT_PATH.cpu_halt == 0 && cycle >= max_cycles) begin // If timeout begin
        $display("\033[0;31mSimulation timed out. HALT signal not asserted after %0d cycles.\033[0m", cycle);
        $error("Simulation timed out.");
        $finish;
      end 
      else begin // Else (halt detected or finished cycles but halt is high) begin
        $display("\033[0;32mSimulation run completed (halt detected or max cycles reached while potentially halting). Cycles run: %0d\033[0m", cycle);
      end 
    end // Task end
  endtask

  task inspect_register;
    // Use fixed width for task arguments
    input [31:0] actual;
    input [31:0] expected;
    input string name;
    input int expected_width;
    logic [31:0] mask;
  begin
      // Create a mask to compare only relevant bits
      mask = (expected_width == 32) ? 32'hFFFFFFFF : (32'h1 << expected_width) - 1;
      // Compare only the lower 'expected_width' bits
      if ((actual & mask) !== (expected & mask)) begin
           $display("[%0t] \033[0;31mAssertion Failed: %s (%0d bits). Actual: %0h, Expected: %0h\033[0m",
                    $time, name, expected_width, actual & mask, expected & mask);
      end else begin
           $display("[%0t] \033[0;32mAssertion Passed: %s (%0d bits) = %0h\033[0m",
                    $time, name, expected_width, actual & mask);
      end
      // Call the original pretty_print_assert_vec if you want the full binary view too
      // pretty_print_assert_vec(actual & mask, expected & mask, {name, " register check"});
    end
  endtask

  task reset_and_wait;
    input int cycles;
    begin
      
      reset = 1'b1;
      repeat(3) @(posedge clk);
      @(negedge clk);
      reset = 1'b0;
      @(posedge clk);
      $display("TB: Reset released at %0t", $time);
      
      repeat (cycles) @(posedge clk);
      $display("TB: Waited an additional %0d cycles", cycles);

    end
  endtask

  task safe_readmemh_rom; // Specific task for ROM
    input string file_path;
    // No memory_array port needed, we'll use a hierarchical path

    integer file_handle;
    string task_msg_prefix = "Task safe_readmemh (ROM)"; // Hardcode for clarity

    begin
      $display("--- %s: Attempting to load hex file: %s ---", task_msg_prefix, file_path);
      file_handle = $fopen(file_path, "r");

      if (file_handle == 0) begin
        $display("--------------------------------------------------------------------");
        $error("FATAL ERROR [%s]: Could not open HEX_FILE for ROM: %s", task_msg_prefix, file_path);
        $display("Please ensure the fixture .hex file exists and is readable.");
        $display("--------------------------------------------------------------------");
        $finish(2);
      end else begin
        $fclose(file_handle);
        $display("--- %s: File found. Loading hex file into ROM memory array ---", task_msg_prefix);
        // Use the hierarchical path to the ROM memory
        // This assumes your ROM instance within 'uut' is named 'u_rom' and its memory is 'mem'
        // And that UUT_PATH is defined correctly (usually as 'uut' from the TB perspective)
        $readmemh(file_path, `UUT_PATH.u_rom.mem);
        $display("--- %s: $readmemh call completed for %s. ---", task_msg_prefix, file_path);
      end
    end
  endtask

  task safe_readmemh_ram; // Specific task for RAM
    input string file_path;
    // No memory_array port needed if using hierarchical path like for ROM

    integer file_handle;
    string task_msg_prefix = "Task safe_readmemh (RAM)";

    begin
      // Check if an empty or "NONE" string is passed, indicating no RAM file to load
      if (file_path == "" || file_path == "NONE" || file_path == "UNUSED") begin
        $display("--- %s: No RAM file specified or marked as unused ('%s'). Skipping RAM load. ---", task_msg_prefix, file_path);
        return; // Exit the task gracefully
      end

      $display("--- %s: Attempting to load hex file: %s ---", task_msg_prefix, file_path);
      file_handle = $fopen(file_path, "r");

      if (file_handle == 0) begin
        // For RAM, not finding the file might be acceptable for some tests.
        // Let's make it a WARNING instead of a FATAL ERROR, unless the test *requires* it.
        // If a test absolutely needs RAM data, it should fail later if the data isn't there.
        // Alternatively, you could have a flag to make this fatal if needed.
        $display("--------------------------------------------------------------------");
        $warning("WARNING [%s]: Could not open HEX_FILE for RAM: %s", task_msg_prefix, file_path);
        $display("RAM will not be initialized from this file. Test may proceed with uninitialized/default RAM contents.");
        $display("If this test requires pre-loaded RAM, this will likely lead to a test failure.");
        $display("--------------------------------------------------------------------");
        // $finish(2); // Optionally make it fatal if all tests with RAM.hex *must* find it.
      end else begin
        $fclose(file_handle); // Close file handle after checking existence
        $display("--- %s: File found. Loading hex file into RAM memory array ---", task_msg_prefix);
        // Use the hierarchical path to the RAM memory
        // Assumes your RAM instance within `UUT_PATH` (e.g., 'uut') is named 'u_ram' and its memory is 'mem'
        $readmemh(file_path, `UUT_PATH.u_ram.mem);
        $display("--- %s: $readmemh call completed for %s. ---", task_msg_prefix, file_path);
        // Optionally, you could call a RAM dump here if `UUT_PATH.u_ram.dump()` exists
        // `UUT_PATH.u_ram.dump();
      end
    end
  endtask

endpackage : test_utils_pkg
