# UART Peripheral Mini-Datasheet (v0.1 - Rudimentary)

## 1. Overview

This document describes the register interface and basic operation of the rudimentary UART (Universal Asynchronous Receiver/Transmitter) peripheral for the [Your CPU Name] system. This version provides basic serial byte transmission and reception capabilities with fixed communication parameters.

## 2. Features

* Serial data transmission (CPU to serial out).
* Serial data reception (serial in to CPU).
* Status register for monitoring transmitter and receiver states, **including a single-cycle `RX_DATA_READY` flag.**
* Basic error reporting for receiver (frame, overshoot).
* Memory-mapped register interface.
* **Note:** Baud rate, data bits (8), stop bits (1), and parity (none) are currently fixed at compile-time within the `uart_transmitter` and `uart_receiver` modules. This version of the `uart_peripheral` does not provide runtime configuration for these parameters.

## 3. Memory Map

The UART peripheral is mapped into the system's I/O address space. The CPU accesses the UART registers using the following memory addresses:

| Register Name      | Address | R/W      | Description                                     |
|--------------------|---------|----------|-------------------------------------------------|
| Control Register   | `$E000` | R/W      | Configures UART operation (currently placeholder) |
| Status Register    | `$E001` | Read-Only| Provides UART status information                |
| Data Register      | `$E002` | R/W      | Transmit Data (on write), Receive Data (on read)|

**Note:** The `address_offset` input to the `uart_peripheral` module corresponds to `cpu_mem_address[1:0]`.

* `2'b00` ($E000) accesses the Control Register.
* `2'b01` ($E001) accesses the Status Register.
* `2'b10` ($E002) accesses the Data Register.

## 4. Register Descriptions

### 4.1. Control Register (Address: `$E000`)

* **Type:** Read/Write
* **Reset Value:** `$00` (all bits 0)
* **Purpose:** Placeholder for future UART configuration. Currently, writing to this register stores the value, and reading returns the stored value, but no bits have defined control functions.

| Bit | Name         | R/W | Reset | Description                       |
|-----|--------------|-----|-------|-----------------------------------|
| 7-0 | `CONTROL[7:0]` | R/W | 0     | Reserved. No function implemented. |

### 4.2. Status Register (Address: `$E001`)

* **Type:** Read-Only
* **Purpose:** Provides status information about the transmitter and receiver.

| Bit | Name                  | R/W | Description                                                                 |
|-----|-----------------------|-----|-----------------------------------------------------------------------------|
| 0   | `TX_BUFFER_EMPTY`     | R   | **1 (Set):** Transmitter is ready to accept a new byte in the Data Register. (Corresponds to `~tx_busy_i`)<br>**0 (Clear):** Transmitter is busy sending a previous byte or not yet initialized. |
| 1   | `RX_DATA_READY`       | R   | **1 (Set):** A complete byte has just been received and is available in the Data Register **for the current clock cycle**. This flag is asserted for **one clock cycle only** when the receiver transitions to its `DATA_READY` state. It is cleared when the receiver returns to its `IDLE` state (typically on the next clock cycle after `DATA_READY`).<br>**0 (Clear):** No new data has just become ready in this clock cycle. The CPU must poll this flag frequently to catch it when asserted. |
| 2   | `ERROR_FRAME`         | R   | **1 (Set):** A framing error (e.g., stop bit not detected correctly) occurred during the last completed reception attempt.<br>**0 (Clear):** No framing error detected on the last completed reception. *(Note: Behavior of this flag across multiple receptions needs further characterization if it's not explicitly cleared by CPU action).* |
| 3   | `ERROR_OVERSHOOT`     | R   | **1 (Set):** Reserved. Overshoot/overrun error detection is **not implemented** in this version.<br>**0 (Clear):** Reads as 0. |
| 7-4 | Reserved              | R   | Reads as `0`.                                                               |

*Important Note on `RX_DATA_READY` (Bit 1): Due to its single-cycle assertion, the CPU must poll this status bit in a tight loop if it expects to reliably detect an incoming byte. If the CPU is too slow or is performing other tasks, it may miss this flag.*

*Note on `ERROR_FRAME` (Bit 2): This flag indicates an error on the most recent attempt to receive a full frame. Its state for subsequent receptions if not cleared by a CPU action (e.g., reading the data register or a specific clear-error command, neither of which are currently implemented to clear errors) should be considered. It likely reflects the status of the *last* frame that completed its receive cycle.*

### 4.3. Data Register (Address: `$E002`)

* **Type:** Read/Write (behavior depends on operation)
* **Write Operation (CPU `STA $E002`): Transmit Data Register (TXDR)**
  * Writing an 8-bit value to this address loads the byte into the UART transmitter's buffer.
  * Transmission of this byte will begin if the transmitter is ready (i.e., `TX_BUFFER_EMPTY` was 1).
* **Read Operation (CPU `LDA $E002`): Receive Data Register (RXDR)**
  * Reading from this address retrieves the 8-bit byte most recently received by the UART and stored in the receiver's buffer.
  * It is **critical** to check the `RX_DATA_READY` bit in the Status Register **and find it set (1)** before reading this register to ensure valid data is present. Due to the single-cycle nature of `RX_DATA_READY`, this read must ideally occur in the same cycle or very soon after `RX_DATA_READY` is detected as high.
  * Reading this register does *not* automatically clear error flags in the Status Register.

## 5. Basic Programming Examples (Conceptual Assembly)

```assembly
; --- Define UART Constants ---
UART_CONTROL_ADDR   EQU $E000
UART_STATUS_ADDR    EQU $E001
UART_DATA_ADDR      EQU $E002

TX_BUFFER_EMPTY_MASK EQU %00000001 ; Mask for bit 0
RX_DATA_READY_MASK   EQU %00000010 ; Mask for bit 1

; --- Procedure: Send a byte (byte to send is in Accumulator A) ---
SEND_UART_BYTE:
    ; (Preserve/Restore A logic as needed)
TX_POLL_LOOP:
    LDA UART_STATUS_ADDR    ; Load status
    AND #TX_BUFFER_EMPTY_MASK ; Isolate TX_BUFFER_EMPTY bit
    JZ TX_POLL_LOOP         ; If bit was 0 (result is 0, Zero Flag set), loop
    STA UART_DATA_ADDR      ; Send byte (A should hold the byte to send here)
    RTS

; --- Procedure: Receive a byte (received byte will be in Accumulator A) ---
; !!! This polling loop is very timing sensitive due to single-cycle RX_DATA_READY !!!
RECEIVE_UART_BYTE:
RX_POLL_LOOP:
    LDA UART_STATUS_ADDR    ; Load status
    AND #RX_DATA_READY_MASK   ; Isolate RX_DATA_READY bit
    JZ RX_POLL_LOOP         ; If bit was 0 (result is 0, Zero Flag set), loop
                            ; IMPORTANT: If CPU is too slow, it might miss the single cycle
                            ; where RX_DATA_READY is high.
    LDA UART_DATA_ADDR      ; <<< MUST read data very quickly after flag detected
    RTS

## 6. Notes

This UART is rudimentary.
* The RX_DATA_READY flag is asserted for a single clock cycle only. This requires careful and fast polling by the CPU.
* Overshoot error detection is not implemented.
* Framing error is reported but there's no CPU mechanism to explicitly clear it.
* The CPU must poll the Status Register to manage data flow. * 
