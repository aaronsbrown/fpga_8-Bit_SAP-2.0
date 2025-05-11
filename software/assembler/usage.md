```bash
    $ python software/assembler/src/assembler.py \
    software/asm/src/<your_test_file>.asm \
    hardware/test/fixtures_generated/<your_test_file_tb>/ \
    --region ROM <rom_start_hex> <rom_end_hex> \
    --region RAM <ram_start_hex> <ram_end_hex>
    # Add other regions as needed
```
