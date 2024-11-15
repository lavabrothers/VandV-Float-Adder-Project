module tt_um_btflv_8bit_fp_adder (
	input  wire [7:0] ui_in,    // Dedicated inputs
	output wire [7:0] uo_out,   // Dedicated outputs
	input  wire [7:0] uio_in,   // IOs: Input path
	output wire [7:0] uio_out,  // IOs: Output path
	output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
	input  wire       ena,      // will go high when the design is enabled
	input  wire       clk,      // clock
	input  wire       rst_n     // reset_n - low to reset
);

assign uio_oe = 8'b00000000;
assign uio_out = 8'b00000000;

wire       a_sign;
wire       b_sign;
wire [3:0] a_expo;
wire [3:0] b_expo;
wire [3:0] a_mant;
wire [3:0] b_mant;
wire       x_sign;

reg [3:0] l_expo;
reg [3:0] s_expo;
reg [6:0] l_mant;
reg [6:0] s_mant;
reg [8:0] c_mant;
reg [5:0] g_mant;
reg [3:0] o_expo;
reg [2:0] o_mant;
reg       o_sign;
reg [7:0] o_floa;

assign a_sign = ui_in[7];
assign b_sign = uio_in[7];
assign a_expo = ui_in[6:3];
assign b_expo = uio_in[6:3];
assign a_mant[2:0] = ui_in[2:0];
assign b_mant[2:0] = uio_in[2:0];
assign a_mant[3] = 1'b1;
assign b_mant[3] = 1'b1;
assign x_sign    = a_sign ^ b_sign;

assign uo_out = o_floa;

always @*
begin	
	if (a_expo > b_expo)
	begin
		l_expo = a_expo;
		s_expo = b_expo;
		l_mant[6:3] = a_mant;
		l_mant[2:0] = (x_sign) ? 3'b000 : 3'b100;
		s_mant = ((b_mant << 3) + ((x_sign) ? 3'b000 : 3'b100)) >> (l_expo - s_expo);
		o_sign = a_sign;
	end
	else if (a_expo < b_expo)
	begin
		l_expo = b_expo;
		s_expo = a_expo;
		l_mant[6:3] = b_mant;
		l_mant[2:0] = (x_sign) ? 3'b000 : 3'b100;
		s_mant = ((a_mant << 3) + ((x_sign) ? 3'b000 : 3'b100)) >> (l_expo - s_expo);
		o_sign = b_sign;
	end
	else
	begin
		if (x_sign)
		begin
			l_mant[2:0] = 3'b000;
			s_mant[2:0] = 3'b000;
		end
		else
		begin
			l_mant[2:0] = 3'b100;
			s_mant[2:0] = 3'b100;
		end
		
		if(a_mant > b_mant)
		begin
			l_expo = a_expo;
			s_expo = b_expo;
			l_mant[6:3] = a_mant;
			s_mant[6:3] = b_mant;
			o_sign = a_sign;
		end
		else
		begin
			l_expo = b_expo;
			s_expo = a_expo;
			l_mant[6:3] = b_mant;
			s_mant[6:3] = a_mant;
			o_sign = b_sign;
		end
	end
	
	if(x_sign)
	begin
		c_mant = (l_mant > s_mant) ? l_mant - s_mant : s_mant - l_mant;
	end
	else
	begin
		c_mant = l_mant + s_mant;
	end
	
	if ((c_mant[7] || c_mant[8]) && !x_sign)
	begin
		if (c_mant[8])
		begin
			if (l_expo < 4'b1110)
			begin
				o_mant = c_mant[4:2];
				o_expo = l_expo + 2;
			end
			else
			begin
				o_mant = 3'b000;
				o_expo = 4'b1111;
			end
		end
		else
		begin
			if (l_expo < 4'b1111)
			begin
				o_mant = c_mant[6:4];
				o_expo = l_expo + 1;
			end
			else
			begin
				o_mant = 3'b000;
				o_expo = 4'b1111;
			end
		end
	end
	else if (c_mant[6])
	begin
		o_mant = c_mant[5:3];
		o_expo = l_expo;
	end
	else if (c_mant[5])
	begin
		o_mant = c_mant[4:2];
		o_expo = l_expo - 1;
	end
	else if (c_mant[4])
	begin
		o_mant = c_mant[3:1];
		o_expo = l_expo - 2;
	end
	else if (c_mant[3])
	begin
		o_mant = c_mant[2:0];
		o_expo = l_expo - 3;
	end
	else
	begin
		o_mant = 3'b000;
		o_expo = 4'b0000;
	end
end

always @(posedge clk)
begin
	if (!rst_n || !ena)
	begin
		o_floa <= 8'd0;
	end
	else if ((a_expo == 4'b1111 && a_mant[2:0] != 3'b000) || (b_expo == 4'b1111 && b_mant[2:0] != 3'b000))
	begin
		o_floa[7:0] <= 8'b01111111;
	end
	else if ((a_expo == 4'b1111 && a_mant[2:0] == 3'b000) || (b_expo == 4'b1111 && b_mant[2:0] == 3'b000))
	begin
		o_floa[6:0] <= 7'b1111000;
		o_floa[7]   <= o_sign;
	end
	else
	begin
		//o_floa = c_mant[7:0];
		o_floa[6:3] <= o_expo;
		o_floa[2:0] <= o_mant;
		o_floa[7]   <= o_sign;
	end
end

endmodule
