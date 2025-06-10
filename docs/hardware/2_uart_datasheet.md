# UART Peripheral Datasheet (v0.3 - Clarified Register Behavior)

<!-- AIDEV-NOTE: v0.3 update clarifies that Data/Command registers don't store values, trigger immediate actions -->

## 1. Overview

This document describes the register interface and operation of the UART (Universal Asynchronous Receiver/Transmitter) peripheral for the [Your CPU Name] system. This version provides serial byte transmission and reception capabilities with enhanced status reporting, including frame and overshoot error detection, and a command register for clearing error flags.

## 2. Features

* Serial data transmission (CPU to serial out).
* Serial data reception (serial in to CPU).
* Level-sensitive `RX_DATA_READY` flag: Indicates a byte is available in the receiver buffer until explicitly read by the CPU.
* Comprehensive error reporting:
  * Receiver Frame Error detection.
  * Receiver Overshoot/Overrun Error detection.
* Command register for explicit clearing of error flags.
* Memory-mapped register interface.
* **Note:** Baud rate, data bits (8), stop bits (1), and parity (none) are currently fixed at compile-time within the `uart_transmitter` and `uart_receiver` modules. Future versions may allow runtime configuration via the Config Register.

## 3. Memory Map

The UART peripheral is mapped into the system's I/O address space.

| Register Name      | Address | R/W        | Description                                                     |
|--------------------|---------|------------|-----------------------------------------------------------------|
| Config Register    | `$E000` | R/W        | Configures UART operation (currently placeholder)               |
| Status Register    | `$E001` | Read-Only  | Provides UART status information                                  |
| Data Register      | `$E002` | R/W        | Transmit Data (on write), Receive Data (on read)                  |
| Command Register   | `$E003` | Write-Only | Executes commands (e.g., clear error flags)                     |

**Note:** The `address_offset` input to the `uart_peripheral` module corresponds to `cpu_mem_address[1:0]`.

* `2'b00` (`$E000`) accesses the Config Register.
* `2'b01` (`$E001`) accesses the Status Register.
* `2'b10` (`$E002`) accesses the Data Register.
* `2'b11` (`$E003`) accesses the Command Register.

## 4. Register Descriptions

### 4.1. Config Register (Address: `$E000`)

* **Type:** Read/Write
* **Reset Value:** `$00` (all bits 0)
* **Purpose:** Intended for future UART configuration (e.g., baud rate, parity, stop bits). Currently, writing to this register stores the value, and reading returns the stored value, but no bits have active control functions influencing UART operation.

| Bit | Name          | R/W | Reset | Description                        |
|-----|---------------|-----|-------|------------------------------------|
| 7-0 | `CONFIG[7:0]` | R/W | 0     | Reserved. No function implemented. |

### 4.2. Status Register (Address: `$E001`)

* **Type:** Read-Only
* **Purpose:** Provides status information about the transmitter and receiver, including error conditions. Error flags are "sticky" and remain set until explicitly cleared by writing to the Command Register or by a system reset.

| Bit | Name                    | Description                                                                                                                               |
|-----|-------------------------|-------------------------------------------------------------------------------------------------------------------------------------------|
| 0   | `TX_BUF_EMPTY`       | **1 (Set):** Transmitter is ready to accept a new byte. (`~tx_busy_i`)<br>**0 (Clear):** Transmitter is busy.                               |
| 1   | `RX_DATA_READY`         | **1 (Set):** A complete byte has been received and is available in the Data Register. This flag remains set until the CPU reads the Data Register (`$E002`).<br>**0 (Clear):** No new data is available, or data has been read by the CPU. |
| 2   | `ERROR_FRAME`           | **1 (Set):** A framing error (e.g., stop bit not detected correctly) occurred during a reception. Cleared by Command Register or reset.<br>**0 (Clear):** No uncleared framing error. |
| 3   | `ERROR_OVERSHOOT`       | **1 (Set):** An overshoot/overrun error occurred. A new byte was fully received while the previous byte in the Data Register had not yet been read by the CPU. The previous byte is lost. Cleared by Command Register or reset.<br>**0 (Clear):** No uncleared overshoot error. |
| 7-4 | Reserved                | Reads as `0`.                                                                                                                             |

### 4.3. Data Register (Address: `$E002`)

* **Type:** Read/Write (behavior depends on operation)
* **Write Operation (CPU `STA $E002`): Transmit Data Register (TXDR)**
  * Writing an 8-bit value loads the byte into the UART transmitter and **immediately triggers transmission**.
  * **Important:** This register does **not** store the written value - it passes the data directly to the transmitter hardware.
  * The transmitter becomes busy (TX_BUF_EMPTY = 0) during transmission.
* **Read Operation (CPU `LDA $E002`): Receive Data Register (RXDR)**
  * Reading retrieves the 8-bit byte from the receiver buffer.
  * **This action also acknowledges receipt to the UART, causing the `RX_DATA_READY` flag in the Status Register to be cleared.**
  * It is critical to check `RX_DATA_READY` before reading to ensure valid data.
  * Reading this register does *not* automatically clear error flags (`ERROR_FRAME`, `ERROR_OVERSHOOT`).

### 4.4. Command Register (Address: `$E003`)

* **Type:** Write-Only  
* **Purpose:** Allows the CPU to issue commands to the UART, primarily for clearing status flags. 
* **Behavioral Note:** This register does **not** store written values. Instead, it executes commands immediately based on the bit pattern written. The bits act as one-cycle command strobes that trigger actions within the UART peripheral.

| Bit Written | Name                             | Action if Bit is 1 on Write                                |
|-------------|----------------------------------|------------------------------------------------------------|
| 0           | `CMD_CLEAR_FRAME_ERROR`          | Clears the `ERROR_FRAME` (bit 2) in the Status Register.   |
| 1           | `CMD_CLEAR_OVERSHOOT_ERROR`      | Clears the `ERROR_OVERSHOOT` (bit 3) in the Status Register.|
| 7-2         | Reserved                         | No action.                                                 |

* **Example Usage:** To clear a frame error, the CPU would write a value with bit 0 set (e.g., `$01`) to address `$E003`. To clear both frame and overshoot errors simultaneously (if both were set), write `$03`.

## 5. Basic Programming Examples (Conceptual Assembly)

```assembly
; --- Define UART Constants (from mmio_defs.inc) ---
; UART_CONFIG_REG          EQU $E000
; UART_STATUS_REG          EQU $E001
; UART_DATA_REG            EQU $E002
; UART_COMMAND_REG         EQU $E003

; MASK_TX_BUF_EMPTY     EQU %00000001 ; Or $01
; MASK_RX_DATA_READY       EQU %00000010 ; Or $02
; MASK_ERROR_FRAME         EQU %00000100 ; Or $04
; MASK_ERROR_OVERSHOOT     EQU %00001000 ; Or $08

; UART_CMD_CLEAR_FRAME_ERROR EQU %00000001 ; Value to write to command reg
; UART_CMD_CLEAR_OVERSHOOT_ERROR EQU %00000010

; --- Procedure: Send a byte (byte to send is in Accumulator A) ---
SEND_UART_BYTE:
TX_POLL_SEND:
    LDA UART_STATUS_REG
    ANI #MASK_TX_BUF_EMPTY
    JZ TX_POLL_SEND
    STA UART_DATA_REG      ; (Assumes A holds byte to send)
    ; RTS                    ; (If using subroutines)
    ; JMP to next part of program if not a subroutine

; --- Procedure: Receive a byte with basic error checking ---
; Clobbers: A, B (and flags)
; If returning values: e.g. A = received byte if no error,
; B = status (0 for OK, non-zero for error type if using that scheme)

RECEIVE_UART_BYTE_CHECK_ERR:
POLL_RX_EVENT:
    LDA UART_STATUS_REG
    MOV A, B                ; Save status in B (Assuming MOV SRC,DST => B=A)

    ANI #MASK_ERROR_FRAME
    JNZ RX_FRAME_ERROR_HANDLER

    MOV B, A                ; Restore status
    ANI #MASK_ERROR_OVERSHOOT
    JNZ RX_OVERSHOOT_HANDLER

    MOV B, A                ; Restore status
    ANI #MASK_RX_DATA_READY
    JZ POLL_RX_EVENT        ; Loop if nothing yet

    ; RX_DATA_READY is set, no errors detected this poll
    LDA UART_DATA_REG       ; A = good received byte. Clears RX_DATA_READY.
    ; LDI B, #$00             ; Optional: B = 0 (indicates OK)
    ; RTS / JMP to process good data
    JMP PROCESS_GOOD_DATA   ; Example jump

RX_FRAME_ERROR_HANDLER:
    ; LDI A, #$FE           ; Optional: Output error code to a port
    ; STA OUTPUT_PORT_1
    LDI A, #UART_CMD_CLEAR_FRAME_ERROR
    STA UART_COMMAND_REG
    LDA UART_DATA_REG       ; "Consume" bad byte from RX buffer & clear RX_DATA_READY if it was set
    ; LDI B, #MASK_ERROR_FRAME ; Optional: B = error type
    ; LDI A, #'F'           ; Optional: Load 'F' into A to be echoed or processed
    JMP PROCESS_ERROR_DATA  ; Example jump

RX_OVERSHOOT_HANDLER:
    ; LDI A, #$DD           ; Optional: Output error code to a port
    ; STA OUTPUT_PORT_1
    LDI A, #UART_CMD_CLEAR_OVERSHOOT_ERROR
    STA UART_COMMAND_REG
    LDA UART_DATA_REG       ; Reads the overwriting byte, clears RX_DATA_READY
    ; LDI B, #MASK_ERROR_OVERSHOOT ; Optional: B = error type
    ; A holds the overwriting byte, could echo it or an error char 'O'
    JMP PROCESS_ERROR_DATA  ; Example jump

PROCESS_GOOD_DATA:
    ; ... A contains good data ...
    JMP POLL_RX_EVENT       ; Example: loop back

PROCESS_ERROR_DATA:
    ; ... A might contain specific char, B might contain error type ...
    JMP POLL_RX_EVENT       ; Example: loop back

## 6. Implementation Notes

### 6.1. Register Storage Behavior
* **Config Register ($E000):** Stores written values and can be read back.
* **Status Register ($E001):** Read-only - reflects real-time UART status.
* **Data Register ($E002):** **Does not store values** - writes trigger immediate transmission, reads return received data.
* **Command Register ($E003):** **Does not store values** - writes execute immediate commands.

### 6.2. Error Handling
* Error flags (ERROR_FRAME, ERROR_OVERSHOOT) are sticky and must be cleared by writing to the Command Register.
* Reading the Data Register ($E002) clears the RX_DATA_READY flag.
* The CPU should poll the Status Register to manage data flow and check for errors.

### 6.3. Integration Testing
* UART functionality can be verified using memory-mapped writes to the UART address space ($E000-$E003).
* Only the Config Register will show persistent stored values during testing.
* Data and Command register operations trigger hardware actions rather than storing test values.

### 6.4. Future Enhancements
Future enhancements may include runtime configuration of baud rate, parity, etc., via the Config Register and FIFO buffers.
