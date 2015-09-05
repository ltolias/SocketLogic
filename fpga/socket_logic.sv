// Quartus II Verilog Template
// Single port RAM with single read/write address and initial contents 
// specified with an initial block


`define SPI_BUF_WIDTH 4
`define FIFO_ADDR_WIDTH 5

//fifo_addr_width must be >= SPI_BUF_WIDTH-1 and integer multiple

module instrument (
  //input clk_reset,
  input inclk,
  input [15:0] inport,
  input SPI_CLK,
  input SPI_MOSI,
  output SPI_MISO,
  input SPI_SS,
  input Reset,
  output [3:0] spi_addr_reg,
  output [31:0] reg_data_spi,
  output [31:0] spi_data_reg,
  output spi_we_reg,
  output [`SPI_BUF_WIDTH-1:0] cont_addr_tx,
  output cont_we_tx,
  output [`SPI_BUF_WIDTH-1:0] spi_addr_tx,
  output [7:0] tx_data_spi,
  output [7:0] fifo_data_tx,
  output [3:0] cont_cmd_fifo,
  output [7:0] debug_out,
  output [7:0] state,
  output [31:0] reg0,
  output [15:0] last,
  output [`FIFO_ADDR_WIDTH-1:0] counter,
  output [`FIFO_ADDR_WIDTH-1:0] fifo_addr_o,
  output fifo_subaddr_o
); 
  
  wire [3:0] spi_addr_reg;
  wire [31:0] reg_data_spi;
  wire [31:0] spi_data_reg; 
  wire spi_we_reg;
  
  
  wire [3:0] spi_addr_reg_1;
  reg [31:0] reg_data_spi_1;
  wire [31:0] spi_data_reg_1; 
  wire spi_we_reg_1;
  
  
  //Controller-TX
  wire [`SPI_BUF_WIDTH-1:0] cont_addr_tx;
  wire cont_we_tx;
  //Controller-RX 
  //wire [11:0] cont_addr_rx;

  //SPI-TX
  wire [`SPI_BUF_WIDTH-1:0] spi_addr_tx;    // outgoing data
  wire [7:0] tx_data_spi;
  wire [`SPI_BUF_WIDTH-1:0] spi_addr_rx;    // incoming data
  wire [7:0] spi_data_rx;
  wire spi_we_rx;

  //Fifo-TX
  wire [7:0] fifo_data_tx;
  //Rx-Fifo
  //wire [7:0] rx_data_fifo;

  wire [3:0] cont_cmd_fifo;
  
  wire [7:0] debug_out;
  
  
  reg [31:0] reg_bank [0:15];
   always @(posedge inclk) begin   
     reg_data_spi_1 <= reg_bank[spi_addr_reg_1];
     if (spi_we_reg_1) begin
      reg_bank[spi_addr_reg_1] <= spi_data_reg_1;
    end
  end

  // Instantiate the Unit Under Test (UUT)
  spiifc uut (
    .Reset(Reset), 
      .SysClk(inclk),
    .SPI_CLK(SPI_CLK), 
    .SPI_MISO(SPI_MISO), 
    .SPI_MOSI(SPI_MOSI), 
    .SPI_SS(SPI_SS), 
    .txMemAddr(spi_addr_tx), 
    .txMemData(tx_data_spi), 
    .rcMemAddr(spi_addr_rx), 
    .rcMemData(spi_data_rx), 
    .rcMemWE(spi_we_rx),
    .regAddr(spi_addr_reg),
    .regReadData(reg_data_spi),
    .regWriteData(spi_data_reg),
    .regWriteEn(spi_we_reg),
    .debug_out(debug_out)
  );
  
  
  controller controller_inst (
    inclk,
    spi_addr_reg, 
    reg_data_spi, 
    spi_data_reg, 
    spi_we_reg, 
    //Controller-TX
    cont_addr_tx,
    cont_we_tx,
    //Controller-RX 
    //cont_addr_rx,
    cont_cmd_fifo,
    inport,
  	state,
    reg0,
  	last,
  	counter);


  
  /*pll pll_inst (
  .areset ( clk_reset ),
  .inclk0 ( inclk ),
  .c0 ( pllout )
  );*/

  fifo fifo_inst (
    inclk, 
    //rx_data_fifo,
    fifo_data_tx, 
    cont_cmd_fifo, 
    inport,
  	fifo_addr_o,
  	fifo_subaddr_o);
  
  tx_buf txbuf_inst (
    inclk,
    cont_addr_tx,
    cont_we_tx,
    spi_addr_tx,
    tx_data_spi,
    fifo_data_tx);

  
  rx_buf rx_buf_inst (
  	inclk,
  	//cont_addr_rx, 
  	spi_we_rx, 
    spi_addr_rx,
    spi_data_rx/*, 
  	rx_data_fifo*/);
  
endmodule


module tx_buf (
  input inclk,
  input [`SPI_BUF_WIDTH-1:0] cont_addr_tx, 
  input cont_we_tx, 
  input [`SPI_BUF_WIDTH-1:0] spi_addr_tx,
  output reg [7:0] tx_data_spi, 
  input [7:0] fifo_data_tx);

  always @(posedge inclk) begin    // Write reg
    if (cont_we_tx) begin
      tx_buf[cont_addr_tx] <= fifo_data_tx;
    end
    tx_data_spi <= tx_buf[spi_addr_tx];
  end
  reg [7:0] tx_buf [0:2**`SPI_BUF_WIDTH-1];
endmodule

module rx_buf (
  input inclk,
  //input [SPI_BUF_WIDTH-1:0] cont_addr_rx, 
  input spi_we_rx, 
  input [`SPI_BUF_WIDTH-1:0] spi_addr_rx,
  input [7:0] spi_data_rx/*, 
  output reg [7:0] rx_data_fifo*/);

  always @(posedge inclk) begin    // Write reg
    if (spi_we_rx) begin
      rx_buf[spi_addr_rx] <= spi_data_rx;
    end
    //rx_data_fifo <= rx_buf[cont_addr_rx];
  end
  reg [7:0] rx_buf [0:2**`SPI_BUF_WIDTH-1];
endmodule


module controller (
  //SPI-RegFiles
  input inclk,
  input [3:0] spi_addr_reg, 
  output reg [31:0] reg_data_spi, 
  input [31:0] spi_data_reg, 
  input spi_we_reg, 
  //Controller-TX
  output reg [`SPI_BUF_WIDTH-1:0] cont_addr_tx,
  output reg cont_we_tx,/*
  //Controller-RX 
  output reg [SPI_BUF_WIDTH-1:0] cont_addr_rx,*/
  output reg [3:0] cont_cmd_fifo,
  input [15:0] inport,
  output [7:0] state_o,
  output [31:0] reg0_o,
  output [15:0] last_o,
  output [`FIFO_ADDR_WIDTH-1:0] counter_o);

  `define STATE_STANDBY     8'd0
  `define STATE_WAIT_TRIGGER     8'd1
  `define STATE_ACQUIRE     8'd2
  `define STATE_FIFO_TX  8'd3
  `define STATE_WAIT_SPI  8'd4
  `define STATE_SEND_WORD   8'd5
  `define STATE_EXTRA   8'd6

  `define CMD_NONE   32'd0
  `define CMD_WAIT_TRIGGER   32'd1
  `define RESP_ACQ   32'd2
  `define RESP_FIFO_TX   32'd3
  `define RESP_WAITING   32'd4
  `define CMD_NEXT_BUF   32'd5
  `define CMD_COMPLETE   32'd6
  `define CMD_ID   		 32'd7
  
  
  `define FIFO_STANDBY   32'd0
  `define FIFO_CLEARCOUNT   32'd1
  `define FIFO_WAITTRIG   32'd2
  `define FIFO_ACQ   32'd3
  `define FIFO_READOUT   32'd4

  reg [7:0] state;
  
  assign state_o = state;
  
  reg [31:0] reg_bank [0:15];
  
  reg [15:0] last;
  
  assign last_o = last;
  
  assign reg0_o = reg_bank[0];
  
  
  
   
 
  
  initial begin
    state <= `STATE_STANDBY;
    reg_bank[0] <=  `CMD_NONE;
    cont_cmd_fifo <= `FIFO_CLEARCOUNT;
    cont_we_tx <= 0;
    last <= 0;
  end

  reg [`FIFO_ADDR_WIDTH-1:0] counter;
  
  assign counter_o = counter;
  
  always @(posedge inclk) begin   
    reg_data_spi <= reg_bank[spi_addr_reg];
    if (spi_we_reg) begin
      reg_bank[spi_addr_reg] <= spi_data_reg;
    end
  end

  always @(posedge inclk) begin   
   
    
    if (`STATE_STANDBY == state) begin

      if (reg_bank[0] == `CMD_WAIT_TRIGGER) begin
        state <= `STATE_WAIT_TRIGGER;
        cont_cmd_fifo <= `FIFO_WAITTRIG;
        last <= inport;
        counter <= 0;
      end

    end else if (`STATE_WAIT_TRIGGER == state) begin

      if (inport[reg_bank[1][3:0]] == reg_bank[2][0] & last[reg_bank[1][3:0]] == ~reg_bank[2][0]) begin //if inport[bit] == edge
        state <= `STATE_ACQUIRE;
        cont_cmd_fifo <= `FIFO_ACQ;
        cont_we_tx <= 0;
        reg_bank[0] <= `RESP_ACQ;
        counter <= 0;
      end
      last <= inport;

    end else if (`STATE_ACQUIRE == state) begin

      if (counter >= 2**`FIFO_ADDR_WIDTH-2) begin
        state <= `STATE_EXTRA;
        cont_cmd_fifo <= `FIFO_CLEARCOUNT;
        cont_we_tx <= 1;
        cont_addr_tx <= 0;
        reg_bank[0] <= `RESP_FIFO_TX;
        reg_bank[1] <= 16;
        reg_bank[2] <= `FIFO_ADDR_WIDTH;
        counter <= 0;
      end else begin
        counter <= counter + 1;
      end
      
    end else if (`STATE_EXTRA == state) begin
      cont_cmd_fifo <= `FIFO_READOUT;
      cont_addr_tx <= 0;
      counter <= counter + 1;
      if (counter >= 1) begin
        state <= `STATE_FIFO_TX;
      end

    end else if (`STATE_FIFO_TX == state) begin
      
      if (cont_addr_tx >= 2**`SPI_BUF_WIDTH-1) begin
        state <= `STATE_WAIT_SPI;
        cont_cmd_fifo <= `FIFO_STANDBY;
        cont_we_tx <= 0;
        reg_bank[0] = `RESP_WAITING;
      end else begin
        cont_addr_tx <= cont_addr_tx + 1;
      end
      
    end else if (`STATE_WAIT_SPI == state) begin
      if (reg_bank[0] == `CMD_NEXT_BUF) begin 
        state <= `STATE_FIFO_TX;
        cont_cmd_fifo <= `FIFO_READOUT;
        cont_we_tx <= 1;
        cont_addr_tx <= 0;
        reg_bank[0] = `RESP_FIFO_TX;
        reg_bank[1] = 16;
        reg_bank[2] = `FIFO_ADDR_WIDTH;
      end else if (reg_bank[0] == `CMD_COMPLETE) begin
        state <= `STATE_STANDBY;
        reg_bank[0] <=  `CMD_NONE;
        cont_cmd_fifo <= `FIFO_CLEARCOUNT;
        cont_we_tx <= 0;
      end
    end

  end
  
endmodule




module fifo 
(
  input inclk,
  //input [7:0] rx_data_fifo,
  output reg [7:0] fifo_data_tx,
  input [3:0] cont_cmd_fifo,
  input [15:0] inport,
  output [`FIFO_ADDR_WIDTH-1:0] fifo_addr_o,
  output fifo_subaddr_o
);

  
  `define FIFO_STANDBY   32'd0
  `define FIFO_CLEARCOUNT   32'd1
  `define FIFO_WAITTRIG   32'd2
  `define FIFO_ACQ   32'd3
  `define FIFO_READOUT   32'd4
  
  // Declare the RAM variable
  reg [15:0] sram[2**`FIFO_ADDR_WIDTH-1:0];

  // Variable to hold the registered read address
  reg [`FIFO_ADDR_WIDTH-1:0] addr_reg;

  reg sub_addr;
  reg [1:0] step;

  assign fifo_subaddr_o = sub_addr;
  assign fifo_addr_o = addr_reg;
  // Specify the initial contents.  You can also use the $readmemb
  // system task to initialize the RAM variable from a text file.
  // See the $readmemb template page for details.
  initial 
  begin
    addr_reg <= 0;
  	sub_addr <= 1;
    step <= 0;
  end 

  always @ (posedge inclk) begin
    // Write
    if (cont_cmd_fifo == `FIFO_CLEARCOUNT) begin
      addr_reg <= 0;
      sub_addr <= 0;
      step <= 0;
    end
    if (cont_cmd_fifo == `FIFO_WAITTRIG) begin 
      sram[0] <= inport;
      addr_reg <= 1;
    end
    if (cont_cmd_fifo == `FIFO_ACQ) begin 
      sram[addr_reg] <= inport;
      addr_reg <= addr_reg + 1;
    end
    if (cont_cmd_fifo == `FIFO_READOUT) begin
      if (step == 0) begin
        sub_addr <= 0;
        fifo_data_tx <= sram[addr_reg][15:8];
        step <= 1;
      end else if (step == 1) begin
        sub_addr <= 1;
        fifo_data_tx <= sram[addr_reg][7:0];
        addr_reg <= addr_reg + 1;
        step <= 2;
      end else if (step == 2) begin
        sub_addr <= 0;
        fifo_data_tx <= sram[addr_reg][15:8];
        step <= 3;
      end else if (step == 3) begin
        sub_addr <= 1;
        fifo_data_tx <= sram[addr_reg][7:0];
        addr_reg <= addr_reg + 1;
        step <= 0;
      end
    end
        
        
  end
  

endmodule

module spiifc(
  Reset,
  SysClk,
  SPI_CLK,
  SPI_MISO,
  SPI_MOSI,
  SPI_SS,
  txMemAddr,
  txMemData,
  rcMemAddr,
  rcMemData,
  rcMemWE,
  regAddr,
  regReadData,
  regWriteEn,
  regWriteData,
  debug_out
);

//
// Parameters
//
parameter AddrBits = `SPI_BUF_WIDTH;
parameter RegAddrBits = 4;

//
// Defines
//
`define CMD_READ_START    8'd1
`define CMD_READ_MORE     8'd2
`define CMD_WRITE_START   8'd3
`define CMD_WRITE_MORE    8'd4
`define CMD_INTERRUPT     8'd5

`define CMD_REG_BASE      8'd128
`define CMD_REG_BIT       7
`define CMD_REG_WE_BIT    6
`define CMD_REG_ID_MASK   8'h3F

`define STATE_GET_CMD     8'd0
`define STATE_READING     8'd1
`define STATE_WRITING     8'd2
`define STATE_WRITE_INTR  8'd3
`define STATE_BUILD_WORD  8'd4
`define STATE_SEND_WORD   8'd5

//
// Input/Outputs
//
input                    Reset;
input                    SysClk;

input                    SPI_CLK;
output                   SPI_MISO;     // outgoing (from respect of this module)
input                    SPI_MOSI;     // incoming (from respect of this module)
input                    SPI_SS;

output [AddrBits-1:0]    txMemAddr;    // outgoing data
input           [7:0]    txMemData;
output [AddrBits-1:0]    rcMemAddr;    // incoming data
output          [7:0]    rcMemData;
output                   rcMemWE;

output [RegAddrBits-1:0] regAddr;       // Register read address (combinational)
input             [31:0] regReadData;   // Result of register read
output                   regWriteEn;    // Enable write to register, otherwise read
output            [31:0] regWriteData;  // Register write data


output          [7:0] debug_out;

//
// Registers
//
reg                   SPI_CLK_reg;    // Stabalized version of SPI_CLK
reg                   SPI_SS_reg;     // Stabalized version of SPI_SS
reg                   SPI_MOSI_reg;   // Stabalized version of SPI_MOSI

reg                   prev_spiClk;    // Value of SPI_CLK during last SysClk cycle
reg                   prev_spiSS;     // Value of SPI_SS during last SysClk cycle
reg             [7:0] state_reg;      // Register backing the 'state' wire
reg             [7:0] rcByte_reg;     // Register backing 'rcByte'
reg             [2:0] rcBitIndex_reg; // Register backing 'rcBitIndex'
reg    [AddrBits-1:0] rcMemAddr_reg;  // Byte addr to write MOSI data to
reg             [7:0] debug_reg;      // register backing debug_out signal
reg             [2:0] txBitIndex_reg; // Register backing txBitIndex
reg    [AddrBits-1:0] txMemAddr_reg;  // Register backing txAddr

reg             [7:0] command;        // Command being handled
reg            [31:0] rcWord;         // Incoming word being built
reg             [1:0] rcWordByteId;   // Which byte the in the rcWord to map to
reg [RegAddrBits-1:0] regAddr_reg;    // Address of register to read/write to

//
// Wires
//
wire                  risingSpiClk;       // Did the SPI_CLK rise since last SysClk cycle?
wire                  validSpiBit;        // Are the SPI MOSI/MISO bits new and valid?
reg             [7:0] state;              // Current state in the module's state machine (always @* effectively wire)
wire                  rcByteValid;        // rcByte is valid and new
wire            [7:0] rcByte;             // Byte received from master
wire            [2:0] rcBitIndex;         // Bit of rcByte to write to next
reg             [2:0] txBitIndex;         // bit of txByte to send to master next
reg    [AddrBits-1:0] txMemAddr_oreg;     // Wirereg piped to txMemAddr output
reg             [7:0] regReadByte_oreg;   // Which byte of the reg word we're reading out master
wire packetStart;
// Save buffered SPI inputs
always @(posedge SysClk) begin
  SPI_CLK_reg <= SPI_CLK;
  SPI_SS_reg <= SPI_SS;
  SPI_MOSI_reg <= SPI_MOSI;
end

// Detect new valid bit
always @(posedge SysClk) begin
  prev_spiClk <= SPI_CLK_reg;
end
assign risingSpiClk = SPI_CLK_reg & (~prev_spiClk);
assign validSpiBit = risingSpiClk & (~SPI_SS_reg);

// Detect new SPI packet (SS dropped low)
always @(posedge SysClk) begin
  prev_spiSS <= SPI_SS_reg;
end
assign packetStart = prev_spiSS & (~SPI_SS_reg);

// Build incoming byte
always @(posedge SysClk) begin
  if (validSpiBit) begin
    rcByte_reg[rcBitIndex] <= SPI_MOSI_reg;
    rcBitIndex_reg <= (rcBitIndex > 0 ? rcBitIndex - 1 : 7);
  end else begin
    rcBitIndex_reg <= rcBitIndex;
  end
end
assign rcBitIndex = (Reset || packetStart ? 7 : rcBitIndex_reg); 
assign rcByte = {rcByte_reg[7:1], SPI_MOSI_reg};
assign rcByteValid = (validSpiBit && rcBitIndex == 0 ? 1 : 0);

// Incoming MOSI data buffer management
assign rcMemAddr = rcMemAddr_reg;
assign rcMemData = rcByte;
assign rcMemWE = (state == `STATE_READING && rcByteValid ? 1 : 0);
always @(posedge SysClk) begin
  if (Reset || (`STATE_GET_CMD == state && rcByteValid)) begin
    rcMemAddr_reg <= 0;
  end else if (rcMemWE) begin
    rcMemAddr_reg <= rcMemAddr + 1;
  end else begin
    rcMemAddr_reg <= rcMemAddr;
  end
end

// Outgoing MISO data buffer management
always @(*) begin
  if (Reset || (state == `STATE_GET_CMD && rcByteValid && 
                  (rcByte == `CMD_WRITE_START || 
                   rcByte[`CMD_REG_BIT:`CMD_REG_WE_BIT] == 2'b11)
                )) begin
    txBitIndex <= 3'd7;
    txMemAddr_oreg <= 0;
  end else begin
    txBitIndex <= txBitIndex_reg;

    //txMemAddr_oreg <= txMemAddr_reg;
    if ((state == `STATE_WRITING || state == `STATE_SEND_WORD) && 
        validSpiBit && txBitIndex == 0) begin
      txMemAddr_oreg <= txMemAddr_reg + 1;
    end else begin
      txMemAddr_oreg <= txMemAddr_reg;
    end
    
  end
end
always @(posedge SysClk) begin
  if (validSpiBit && (state == `STATE_WRITING || state == `STATE_SEND_WORD)) begin
    txBitIndex_reg <= (txBitIndex == 0 ? 7 : txBitIndex - 1);
  end else begin
    txBitIndex_reg <= txBitIndex;
  end

  txMemAddr_reg <= txMemAddr;
//  if (state == `STATE_WRITING && validSpiBit && txBitIndex == 0) begin
//    txMemAddr_reg <= txMemAddr + 1;
//  end else begin
//    txMemAddr_reg <= txMemAddr;  
//  end
end
assign txMemAddr = txMemAddr_oreg;
assign SPI_MISO = (state == `STATE_SEND_WORD ? regReadByte_oreg[txBitIndex] : txMemData[txBitIndex]);

// State machine
always @(*) begin
  if (Reset || packetStart) begin
    state <= `STATE_GET_CMD;
// Handled in state_reg logic, should be latched, not immediate.
//  end else if (state_reg == `STATE_GET_CMD && rcByteValid) begin
//    state <= rcByte;
  end else begin
    state <= state_reg;
  end
end
always @(posedge SysClk) begin
  if (`STATE_GET_CMD == state && rcByteValid) begin
    if (`CMD_READ_START == rcByte) begin
      state_reg <= `STATE_READING;
    end else if (`CMD_READ_MORE == rcByte) begin
      state_reg <= `STATE_READING;
    end else if (`CMD_WRITE_START == rcByte) begin
      state_reg <= `STATE_WRITING;
    end else if (`CMD_WRITE_MORE == rcByte) begin
      state_reg <= `STATE_WRITING;
    end else if (rcByte[`CMD_REG_BIT] != 0) begin
      // Register access
      rcWordByteId <= 0;
      command <= `CMD_REG_BASE;               // Write reg           Read reg
      state_reg <= (rcByte[`CMD_REG_WE_BIT] ? `STATE_BUILD_WORD : `STATE_SEND_WORD);      
    end else if (`CMD_INTERRUPT == rcByte) begin
      // TODO: NYI
    end
  end else if (`STATE_BUILD_WORD == state && rcByteValid) begin
    if (0 == rcWordByteId) begin
      rcWord[31:24] <= rcByte;
      rcWordByteId <= 1;
    end else if (1 == rcWordByteId) begin
      rcWord[23:16] <= rcByte;
      rcWordByteId <= 2;
    end else if (2 == rcWordByteId) begin
      rcWord[15:8] <= rcByte;
      rcWordByteId <= 3;
    end else if (3 == rcWordByteId) begin
      rcWord[7:0] <= rcByte;
      state_reg <= `STATE_GET_CMD;
    end
  end else if (`STATE_SEND_WORD == state && rcByteValid) begin
    rcWordByteId <= rcWordByteId + 1;
    state_reg <= (rcWordByteId == 3 ? `STATE_GET_CMD : `STATE_SEND_WORD);
      
  end else begin
    state_reg <= state;
  end
end

// Register logic
assign regAddr = (`STATE_GET_CMD == state && rcByteValid && rcByte[`CMD_REG_BIT] ? (rcByte & `CMD_REG_ID_MASK) : regAddr_reg);
assign regWriteEn = (`STATE_BUILD_WORD == state && rcByteValid && 3 == rcWordByteId ? 1 : 0);
assign regWriteData = {rcWord[31:8], rcByte};
always @(posedge SysClk) begin
  regAddr_reg <= regAddr;
end
always @(*) begin
  case (rcWordByteId)
    0: regReadByte_oreg <= regReadData[31:24];
    1: regReadByte_oreg <= regReadData[23:16];
    2: regReadByte_oreg <= regReadData[15:8];
    3: regReadByte_oreg <= regReadData[7:0];
  endcase
end

// Debugging
always @(posedge SysClk) begin
  if (rcByteValid) begin
    debug_reg <= rcByte;
  end
end
assign debug_out = debug_reg;

endmodule