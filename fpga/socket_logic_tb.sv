// Testbench
`define SPI_BUF_WIDTH 4
`define FIFO_ADDR_WIDTH 5

module test;
  
  reg a_inclk;
  reg [15:0] b_inport;
  reg c_SPI_CLK;
  reg d_SPI_MOSI;
  wire e_SPI_MISO;
  reg f_SPI_SS;
  reg g_Reset;
  
  wire [3:0] h_spi_addr_reg;
  wire [31:0] i_reg_data_spi;
  wire [31:0] j_spi_data_reg; 
  wire k_spi_we_reg;
  //Controller-TX
  wire [`SPI_BUF_WIDTH-1:0] l_cont_addr_tx;
  wire m_cont_we_tx;
  //Controller-RX 
  //wire [11:0] cont_addr_rx;

  //SPI-TX
  wire [`SPI_BUF_WIDTH-1:0] n_spi_addr_tx;    // outgoing data
  wire [7:0] o_tx_data_spi;
  /*wire [11:0] spi_addr_rx;    // incoming data
  wire [7:0] spi_data_rx;
  wire spi_we_rx;*/

  //Fifo-TX
  wire [7:0] p_fifo_data_tx;
  //Rx-Fifo
  //wire [7:0] rx_data_fifo;

  wire [3:0] q_cont_cmd_fifo;
  
  wire [7:0] r_debug_out;
  
  wire [7:0] s_state;
  
  wire [31:0] t_reg0;
  
  wire [15:0] u_last;
  
  wire [`FIFO_ADDR_WIDTH-1:0] v_counter;
  
  wire [`FIFO_ADDR_WIDTH-1:0] w_fifo_addr;
  
  wire x_fifo_subaddr;
  
  instrument logic_inst(a_inclk, b_inport, c_SPI_CLK, d_SPI_MOSI, e_SPI_MISO, f_SPI_SS, g_Reset,
  h_spi_addr_reg,
  i_reg_data_spi,
  j_spi_data_reg,
  k_spi_we_reg,
  l_cont_addr_tx,
  m_cont_we_tx,
  n_spi_addr_tx,
  o_tx_data_spi,
  p_fifo_data_tx,
  q_cont_cmd_fifo,
  r_debug_out,
  s_state,
  t_reg0,
  u_last,
  v_counter,
  w_fifo_addr,
  x_fifo_subaddr);
  
  
 
    
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
      sendByte(8'hC0);
      sendByte(8'h00);
      sendByte(8'h00);
      sendByte(8'h00);
      sendByte(command);
    end
  endtask

  task set1;
    input   [7:0] val;
    begin
      sendByte(8'hC1);
      sendByte(8'h00);
      sendByte(8'h00);
      sendByte(8'h00);
      sendByte(val);
    end
  endtask
  task set2;
    input   [7:0] val;
    begin
      sendByte(8'hC2);
      sendByte(8'h00);
      sendByte(8'h00);
      sendByte(8'h00);
      sendByte(val);
    end
  endtask
  
  task readResp;
    begin
      sendByte(8'h80);
      sendByte(8'h00);
      sendByte(8'h00);
      sendByte(8'h00);
      sendByte(8'h00);
    end
  endtask
  task read1;
    begin
      sendByte(8'h81);
      sendByte(8'h00);
      sendByte(8'h00);
      sendByte(8'h00);
      sendByte(8'h00); 
      $display("%g\trx:0x%h", $time, returned);
    end
  endtask
  task readBuf;
    begin
      f_SPI_SS = 0;
      readResp();
      f_SPI_SS = 1;
      #10;
      while (returned != 8'h04) begin
        f_SPI_SS = 0;
        readResp();
        f_SPI_SS = 1;
        #10;
      end
      #10;
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
  task nextBuf;
    begin
      #10;
      f_SPI_SS = 0;
      sendCommand(8'h05);
      f_SPI_SS = 1;
    end
  endtask
  
  task complete;
    begin
      #10;
      f_SPI_SS = 0;
      sendCommand(8'h07);
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
  
  initial begin
    forever begin
      #2 b_inport = b_inport + 1; 
    end
  end
  
  reg [15:0] i;

  initial begin
   	// Dump waves
    $dumpfile("dump.vcd");
    $dumpvars(1, test);
    
    $display("Testing");
    a_inclk = 1;
    b_inport = 0;
    g_Reset = 0;
    c_SPI_CLK = 0;
    d_SPI_MOSI = 0;
    f_SPI_SS = 1;
    #4;
    g_Reset = 1;
    #4;
    g_Reset = 0;
    #4
    f_SPI_SS = 0;
    //set trigger bit 0-15 h00-h0f
    set1(8'h08);
    read1();
 
    //set trigger edge 1=pos 0=neg
    set2(8'h01);
    
    
    //wait for trigger
    sendCommand(8'h01);
    
    f_SPI_SS = 1;
    #10;
	
    
    readBuf();
    #10;
    
    nextBuf();
   	#10;
    
    readBuf();
    #10;
    
    nextBuf();
   	#10;
    
    readBuf();
    #10;
    
    nextBuf();
   	#10;
    
    readBuf();
    #10;
    
    complete();
   
    
    #100;
    
    
    $finish;

    
  end
  

  
endmodule