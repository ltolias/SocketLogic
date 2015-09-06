// Testbench
`define SPI_BUF_WIDTH 4
`define FIFO_ADDR_WIDTH 5



`define CMD_RESET         32'd0
`define CMD_INIT        32'd1
`define CMD_NONE        32'd2
`define CMD_WAIT_TRIGGER    32'd3
`define CMD_NEXT_BUF      32'd4
`define CMD_COMPLETE      32'd5
`define CMD_ID          32'd6

`define CMD_ARM_ON_STEP   32'd7
`define CMD_SET_VALUE     32'd8
`define CMD_SET_RANGE     32'd9
`define CMD_SET_VMASK     32'd10
`define CMD_SET_EDGE      32'd11
`define CMD_SET_EMASK     32'd12
`define CMD_SET_CONFIG    32'd13
`define CMD_SET_SERIALOPTS  32'd14

`define RESP_RESET      32'd0
`define RESP_INIT       32'd1
`define RESP_NONE       32'd2
`define RESP_ACQ        32'd3
`define RESP_FIFO_TX      32'd4
`define RESP_WAITING      32'd5
`define RESP_DONE       32'd6

`define RESP_ARM_ON_STEP    32'd7
`define RESP_SET_VALUE    32'd8
`define RESP_SET_RANGE    32'd9
`define RESP_SET_VMASK    32'd10
`define RESP_SET_EDGE     32'd11
`define RESP_SET_EMASK    32'd12
`define RESP_SET_CONFIG   32'd13
`define RESP_SET_SERIALOPTS 32'd14



module test;
  
  reg a_inclk;
  reg [15:0] b_inport;
  reg c_SPI_CLK;
  reg d_SPI_MOSI;
  wire e_SPI_MISO;
  reg f_SPI_SS;
  reg g_Reset;
  
  
  instrument logic_inst(a_inclk, b_inport, c_SPI_CLK, d_SPI_MOSI, e_SPI_MISO, f_SPI_SS, g_Reset);
  
 
    
  reg [7:0] returned;
  
  task recvByte;
    input   [7:0] rcByte;
    integer       rcBitIndex;
    begin   
      for (rcBitIndex = 0; rcBitIndex < 8; rcBitIndex = rcBitIndex + 1) begin
        d_SPI_MOSI = rcByte[7 - rcBitIndex];
        returned[7-rcBitIndex] = e_SPI_MISO;
        #4;
      end
      $display("%g\ttx:0x%h\trx:0x%h", $time, rcByte, returned);
    end
  endtask
  
  
  task sendByte;
    input   [7:0] rcByte;
    integer       rcBitIndex;
    begin   
      for (rcBitIndex = 0; rcBitIndex < 8; rcBitIndex = rcBitIndex + 1) begin
        d_SPI_MOSI = rcByte[7 - rcBitIndex];
        returned[7-rcBitIndex] = e_SPI_MISO;
        #4;
      end
    end
  endtask
  
  
  task sendCommand;
    input   [7:0] command;
    begin
      f_SPI_SS = 0;
      sendByte(8'hC0);
      sendByte(8'h00);
      sendByte(8'h00);
      sendByte(8'h00);
      sendByte(command);
      f_SPI_SS = 1;
    end
  endtask

  task write1;
    input   [31:0] val;
    begin
      f_SPI_SS = 0;
      sendByte(8'hC1);
      sendByte(val >> 24);
      sendByte((val >> 16) & (8'hff));
      sendByte((val >> 8) & (8'hff));
      sendByte(val & 8'hff);
      f_SPI_SS = 1;
    end
  endtask
  task readResp;
    begin
      f_SPI_SS = 0;
      sendByte(8'h88);
      sendByte(8'h00);
      sendByte(8'h00);
      sendByte(8'h00);
      sendByte(8'h00);
      f_SPI_SS = 1;
    end
  endtask
  
  task blockResponse;
    input   [7:0] val;
    begin
      readResp();
      #4;
      while (returned != val) begin
        readResp();
        #4;
      end
    end
  endtask
      
  task readBuf;
    begin
      blockResponse(`RESP_WAITING);
      #4;
      i = 0;
      f_SPI_SS = 0;
      sendByte(8'h03);
      while (i <= 15) begin
        sendByte(8'h00); 
        $display("%g\trx:0x%h\t%d", $time, returned, i);
        i = i+1;
      end
      f_SPI_SS = 1;
    end
  endtask

  
  
  initial begin 
    forever begin
      #1 a_inclk = ~a_inclk; 
    end
  end
  
  initial begin
     forever begin
       if (~f_SPI_SS) begin
        c_SPI_CLK = ~c_SPI_CLK;
        #1;
      end
      else begin
        c_SPI_CLK = 0;
      end
      #1;
    end
  end
  
  /*initial begin
    forever begin
      #2 b_inport = b_inport + 1; 
    end
  end*/
  
  reg [15:0] i;

  initial begin
    // Dump waves
    $dumpfile("dump.vcd");
    $dumpvars(1,logic_inst);
    $dumpvars(2, logic_inst.controller_inst);
    //$dumpvars(2, logic_inst.tsys_inst);
    //$dumpvars(2, logic_inst.fifo_inst);
    
    $display("Testing");
    a_inclk = 1;
    b_inport = 16'd1;
    g_Reset = 0;
    c_SPI_CLK = 0;
    d_SPI_MOSI = 0;
    f_SPI_SS = 1;
    #4;
    g_Reset = 1;
    #4;
    g_Reset = 0;
    #4
    
    #10;
    sendCommand(`CMD_RESET);
    #4;
    blockResponse(`RESP_RESET);
    #4;
    sendCommand(`CMD_INIT);
    #4;
    blockResponse(`RESP_INIT);
    #4;
    write1(3 << 16);
    #4;
    sendCommand(`CMD_ARM_ON_STEP);
    #4;
    blockResponse(`RESP_ARM_ON_STEP);
    #4;
    write1((1 << 8) | (0 << 24));
    #4;
    sendCommand(`CMD_SET_VALUE);
    #4;
    blockResponse(`RESP_SET_VALUE);
    #4;
    write1((0 << 8) | 1 | (0 << 24));
    #4;
    sendCommand(`CMD_SET_VMASK);
    #4;
    blockResponse(`RESP_SET_VMASK);
    #4;
    write1((1 << 8) | (0 << 24));
    #4;
    sendCommand(`CMD_SET_EDGE);
    #4;
    blockResponse(`RESP_SET_EDGE);
    #4;
    write1((1 << 6) | (0 << 24));
    #4;
    sendCommand(`CMD_SET_CONFIG);
    #4;
    blockResponse(`RESP_SET_CONFIG);
    #4;
    write1((2 << 8) | (1 << 24));
    #4;
    sendCommand(`CMD_SET_VALUE);
    #4;
    blockResponse(`RESP_SET_VALUE);
    #4;
    write1((2 << 8) | 2 | (1 << 24));
    #4;
    sendCommand(`CMD_SET_VMASK);
    #4;
    blockResponse(`RESP_SET_VMASK);
    #4;
    sendCommand(`CMD_NONE);
    
    #20;
    
    sendCommand(`CMD_WAIT_TRIGGER);
    
    
    #15;
    b_inport = 16'd0;
    #15;
    b_inport = 16'd1;

    
    #14;
    
    b_inport = 16'd2;
    
    #20;
  //$finish;

  
    readBuf();
    $display("Testing");
    #4;
    
    sendCommand(`CMD_NEXT_BUF);
    #4;
    
    readBuf();
    #4;
    
    sendCommand(`CMD_NEXT_BUF);
    #4;
    
    readBuf();
    #4;
    
    sendCommand(`CMD_NEXT_BUF);
    #4;
    
    readBuf();
    #4;
    
    sendCommand(`CMD_COMPLETE);
   
    
    #100;
    
    
    $finish;

    
  end
  

  
endmodule