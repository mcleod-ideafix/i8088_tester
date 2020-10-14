//////////////////////////////////////////////////////////////////////////////////
//    This file is tld_zxuno_v41
//    Creation date is 22:00:58 07/20/2020 by Miguel Angel Rodriguez Jodar
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

module tld_i8088_tester_zxuno_v41 (
  input wire clk50mhz,
  output wire testled,
  //// interface i8088 /////
  output wire clkcpu,
  output wire rst,
  inout wire [7:0] ad,
  input wire [19:8] a,
  input wire ale,
  input wire den_n,
  input wire io_m_n,
  input wire rd_n,
  input wire wr_n,
  input wire dt_r_n,
  output wire intr,
  input wire ss0
  );

  wire clk25mhz;
  relojes reloj25m (
    .CLK_IN1(clk50mhz),
    .CLK_OUT1(clk25mhz)
  );
  
  minimal_system the_sistema (
    .clk(clk25mhz),
    .clkcpu(clkcpu),
    .rst(rst),
    .ad(ad),
    .a(a),
    .ale(ale),
    .den_n(den_n),
    .io_m_n(io_m_n),
    .rd_n(rd_n),
    .wr_n(wr_n),
    .dt_r_n(dt_r_n),
    .intr(intr),
    .ss0(ss0),
    ///////////////////
    .led(testled)
  );
endmodule

`default_nettype wire