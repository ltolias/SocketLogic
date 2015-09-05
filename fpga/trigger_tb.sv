// Code your testbench here
// or browse Examples
// Testbench
`define SPI_BUF_WIDTH 4
`define FIFO_ADDR_WIDTH 5

`define STATE_TRIG_STANDBY  8'd0
`define STATE_TRIG_ARMED  8'd1
`define STATE_TRIG_DELAY    8'd2
`define STATE_TRIG_FIRED    8'd3

`define CMD_TRIG_RUN          8'd0
`define CMD_TRIG_HALT         8'd1
`define CMD_TRIG_SET_VALUE      8'd2
`define CMD_TRIG_SET_VMASK      8'd3
`define CMD_TRIG_SET_EVALUE     8'd4
`define CMD_TRIG_SET_EMASK      8'd5
`define CMD_TRIG_SET_RANGE      8'd6
`define CMD_TRIG_SET_CONFIG     8'd7
`define CMD_TRIG_SET_SERIALOPTS   8'd8

`define TYPE_PAR    1'd0
`define TYPE_SER    1'd1
 

module test;
  
  reg a_inclk;
  reg [7:0] b_command;
  reg [23:0] c_config_in;
  reg [15:0] d_inport;

  
  wire e_triggered;
  //wire gg_triggered;
  
  reg [3:0] f_we;
  //reg hh_we;
  
  //reg [7:0] xx_step;
  

 
  
  //trigger_stage trigger_inst(a_inclk, b_command, c_config_in, d_inport, xx_step, gg_triggered, hh_we);
    
  
  
  trigger_system sys_inst(a_inclk, b_command, c_config_in, d_inport, e_triggered, f_we);
  initial begin 
    forever begin
      #1 a_inclk = ~a_inclk; 
    end
  end
  /*initial begin
    forever begin
      #2 d_inport = d_inport + 1; 
    end
  end*/
  
  reg [15:0] i;

  initial begin
    // Dump waves
    $dumpfile("dump.vcd");
    $dumpvars(0, test);
    //$dumpvars(1, sys_inst);
    $dumpvars(1); 
    $display("Testing");
    a_inclk = 1;
    d_inport = 16'd2;
    
    /*hh_we = 1;
    
    xx_step = 0;

    c_config_in = 24'd0;
    b_command = 8'd1;
    #10;
    c_config_in = (0 << 8);
    #2;
    b_command = `CMD_TRIG_SET_VALUE;
    #2;
    b_command = `CMD_TRIG_HALT;
    #2
    c_config_in = (2 << 8);
    #2;
    b_command = `CMD_TRIG_SET_VMASK;
    #2;
    b_command = `CMD_TRIG_HALT;
    #10;
    b_command = `CMD_TRIG_RUN;
    
    #30;
    d_inport = 16'd1;
    #30;*/
    d_inport = 16'd1;
    f_we = (1 << 0);

    c_config_in = 24'd0;
    b_command = 8'd1;
    #10;
    c_config_in = (1 << 8);
    #2;
    b_command = `CMD_TRIG_SET_EVALUE;
    #2;
    b_command = `CMD_TRIG_HALT;
    #2
    c_config_in = (0 << 8) | 1;
    #2;
    b_command = `CMD_TRIG_SET_VMASK;
    #2;
    b_command = `CMD_TRIG_HALT;
    #2
    c_config_in = (1 << 8) | 1;
    #2;
    b_command = `CMD_TRIG_SET_EMASK;
    #2;
    b_command = `CMD_TRIG_HALT;
    #2;
    c_config_in = (1 << 6);
    #2;
    b_command = `CMD_TRIG_SET_CONFIG;
    #2;
    b_command = `CMD_TRIG_HALT;
    #2;
    f_we = (1 << 1);
    c_config_in = (2 << 8);
    #2;
    b_command = `CMD_TRIG_SET_VALUE;
    #2;
    b_command = `CMD_TRIG_HALT;
    #2;
    c_config_in = (2 << 8) | 2;
    #2;
    b_command = `CMD_TRIG_SET_VMASK;
    #2
    b_command = `CMD_TRIG_RUN;
    
    
    
    #15;
    d_inport = 16'd0;
    #14;
    d_inport = 16'd1;

    
    #14;
    
    d_inport = 16'd2;
    
    #20;
    
    
    
    
    $finish;

    
  end
  

  
endmodule