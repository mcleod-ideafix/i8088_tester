//////////////////////////////////////////////////////////////////////////////////
//    This file is system
//    Creation date is 18:27:19 07/20/2020 by Miguel Angel Rodriguez Jodar
//    (c)2020 Miguel Angel Rodriguez Jodar. ZXProjects
//
//    This core is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    This core is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with this core.  If not, see <https://www.gnu.org/licenses/>.
//
//    All copies of this file must keep this notice intact.
//
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ns
`default_nettype none

module minimal_system (
  input wire clk,      // 25 MHz (comes from the PLL/DCIM module of the FPGA)
  output reg clkcpu,   // 1/6 of clk. 33% duty cycle
  output wire rst,     // active high for 8 clkcpu clocks
  inout wire [7:0] ad, // low part of address bus / databus
  input wire [19:8] a, // high part of address bus
  input wire ale,      //
  input wire den_n,    // These signals come straight from
  input wire io_m_n,   // the corresponding pins at the i8088
  input wire rd_n,     // chip
  input wire wr_n,     //
  input wire dt_r_n,   //
  input wire ss0,      //
  output wire intr,    //
  //// Remaining pins: READY=1, NMI=0, TEST=0, MN/MX=1, HOLD=0
  output wire led
  );

  // No interrupts for this test machine
  assign intr = 1'b0;

  // CPU clock generation, 1/6 clk, con 33% duty cycle
  initial clkcpu = 1'b0;
  reg [2:0] cntclkcpu = 3'd0;
  always @(posedge clk) begin
    if (cntclkcpu == 3'd5) begin
      cntclkcpu <= 3'd0;
      clkcpu <= 1'b0;
    end
    else begin
      cntclkcpu <= cntclkcpu + 3'd1;
      if (cntclkcpu == 3'd3)
        clkcpu <= 1'b1;
    end
  end

  // Events to help synchronize certain signals to the rising or falling edge of the CPU clock
  wire rising_edge_clkcpu = (cntclkcpu == 3'd4);
  wire falling_edge_clkcpu = (cntclkcpu == 3'd0);

  // i8088 power on reset
  reg [7:0] srrst = 8'hFF;  // 8 cpu clks (datasheets states that 4 are the minimum)
  assign rst = srrst[0];
  always @(posedge clk) begin
    if (rising_edge_clkcpu)
      srrst <= {1'b0, srrst[7:1]};
  end

  // Bidir data interface
  reg [7:0] data_to_cpu;
  wire [7:0] data_from_cpu = ad;
  assign ad = (ale == 1'b0 && dt_r_n == 1'b0 && den_n == 1'b0)? data_to_cpu : 8'hZZ;

  // Address bus demuxer
  reg [19:0] addrcpu = 20'h00000;
  always @(posedge clk) begin
    if (ale == 1'b1)
      addrcpu <= {a, ad};
  end

  // Control signal decoding (won't use all of them, though)
  wire memrd = (ale == 1'b0 && io_m_n == 1'b0 && rd_n == 0);
  wire memwr = (ale == 1'b0 && io_m_n == 1'b0 && wr_n == 0);
  wire iord  = (ale == 1'b0 && io_m_n == 1'b1 && rd_n == 0);
  wire iowr  = (ale == 1'b0 && io_m_n == 1'b1 && wr_n == 0);

  // A very simple write-only I/O device at port xx00h (just a led controlled through bit 0 of data written to it)
  reg rled = 1'b0;
  assign led = rled;
  always @(posedge clk) begin
    if (addrcpu[7:0] == 8'h00 && iowr)
      rled <= data_from_cpu[0];
  end

  // ROM and RAM
  reg [7:0] rom[0:15];    // FFFF:FFF0 - FFFF:FFFF
  reg [7:0] ram[0:16383]; // 0000:0000 - 0000:3FFF
  reg [7:0] data_rom, data_ram;

  integer i;
  initial begin
    // ROM content: disable interrupts, turn on the led (as initial test) and far jump to RAM
    for (i=0; i<16; i=i+1)
      rom[i] = 8'h90;  // first, init all 16 bytes with NOP

    // and them, put the actual content we will use (or else, XST will throw a warning about not full BRAM inititalization)
    rom[0] = 8'hFA; // CLI
    rom[1] = 8'hB0; //
    rom[2] = 8'h01; // MOV AL,01h
    rom[3] = 8'hE6; //
    rom[4] = 8'h00; // OUT 0h,AL
    rom[5] = 8'hEA; //
    rom[6] = 8'h00; //
    rom[7] = 8'h04; // JMP FAR 0000:0400
    rom[8] = 8'h00; //
    rom[9] = 8'h00; //

    // First KB of memory holds the IVT. Make all vectors point to the same address
    for (i=0; i<1024; i=i+4) begin
      ram[i*4+0] = 8'hFF; //
      ram[i*4+1] = 8'h3F; // Interrupt routine is at
      ram[i*4+2] = 8'h00; // en 0000:3FFF (IRET)
      ram[i*4+3] = 8'h00; //
    end

    for (i=1024; i<16384; i=i+1)
      ram[i] = 8'h90;  // init all RAM to NOP

    // and them, put the actual program in a small portion of it (16KB of RAM for such a small program may be overkill for some FPGAs. Shrink it according to your needs)
    ram[1024] = 8'hB0;
    ram[1025] = 8'h00; // MOV AL,00h
    ram[1026] = 8'hE6;
    ram[1027] = 8'h00; // again: OUT 0h,AL
    ram[1028] = 8'hB9;
    ram[1029] = 8'hFF;
    ram[1030] = 8'h7F; // wait: MOV CX,7FFFh
    ram[1031] = 8'hE2;
    ram[1032] = 8'hFE; // LOOP wait
    ram[1033] = 8'h34;
    ram[1034] = 8'h01; // XOR AL,1
    ram[1035] = 8'hEB;
    ram[1036] = 8'hF5; // JMP again
    // This small program will make the led to blink at approx. 4 times/second.

    ram[16383] = 8'hCF;  // IRET for all interrupt vectors
  end

  // RAM and ROM handling
  always @(posedge clk) begin
    if (memrd)
      data_rom <= rom[addrcpu[3:0]];
    if (addrcpu[19:14] == 6'b000000) begin
      if (memwr)
        ram[addrcpu[13:0]] <= data_from_cpu;
      else
        data_ram <= ram[addrcpu[13:0]];
    end
  end

  // Output enables for ROM and RAM
  wire oe_rom = (addrcpu[19:4] == 16'hFFFF && memrd);
  wire oe_ram = (addrcpu[19:14] == 6'b000000 && memrd);

  // Muxer to decide which of ROM or RAM will give its data to the CPU
  always @* begin
    case (1'b1)
      oe_rom : data_to_cpu = data_rom;
      oe_ram : data_to_cpu = data_ram;
      default: data_to_cpu = 8'hFF;  // nobody.
    endcase
  end

endmodule

`default_nettype wire
