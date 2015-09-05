// Quartus II Verilog Template
// Single port RAM with single read/write address and initial contents 
// specified with an initial block


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


`define CMD_TRIG_RUN        8'd0
`define CMD_TRIG_RESET      8'd1
`define CMD_TRIG_HALT       8'd2
`define CMD_TRIG_SETUP      8'd3
`define CMD_TRIG_ARM_ON_STEP    8'd4
`define CMD_TRIG_SET_VALUE    8'd5
`define CMD_TRIG_SET_RANGE    8'd6
`define CMD_TRIG_SET_VMASK    8'd7
`define CMD_TRIG_SET_EDGE     8'd8
`define CMD_TRIG_SET_EMASK    8'd9
`define CMD_TRIG_SET_CONFIG   8'd10
`define CMD_TRIG_SET_SERIALOPTS 8'd11


`define FIFO_STANDBY    32'd0
`define FIFO_CLEARCOUNT   32'd1
`define FIFO_WAITTRIG     32'd2
`define FIFO_ACQ      32'd3
`define FIFO_READOUT    32'd4



//fifo_addr_width must be >= SPI_BUF_WIDTH-1 and integer multiple

module instrument (
  //input clk_reset,
  input inclk,
  input [15:0] inport,
  input SPI_CLK,
  input SPI_MOSI,
  output SPI_MISO,
  input SPI_SS,
  input Reset
); 
  
  wire [3:0] spi_addr_reg;
  wire [31:0] reg_data_spi;
  wire [31:0] spi_data_reg; 
  wire spi_we_reg;
  
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
  
  
  wire [23:0] cont_config_trig;
  wire [7:0] cont_command_trig;
  wire [3:0] cont_we_trig;
  wire trig_trigger_cont;
  
  wire [7:0] debug_out;
  
  

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
    cont_config_trig,
    cont_command_trig,
    cont_we_trig,
    trig_trigger_cont,
    cont_reset_spi);


  
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
    inport);
  
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
  
  
  trigger_system tsys_inst(
    inclk,
    cont_command_trig,
    cont_config_trig,
    inport,
    trig_trigger_cont,
    cont_we_trig);
  
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
  output reg [23:0] cont_config_trig,
  output reg [7:0] cont_command_trig,
  output reg [3:0] cont_we_trig,
  input trig_trigger_cont,
  output reg cont_reset_spi);

  `define STATE_STANDBY       8'd0
  `define STATE_WAIT_TRIGGER    8'd1
  `define STATE_ACQUIRE       8'd2
  `define STATE_FIFO_TX     8'd3
  `define STATE_WAIT_SPI      8'd4
  `define STATE_SEND_WORD     8'd5
  `define STATE_EXTRA       8'd6


  reg [7:0] state;
  
  
  reg [31:0] reg_bank [0:15];
  
  reg [15:0] last;
  
  


  reg [`FIFO_ADDR_WIDTH-1:0] counter;
  
  
  always @(posedge inclk) begin   
    reg_data_spi <= reg_bank[spi_addr_reg];
    if (spi_we_reg) begin
      reg_bank[spi_addr_reg] <= spi_data_reg;
    end
  end
  
  
  
  always @(posedge inclk) begin   
    if (reg_bank[0] == `CMD_RESET) begin
      //reset all
      state <= `STATE_STANDBY;
      cont_cmd_fifo <= `FIFO_CLEARCOUNT;
      cont_we_tx <= 0;
      last <= 0;
      cont_config_trig <= 0;
      cont_command_trig <= `CMD_TRIG_RESET;
      cont_we_trig <= 0;
      state <= `STATE_STANDBY;
      cont_cmd_fifo <= `FIFO_CLEARCOUNT;
      cont_reset_spi <= 1;
      reg_bank[1] <= `RESP_RESET;
      
    end else if (reg_bank[0] == `CMD_INIT) begin
      reg_bank[1] <= `RESP_INIT;
      cont_reset_spi <= 0;
      cont_command_trig <= `CMD_TRIG_HALT;
      
    end else if (reg_bank[0] == `CMD_NONE) begin
      reg_bank[1] <= `RESP_NONE;
      
    end else if (reg_bank[0] == `CMD_ARM_ON_STEP && reg_bank[1] != `RESP_ARM_ON_STEP) begin
      if (cont_command_trig == `CMD_TRIG_HALT) begin
        cont_config_trig <= reg_bank[2][23:0];
        cont_command_trig <= `CMD_TRIG_SETUP;
      end else if (cont_command_trig == `CMD_TRIG_SETUP) begin
        cont_command_trig <= `CMD_TRIG_ARM_ON_STEP;
      end else begin
        cont_command_trig <= `CMD_TRIG_HALT;
        reg_bank[1] <= `RESP_ARM_ON_STEP;
      end
      
    end else if (reg_bank[0] == `CMD_SET_VALUE && reg_bank[1] != `RESP_SET_VALUE) begin
      if (cont_command_trig == `CMD_TRIG_HALT) begin
        cont_we_trig[reg_bank[2][31:24]] <= 1;
        cont_config_trig <= reg_bank[2][23:0];
        cont_command_trig <= `CMD_TRIG_SETUP;
      end else if (cont_command_trig == `CMD_TRIG_SETUP) begin
        cont_command_trig <= `CMD_TRIG_SET_VALUE;
      end else begin
        cont_command_trig <= `CMD_TRIG_HALT;
        cont_we_trig <= 0;
        reg_bank[1] <= `RESP_SET_VALUE;
      end
      
    end else if (reg_bank[0] == `CMD_SET_RANGE && reg_bank[1] != `RESP_SET_RANGE) begin
      if (cont_command_trig == `CMD_TRIG_HALT) begin
        cont_we_trig[reg_bank[2][31:24]] <= 1;
        cont_config_trig <= reg_bank[2][23:0];
        cont_command_trig <= `CMD_TRIG_SETUP;
      end else if (cont_command_trig == `CMD_TRIG_SETUP) begin
        cont_command_trig <= `CMD_TRIG_SET_RANGE;
      end else begin
        cont_command_trig <= `CMD_TRIG_HALT;
        cont_we_trig <= 0;
        reg_bank[1] <= `RESP_SET_RANGE;
      end
      
    end else if (reg_bank[0] == `CMD_SET_VMASK && reg_bank[1] != `RESP_SET_VMASK) begin
      if (cont_command_trig == `CMD_TRIG_HALT) begin
        cont_we_trig[reg_bank[2][31:24]] <= 1;
        cont_config_trig <= reg_bank[2][23:0];
        cont_command_trig <= `CMD_TRIG_SETUP;
      end else if (cont_command_trig == `CMD_TRIG_SETUP) begin
        cont_command_trig <= `CMD_TRIG_SET_VMASK;
      end else begin
        cont_command_trig <= `CMD_TRIG_HALT;
        cont_we_trig <= 0;
        reg_bank[1] <= `RESP_SET_VMASK;
      end
      
    end else if (reg_bank[0] == `CMD_SET_EDGE && reg_bank[1] != `RESP_SET_EDGE) begin
      if (cont_command_trig == `CMD_TRIG_HALT) begin
        cont_we_trig[reg_bank[2][31:24]] <= 1;
        cont_config_trig <= reg_bank[2][23:0];
        cont_command_trig <= `CMD_TRIG_SETUP;
      end else if (cont_command_trig == `CMD_TRIG_SETUP) begin
        cont_command_trig <= `CMD_TRIG_SET_EDGE;
      end else begin
        cont_command_trig <= `CMD_TRIG_HALT;
        cont_we_trig <= 0;
        reg_bank[1] <= `RESP_SET_EDGE;
      end
      
    end else if (reg_bank[0] == `CMD_SET_EMASK && reg_bank[1] != `RESP_SET_EMASK) begin
      if (cont_command_trig == `CMD_TRIG_HALT) begin
        cont_we_trig[reg_bank[2][31:24]] <= 1;
        cont_config_trig <= reg_bank[2][23:0];
        cont_command_trig <= `CMD_TRIG_SETUP;
      end else if (cont_command_trig == `CMD_TRIG_SETUP) begin
        cont_command_trig <= `CMD_TRIG_SET_EMASK;
      end else begin
        cont_command_trig <= `CMD_TRIG_HALT;
        cont_we_trig <= 0;
        reg_bank[1] <= `RESP_SET_EMASK;
      end
      
    end else if (reg_bank[0] == `CMD_SET_CONFIG && reg_bank[1] != `RESP_SET_CONFIG) begin
      if (cont_command_trig == `CMD_TRIG_HALT) begin
        cont_we_trig[reg_bank[2][31:24]] <= 1;
        cont_config_trig <= reg_bank[2][23:0];
        cont_command_trig <= `CMD_TRIG_SETUP;
      end else if (cont_command_trig == `CMD_TRIG_SETUP) begin
        cont_command_trig <= `CMD_TRIG_SET_CONFIG;
      end else begin
        cont_command_trig <= `CMD_TRIG_HALT;
        cont_we_trig <= 0;
        reg_bank[1] <= `RESP_SET_CONFIG;
      end
      
    end else if (reg_bank[0] == `CMD_SET_SERIALOPTS && reg_bank[1] != `RESP_SET_SERIALOPTS) begin
      if (cont_command_trig == `CMD_TRIG_HALT) begin
        cont_we_trig[reg_bank[2][31:24]] <= 1;
        cont_config_trig <= reg_bank[2][23:0];
        cont_command_trig <= `CMD_TRIG_SETUP;
      end else if (cont_command_trig == `CMD_TRIG_SETUP) begin
        cont_command_trig <= `CMD_TRIG_SET_SERIALOPTS;
      end else begin
        cont_command_trig <= `CMD_TRIG_HALT;
        cont_we_trig <= 0;
        reg_bank[1] <= `RESP_SET_SERIALOPTS;
      end
      
    end else if (`STATE_STANDBY == state) begin
      if (reg_bank[0] == `CMD_WAIT_TRIGGER) begin
        state <= `STATE_WAIT_TRIGGER;
        cont_cmd_fifo <= `FIFO_WAITTRIG;
        last <= inport;
        counter <= 0;
        cont_command_trig <= `CMD_TRIG_RUN;
      end
      
    end else if (`STATE_WAIT_TRIGGER == state) begin

      if (trig_trigger_cont) begin //if inport[bit] == edge
        state <= `STATE_ACQUIRE;
        cont_cmd_fifo <= `FIFO_ACQ;
        cont_we_tx <= 0;
        reg_bank[1] <= `RESP_ACQ;
        counter <= 0;
      end
      last <= inport;

    end else if (`STATE_ACQUIRE == state) begin

      if (counter >= 2**`FIFO_ADDR_WIDTH-2) begin
        state <= `STATE_EXTRA;
        cont_cmd_fifo <= `FIFO_CLEARCOUNT;
        cont_we_tx <= 1;
        cont_addr_tx <= 0;
        reg_bank[1] <= `RESP_FIFO_TX;
        reg_bank[2] <= 16;
        reg_bank[3] <= `FIFO_ADDR_WIDTH;
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
        reg_bank[1] = `RESP_WAITING;
      end else begin
        cont_addr_tx <= cont_addr_tx + 1;
      end
      
    end else if (`STATE_WAIT_SPI == state) begin
      if (reg_bank[0] == `CMD_NEXT_BUF) begin 
        state <= `STATE_FIFO_TX;
        cont_cmd_fifo <= `FIFO_READOUT;
        cont_we_tx <= 1;
        cont_addr_tx <= 0;
        reg_bank[1] = `RESP_FIFO_TX;
        reg_bank[2] = 16;
        reg_bank[3] = `FIFO_ADDR_WIDTH;
      end else if (reg_bank[0] == `CMD_COMPLETE) begin
        state <= `STATE_STANDBY;
        reg_bank[1] <=  `RESP_DONE;
        cont_cmd_fifo <= `FIFO_CLEARCOUNT;
        cont_we_tx <= 0;
      end
    end

  end
  
endmodule


module trigger_system(inclk,command,config_in,inport,trig,we);
  
  


  `define STATE_SYS_STANDBY   8'd0
  `define STATE_SYS_RUN     8'd1
  `define STATE_SYS_FIRED   8'd2


  
  input [23:0] config_in;
  input [7:0] command;
  input [3:0] we;
  
  
  reg [3:0] t_last;
  
  input inclk;
  input [15:0] inport;

  
  reg [7:0] state;
  reg [7:0] trig_on;
  
  reg [7:0] step;
  
  output reg trig;
  
  wire [3:0] triggered;
  
  genvar index;  
  generate  
    for (index=0; index < 4; index=index+1)  
    begin: gen_t_stages  
      trigger_stage trigger_gen(inclk, command, config_in, inport, step, triggered[index], we[index]);
    end  
  endgenerate 

  always @(posedge inclk) 
  begin
    if (command == `CMD_TRIG_RESET) begin
      state <= `STATE_SYS_STANDBY;
      step <= 0;
      trig <= 0;
      t_last <= 0;
      trig_on <= 0;
    end else if (command == `CMD_TRIG_RUN)
    begin
      if (state == `STATE_SYS_STANDBY) begin
        step <= 1;
        t_last <= triggered;
        state <= `STATE_SYS_RUN;
      end else if (state == `STATE_SYS_RUN) begin
        if (t_last != triggered)
        begin
          t_last <= triggered;
          step <= step + 1;
          if (step+1 == trig_on) begin
            state <= `STATE_SYS_FIRED;
            trig <= 1;
          end
        end else begin
          t_last <= triggered;
        end
      end
    end else if (command == `CMD_TRIG_ARM_ON_STEP) 
    begin
      trig_on <= config_in[23:16];
    end
  end    
  
  
  
endmodule


 


module trigger_stage(inclk, command, config_in, inport, step, triggered, we); 
  
  
    
  `define FMT_PAR   2'd0
  `define FMT_EDGE  2'd1
  `define FMT_SER   2'd2

  `define STATE_TRIG_STANDBY  8'd0
  `define STATE_TRIG_ARMED    8'd1
  `define STATE_TRIG_DELAY    8'd2
  `define STATE_TRIG_FIRED    8'd3


  
  input [23:0] config_in;
  input [7:0] command;
  input we;
  
  reg [7:0] arm_on_step;
  reg [15:0] delay;
  reg [15:0] vmask;
  reg [15:0] value;
  reg [15:0] evalue;
  reg [15:0] emask;
  reg [15:0] range_top;
  reg [7:0] repetitions;
  reg [3:0] data_ch;
  reg [4:0] clock_ch;
  reg [6:0] cycle_delay;
  reg [1:0] format;
  reg range;
  
  reg [15:0] last;
  
  input inclk;
  input [15:0] inport;
  
  reg [7:0] occur;
  reg [15:0] dcount;
  
  input [7:0] step;

  reg [7:0] state;
  
  output reg triggered;
  
  wire shift_clk;
  wire shift_in;
  
  assign shift_clk = (~clock_ch[4]) ? inclk:inport[clock_ch[3:0]];
  assign shift_in = inport[data_ch];
  
  wire e_trig;
  wire v_trig;
  wire r_trig;
  wire sv_trig;
  wire sr_trig;
  wire s_trig;
  
  wire xx;
  wire yy;
  
  assign xx = value & vmask;
  assign yy = vmask & inport;
  
  
  assign e_trig = ((~evalue & emask) == (emask & last)) && ((evalue & emask) == (emask & inport));
  assign v_trig = ~range && ((value & vmask) == (vmask & inport));
  assign r_trig = range && ((value & vmask) <= (vmask & inport)) && ((range_top & vmask) >= (vmask & inport));
  
  assign sv_trig = ~range && ((value & vmask) == (vmask & PO));
  assign sr_trig =  range && ((value & vmask) <= (vmask & PO)) && ((range_top & vmask) >= (vmask & PO));
  
  assign s_trig = ((format == `FMT_SER) && (sv_trig || sr_trig));
  
  wire [15:0] PO;
  
  reg reset_shift;
 
  shift_delay shift_delay_inst(shift_clk, shift_in, PO, cycle_delay, reset_shift); 

  always @(posedge inclk) 
  begin
    if (command == `CMD_TRIG_RESET) begin
      state <= `STATE_TRIG_STANDBY;
      arm_on_step <= 0;
      delay <= 0;
      vmask <= 0;
      value <= 0;
      evalue <= 0;
      emask <= 0;
      range_top <= 0;
      repetitions <= 0;
      data_ch <= 0;
      clock_ch <= 0;
      cycle_delay <= 0;
      format <= 0;
      range <= 0;
      last <= 0;
      occur <= 0;
      dcount <= 0;
      triggered <= 0;
      reset_shift <= 1;
    end else if (step == arm_on_step+1) begin
      state <= `STATE_TRIG_FIRED;
    end else if (command == `CMD_TRIG_RUN)
    begin
      if (state == `STATE_TRIG_STANDBY) begin
        occur <= 0;
        dcount <= 0;
        if (step == arm_on_step) begin
          reset_shift <= 0;
          state <= `STATE_TRIG_ARMED;
          last <= inport;
        end
      end else if (state == `STATE_TRIG_ARMED) begin
        if ((v_trig || r_trig || s_trig) &&   ((format == `FMT_PAR) || ((format == `FMT_EDGE) && e_trig) || s_trig))
        begin
          occur <= occur + 1;
          if (delay > 0) begin
              state <= `STATE_TRIG_DELAY;
              dcount <= 0;
          end else if (occur == repetitions) begin
              state <= `STATE_TRIG_FIRED;
              triggered <= 1;
          end 
        end else begin
          last <= inport;
        end
      end else if (state == `STATE_TRIG_DELAY) begin
        dcount <= dcount + 1;
        if (dcount == delay) begin
          if (occur == repetitions) begin
            state <= `STATE_TRIG_FIRED;
            reset_shift <= 1;
            triggered <= 1;
          end else begin
            last <= inport;
            state <= `STATE_TRIG_ARMED;
          end
        end
      end
    end else 
    begin
      if (we) begin
        if (command == `CMD_TRIG_SET_VALUE) begin
          value <= config_in[23:8];
          repetitions <= config_in[7:0];
        end else if (command == `CMD_TRIG_SET_RANGE) begin
          range_top <= config_in[23:8];
        end else if (command == `CMD_TRIG_SET_VMASK) begin
          vmask <= config_in[23:8];
          arm_on_step <= config_in[7:0];
        end else if (command == `CMD_TRIG_SET_EDGE) begin
          evalue <= config_in[23:8];
        end else if (command == `CMD_TRIG_SET_EMASK) begin
          emask <= config_in[23:8];
        end else if (command == `CMD_TRIG_SET_CONFIG) begin
          delay <= config_in[23:8];
          format <= config_in[7:6];
          range <= config_in[5];  
        end else if (command == `CMD_TRIG_SET_SERIALOPTS) begin
          data_ch <= config_in[23:20];
          clock_ch <= config_in[19:15];
          cycle_delay <= config_in[6:0]; 
        end
      end
    end
  end         
    
endmodule
          

module shift_delay(C, SI, PO, cycle_delay, reset); 
  input  C,SI; 
  input [6:0] cycle_delay;
  reg [6:0] count;
  output [15:0] PO; 
  reg [15:0] tmp; 
  input reset;
  
  initial begin
      count = 0;
  end
  always @(posedge C) 
  begin 
    if (reset) begin
      count <= 0;
      tmp <= 0; 
    end else if (count == cycle_delay)
    begin
      count <= 0;
      tmp <= {tmp[14:0], SI}; 
    end else
    begin
      count <= count + 1;
    end
  end 
  assign PO = tmp; 
endmodule 






module fifo 
(
  input inclk,
  //input [7:0] rx_data_fifo,
  output reg [7:0] fifo_data_tx,
  input [3:0] cont_cmd_fifo,
  input [15:0] inport
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