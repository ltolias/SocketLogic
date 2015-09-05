


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
`define CMD_TRIG_SET_TRIGON     8'd9

`define FMT_PAR   2'd0
`define FMT_EDGE    2'd1
`define FMT_SER   2'd2

`define STATE_SYS_STANDBY   8'd0
`define STATE_SYS_RUN     8'd1
`define STATE_SYS_FIRED   8'd2



module trigger_system(inclk,command,config_in,inport,trig,we);
  
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
  
  
  initial begin
    state <= 0;
    step <= 0;
    trig <= 0;
    t_last <= 0;
    trig_on <= 3;
  end

  always @(posedge inclk) 
  begin
    if (command == `CMD_TRIG_RUN)
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
    end else if (command == `CMD_TRIG_SET_TRIGON) 
    begin
      trig_on <= config_in[23:16];
    end
  end    
  
  
  
endmodule


 


module trigger_stage(inclk, command, config_in, inport, step, triggered, we); 
  
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
  
  shift_delay shift_delay_inst(shift_clk, shift_in, PO, cycle_delay); 
  
  initial begin
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
  end

  always @(posedge inclk) 
  begin
    if (step == arm_on_step+1) begin
      state <= `STATE_TRIG_FIRED;
    end else if (command == `CMD_TRIG_RUN)
    begin
      if (state == `STATE_TRIG_STANDBY) begin
        occur <= 0;
        dcount <= 0;
        if (step == arm_on_step) begin 
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
        end else if (command == `CMD_TRIG_SET_EVALUE) begin
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
          

module shift_delay(C, SI, PO, cycle_delay); 
  input  C,SI; 
  input [6:0] cycle_delay;
  reg [6:0] count;
  output [15:0] PO; 
  reg [15:0] tmp; 
  initial begin
      count = 0;
  end
  always @(posedge C) 
  begin 
    if (count == cycle_delay)
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


