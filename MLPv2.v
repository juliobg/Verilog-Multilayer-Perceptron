`timescale 1ns/10ps
`define EOF 32'hFFFF_FFFF

module testb ();
reg clk;
reg reset;
reg [15:0] address;
reg [31:0] din;
wire [31:0] dout;
reg write;
reg read;
reg signed [7:0] s;

reg signed [7:0] p;
integer file, j;
real f; integer st;

MLP mlp (clk, reset, address, din, dout, write, read);

always
begin
clk=1; #5; clk=0; #5;
end

initial begin

  //resetear el dispositivo
  reset=1;
  #19;
  reset=0;
  
  //escribir en el registro de control para activar el acceso a las memorias
  write=1;
  address=16'h0004;
  din=16'b001;
  #10
  
  //registro N
  address=16'h0010;
  din=36;
  #10
  
  //registro M
  address=16'h0014;
  din=11;
  #10
  
  //registro H
  address=16'h0018;
  din=26;
  #10
  
  //Escribir datos de entrada
  address=16'h1000;
  file=$fopen("Inputs.txt", "r");
  st=$fscanf(file, "%f", f);
  j=0;
  while (j<=255 && st!=`EOF) begin
    //p=f/2;
    din=f/2;
    #10;
    st=$fscanf(file, "%f", f);
    j=j+1;
    address=address+1;
  end
  $fclose (file);

  //Escribir pesos capa oculta
  address=16'h8000;
  file=$fopen("InputWeights.txt", "r");
  st=$fscanf(file, "%f", f);
  j=0;
  while (j<=2048 && st!=`EOF) begin
    din<=f*512;#10;
    st=$fscanf(file, "%f", f);
    j=j+1;
    address=address+1;
  end
  $fclose (file);
  
  //Escribir pesos capa de salida
  address=16'hA000;
  file=$fopen("InterWeights.txt", "r");
  st=$fscanf(file, "%f", f);
  j=0;
  while (j<=2048 && st!=`EOF) begin
    din=f*512;#10;
    st=$fscanf(file, "%f", f);
    j=j+1;
    address=address+1;
  end
  $fclose (file);
  
  //Escribir LUT
  address=16'h4000;
  file=$fopen("tansig.txt", "r");
  st=$fscanf(file, "%f", f);
  j=0;
  while (j<=4096 && st!=`EOF) begin
    din=f/2;#10;
    st=$fscanf(file, "%f", f);
    j=j+1;
    address=address+1;
  end
  $fclose (file);
  $display ("Memorias inicializadas");
  
  //Una vez escritas las memorias se desactiva el acceso a las memorias y se inicia el procesado a través del registro de control
  address=16'h0004;
  din=16'b010;
  #10;
  write=0;
  
  //Mantener el registro de estado en lectura
   address=16'h0008;
end

//Cuando el bit 1 del registro de estado pase a 1 (fin del procesado), mostrar los resultados almacenados en la memoria de datos (salida)
always @(posedge dout[0]) begin
  if (address==16'h0008) begin
    write<=1;
    address<=16'h0004;
    din<=16'b001;
    #10
    write<=0;
    address<=16'h1800;
    j=0;
    while (j<26) begin
      #10;
      s=dout;
      $display ("Ouput: %d", s);
      j=j+1;
      address<=address+1;
    end
  end
end
  
endmodule

module MLP (input clk, input reset, input [15:0] address, input [31:0] din, output reg [31:0] dout, input write, input read); 
reg [15:0] control_reg;
reg [7:0] N;
reg [7:0] M;
reg [7:0] H;
wire [7:0]mem_dat_data_a; 
wire [15:0] status_out;
reg mem_w_wr, mem_f_wr;
wire mem_dat_en, meme_w_en, mem_F_en;
wire [9:0] mem_dat_add_rd, mem_dat_add_wr;
reg [9:0] mem_dat_add_wr_m;
wire [7:0] mem_dat_data, mem_dat_data_f; 
reg [7:0] mem_dat_data_f_m;
wire mem_dat_wr;
reg mem_dat_wr_m;
wire [11:0] mem_w_address, mem_F_address;
reg [11:0] mem_F_address_m, mem_w_address_m;
wire [15:0] mem_w_data;
reg [7:0] mem_f_data_w;
reg [15:0] mem_w_data_w;

//bloque de procesado
mlp_core core (clk, reset, control_reg, N, M, H, mem_dat_en, mem_dat_add_rd, mem_dat_data, 
mem_dat_add_wr, mem_dat_wr, mem_w_address, meme_w_en, mem_w_data, mem_F_address, mem_F_en, status_out);

//memoria de datos de doble puerto
RAM_dual_port ram_data (clk, mem_dat_en, mem_dat_wr_m, mem_dat_add_wr_m, mem_dat_add_rd, 
mem_dat_data_f_m, mem_dat_data_a, mem_dat_data);

//memoria de pesos
RAM_single_port_1 ram_w (clk, meme_w_en, mem_w_wr, mem_w_address_m, mem_w_data_w, mem_w_data);

//LUT con la funcion no lineal
RAM_single_port_2 ram_f (clk, mem_F_en, mem_f_wr, mem_F_address_m, mem_f_data_w,mem_dat_data_f);

//interfaz con el bus
//registros de configuracion
always @(posedge clk)
  if (write)
    case (address)
      16'h0004: control_reg<=din [15:0];
      16'h0010: N<=din;
      16'h0014: M<=din;
      16'h0018: H<=din;
    endcase
//salida de datos
always @(*) begin
  case (address[15:12]) 
    4'h0: 
      case (address [7:0]) 
        8'h04: dout=control_reg;
        8'h08: dout=status_out;
        8'h10: dout=N;
        8'h14: dout=M;
        8'h18: dout=H;
      endcase
    4'h1: dout=mem_dat_data_a;
    4'h4: dout=mem_dat_data_f;
    4'h8: dout=mem_w_data;  
    4'hA: dout=mem_w_data;
  endcase
end

//entrada de datos y bus de direcciones
always @(*) begin
  if (address [15:12]==4'h1 && control_reg[0]) begin
    mem_dat_wr_m=write;
    mem_dat_data_f_m=din;
    if (address [11:10]==2'b00)
      mem_dat_add_wr_m={2'b00, address [7:0]};
    else if (address [11:10]==2'b01)
      mem_dat_add_wr_m={2'b01, address [7:0]};
    else
      mem_dat_add_wr_m={2'b10, address [7:0]};
  end
  else begin
    mem_dat_wr_m=mem_dat_wr;
    mem_dat_data_f_m=mem_dat_data_f;
    mem_dat_add_wr_m=mem_dat_add_wr;
  end
  if (address [15:12]==4'h4 && control_reg[0]) begin    
    mem_f_wr=write;
    mem_f_data_w=din;
    mem_F_address_m=address [11:0];
  end
  else begin
    mem_f_wr=1'b0;
    mem_f_data_w=8'b0;
    mem_F_address_m=mem_F_address;
  end
  if (address [15]==1'b1 && control_reg[0]) begin
    mem_w_wr=write;
    mem_w_data_w=din;
    if (address [14:12]==0)
      mem_w_address_m={1'b0, address[10:0]};
    else
      mem_w_address_m={1'b1, address[10:0]};
  end
  else begin
    mem_w_wr=0;
    mem_w_data_w=12'b0;
    mem_w_address_m=mem_w_address;
  end
end
endmodule

module mlp_core (clk, reset, control, N, M, H, mem_dat_en, mem_dat_add_rd, mem_dat_data, mem_dat_add_wr, mem_dat_wr, mem_w_address, meme_w_en, mem_w_data, mem_F_address, mem_F_en, status_r);
input clk, reset;
input [15:0] control; 
input [7:0] N, M, H;
output mem_dat_en, meme_w_en, mem_F_en;
output reg [9:0] mem_dat_add_rd, mem_dat_add_wr; 
output reg [11:0] mem_w_address, mem_F_address;
input [7:0] mem_dat_data;
output reg mem_dat_wr;
input [15:0] mem_w_data;
output reg [15:0] status_r;
      
reg signed [7:0] data;
reg signed [15:0] weight;
reg signed [23:0] mult;
reg signed [31:0] suma;
reg [4:0] ctrl_0, ctrl_1, ctrl_2, ctrl_3, ctrl_4, ctrl_5;
reg [7:0] cont; reg [7:0] cont2;

parameter data_in_m=10'h000;
parameter data_a_m=10'h100;
parameter data_out_m=10'h200;
parameter iw_m=12'h000;
parameter il_m=12'h800;

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
    status_r<=0;
  end
  else begin
    if (status_r[0]==1 && control[1]==0)
      status_r[0]=0;
            
    else if (status_r[0]==0 && control[1]==1) begin
      //registros de control (pipeline), entrada de datos y multiplicacion
      ctrl_0[0]<=1; ctrl_1<=ctrl_0; ctrl_2<=ctrl_1;
      ctrl_3<=ctrl_2; ctrl_4<=ctrl_3; ctrl_5<=ctrl_4;
      data<=mem_dat_data;
      weight<=mem_w_data;
      mult<=data*weight;

      //comprobar si se ha llegado al final de la primera fase (capa oculta)
      if (cont==N && cont2==M && ctrl_0[4]==0) begin
        mem_dat_add_rd<=data_a_m;
        mem_w_address<=il_m;
        ctrl_0[3:1]<=3'b010;
        ctrl_0[4]<=1;
        cont<=1;
        cont2<=1;
      end
      //comprobar si se ha llegado al final del procesado (capa de salida)
      else if (cont==M && cont2==H && ctrl_0[4]==1) begin
        ctrl_0[3:1]<=3'b100;
        cont<=0;
      end
      //comprobar si se ha calculado una neurona de la capa oculta
      else if (cont==N && ctrl_0[4]==0) begin
        ctrl_0[3:1]<=3'b001;
        mem_dat_add_rd<=data_in_m;
        mem_w_address<=mem_w_address+1;
        cont<=1;
        cont2<=cont2+1;
      end
      //comprobar si se ha calculado una neurona de la capa de salida
      else if (cont==M && ctrl_0[4]==1) begin
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
      
      //escribir en el acumulador solo si hay un valor valido a la entrada
      if (ctrl_3[3:1]!=3'b000)
        suma<=mult;
      else if (ctrl_2[0]) 
        suma<=suma+mult;
      else
        suma<=0;
        
      //calculo de la direccion de 12 bits para la LUT    
      if (ctrl_3[3:1]) begin
        if ((suma[30:17]!=0 && suma[31]==0) || ctrl_3[2])
          mem_F_address<=12'h7FF;
        else if (suma[30:17]!=14'hFFFF && suma[31])
          mem_F_address<=12'h800;
        else
          mem_F_address<={suma[31],suma[16:6]};
      end

      //activar escritura en memoria de datos solo cuando sea necesario
      if (ctrl_4[3:1])
        mem_dat_wr<=1;
      else
        mem_dat_wr<=0;

      //actualizar direccion de escritura en memoria de datos            
      if (ctrl_5[1])
        mem_dat_add_wr<=mem_dat_add_wr+1;
      else if (ctrl_5[2]) 
        mem_dat_add_wr<=data_out_m;

      //se ha llegado al final del procesado? (ultimo dato escrito?)      
      if (ctrl_5[3])
        status_r[0]<=1;
    end
  end
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

   
always @(posedge clock)
      if (ram_enable) begin
         if (write_enableA) begin
            memory[addressA] <= data_input;
        end
         data_outputA = memory[addressA];
         data_outputB = memory[addressB];
      end
                              
endmodule