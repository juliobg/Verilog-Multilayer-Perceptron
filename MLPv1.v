`timescale 1ns/10ps
`define EOF 32'hFFFF_FFFF

module MLP ();
reg clk;
reg reset;
reg [15:0] control_in;
reg [7:0] N;
reg [7:0] M;
reg [7:0] H;
wire [7:0]mem_dat_data_a; 
reg mem_w_wr, mem_f_wr;
wire mem_dat_en, meme_w_en, mem_F_en;
wire [9:0] mem_dat_add_rd, mem_dat_add_wr;
wire [7:0] mem_dat_data, mem_dat_data_f; 
wire mem_dat_wr;
wire [11:0] mem_w_address, mem_F_address;
wire [15:0] mem_w_data;
reg [7:0] mem_f_data_w;
reg [15:0] mem_w_data_w;

mlp_core core (clk, reset, control_in, N, M, H, mem_dat_en, mem_dat_add_rd, mem_dat_data, 
mem_dat_add_wr, mem_dat_wr, mem_w_address, meme_w_en, mem_w_data, mem_F_address, mem_F_en);

RAM_dual_port ram_data (clk, mem_dat_en, mem_dat_wr, mem_dat_add_wr, mem_dat_add_rd, 
mem_dat_data_f, mem_dat_data_a, mem_dat_data);

RAM_single_port_1 ram_w (clk, meme_w_en, mem_w_wr, mem_w_address, mem_w_data_w, mem_w_data);

RAM_single_port_2 ram_f (clk, mem_F_en, mem_f_wr, mem_F_address, mem_f_data_w,mem_dat_data_f);

always
begin
  clk=1; #5; clk=0; #5;
end

initial begin
  N<=36;
  M<=11;
  H<=26;  
  reset<=1;
  control_in<=0;
  #20;
  reset<=0;
  control_in<=2'b10;  
end

endmodule


module RAM_single_port_1 (clock,ram_enable, write_enable,address, data_input, data_output);
parameter N=16;
parameter M=12;
input clock,ram_enable,write_enable;
input [M-1:0] address;
input [N-1:0] data_input;
output [N-1:0] data_output;
reg [N-1:0] data_output;
reg [N-1:0] memory [(2**M)-1:0];

//////////inicializacion
integer file, j;
real f; integer st;
initial begin
  file=$fopen("InputWeights.txt", "r");
  st=$fscanf(file, "%f", f);
  j=0;
  while (j<=2048 && st!=`EOF) begin
    memory[j]=f*512;
    $display ("ww:%d", memory[j]);
    st=$fscanf(file, "%f", f);
    j=j+1;
  end
  $fclose (file);
  j=2048;
    file=$fopen("InterWeights.txt", "r");
  st=$fscanf(file, "%f", f);
  while (j<=4095 && st!=`EOF) begin
    memory[j]=f*512;
    st=$fscanf(file, "%f", f);
    j=j+1;
  end
  $fclose (file);
  
end

////////////////////////

always @(posedge clock)
      if (ram_enable)
         if (write_enable) begin
            memory[address] <= data_input;
        end
         else
            data_output <= memory[address];
                                                      
endmodule

module RAM_single_port_2 (clock,ram_enable, write_enable,address, data_input, data_output);
parameter N=8;
parameter M=12;
input clock,ram_enable,write_enable;
input [M-1:0] address;
input [N-1:0] data_input;
output [N-1:0] data_output;
reg [N-1:0] data_output;
reg [N-1:0] memory [(2**M)-1:0];

//////////inicializacion
integer file, j;
real f; integer st;
initial begin
  file=$fopen("tansig.txt", "r");
  st=$fscanf(file, "%f", f);
  j=0;
  while (j<=4096 && st!=`EOF) begin
    memory [j]=f/2;
    $display ("tans:%d", memory[j]);
    st=$fscanf(file, "%f", f);
    j=j+1;
  end
  $fclose (file);
end

////////////////////////
   
always @(posedge clock)
      if (ram_enable)
         if (write_enable)
            memory[address] <= data_input;
         else
            data_output <= memory[address];
                                                      
endmodule


module RAM_dual_port(clock,ram_enable,write_enableA,addressA,addressB,data_input,data_outputA,data_outputB);
parameter N=8;
parameter M=10;
input clock,ram_enable,write_enableA;
input [M-1:0] addressA,addressB;
input [N-1:0] data_input;
output [N-1:0] data_outputA,data_outputB;
reg [N-1:0] data_outputA,data_outputB;
reg [N-1:0] memory [(2**M)-1:0];


//////////inicializacion
reg signed [7:0] p;
integer file, j;
real f; integer st;
initial begin
  file=$fopen("Inputs.txt", "r");
  st=$fscanf(file, "%f", f);
  j=0;
  while (j<=255 && st!=`EOF) begin
    memory [j]=f/2;
    $display ("%d", memory[j]);
    st=$fscanf(file, "%f", f);
    j=j+1;
  end
  $fclose (file);
end

////////////////////////
   
always @(posedge clock)
      if (ram_enable) begin
         if (write_enableA) begin
            memory[addressA] <= data_input;
        end
         data_outputA = memory[addressA];
         data_outputB = memory[addressB];
      end
                              
endmodule


module mlp_core (clk, reset, control, N, M, H, mem_dat_en, mem_dat_add_rd, mem_dat_data, 
                mem_dat_add_wr, mem_dat_wr, mem_w_address, meme_w_en, mem_w_data, mem_F_address, mem_F_en);
input clk, reset;
input [15:0] control; 
input [7:0] N, M, H;
output mem_dat_en, meme_w_en, mem_F_en;
output reg [9:0] mem_dat_add_rd, mem_dat_add_wr; 
output reg [11:0] mem_w_address, mem_F_address;
input [7:0] mem_dat_data;
output reg mem_dat_wr;
input [15:0] mem_w_data;

parameter data_in_m=10'h000;
parameter data_a_m=10'h100;
parameter data_out_m=10'h200;
parameter iw_m=12'h000;
parameter il_m=12'h800;

reg signed [7:0] data;
reg signed [15:0] weight;
reg signed [23:0] mult;
reg signed [31:0] suma;
reg [15:0] status_r;
reg [15:0] control_r;
reg [7:0] N_r, M_r, H_r;
reg [7:0] ctrl_0, ctrl_1, ctrl_2, ctrl_3, ctrl_4, ctrl_5;
reg [7:0] cont; reg [7:0] cont2;

assign mem_dat_en=1;
assign meme_w_en=1;
assign mem_F_en=1;
 

always @ (posedge clk) begin
  if (reset || control[2] || status_r[0]) begin
    ctrl_0<=0; ctrl_1<=0; ctrl_2<=0; cont<=1; 
    ctrl_3<=0; ctrl_4<=0; ctrl_5<=0; cont2<=1;
    mem_dat_add_rd<=data_in_m;
    mem_dat_add_wr<=data_a_m;
    mem_w_address<=12'h000;
  end
  
  if (reset || control[2]) begin
    control_r<=0;
    status_r<=0;
    N_r<=0; M_r<=0; H_r<=0;
  end
  else begin
    control_r<=control;
    N_r<=N; M_r<=M; H_r<=H;

    if (status_r[0]==1 && control_r[1]==0)
      status_r[0]=0;
      
    else if (status_r[0]==0 && control_r[1]==1) begin
      ctrl_0[0]<=1; ctrl_1<=ctrl_0; ctrl_2<=ctrl_1;
      ctrl_3<=ctrl_2; ctrl_4<=ctrl_3; ctrl_5<=ctrl_4;
      data<=mem_dat_data;
      weight<=mem_w_data;
      mult<=data*weight;

      if (cont==N_r && cont2==M_r && ctrl_0[4]==0) begin
        mem_dat_add_rd<=data_a_m;
        mem_w_address<=il_m;
        ctrl_0[3:1]<=3'b010;
        ctrl_0[4]<=1;
        cont<=1;
        cont2<=1;
      end
      else if (cont==M_r && cont2==H_r && ctrl_0[4]==1) begin
        ctrl_0[3:1]<=3'b100;
        cont<=0;
      end
      else if (cont==N_r && ctrl_0[4]==0) begin
        ctrl_0[3:1]<=3'b001;
        mem_dat_add_rd<=data_in_m;
        mem_w_address<=mem_w_address+1;
        cont<=1;
        cont2<=cont2+1;
      end
      else if (cont==M_r && ctrl_0[4]==1) begin
        ctrl_0[3:1]<=3'b001;
        mem_dat_add_rd<=data_a_m;
        mem_w_address<=mem_w_address+1;
        cont<=1;
        cont2<=cont2+1;
      end
      else begin
        mem_dat_add_rd<=mem_dat_add_rd+1;
        mem_w_address<=mem_w_address+1;
        cont<=cont+1;
        ctrl_0[3:1]<=3'b000;
      end

      if (ctrl_3[3:1]!=3'b000)
        suma<=mult;
      else if (ctrl_2[0]) 
        suma<=suma+mult;
      else
        suma<=0;
      
      if ((suma[30:17]!=0 && suma[31]==0) || ctrl_3[2]==1)
        mem_F_address<=12'h7FF;
      else if (suma[30:17]!=14'hFFFF && suma[31]==1)
        mem_F_address<=12'h800;
      else
        mem_F_address<={suma[31],suma[16:6]}; 

      if (ctrl_4[3:1])
        mem_dat_wr<=1;
      else
        mem_dat_wr<=0;
      
      if (ctrl_5[1])
        mem_dat_add_wr<=mem_dat_add_wr+1;
      else if (ctrl_5[2]) 
        mem_dat_add_wr<=data_out_m;

      if (ctrl_5[3])
        status_r[0]<=1;
    end
  end
end
endmodule