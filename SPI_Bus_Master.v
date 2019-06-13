module SPI_Bus_Master (
		
		input      SDI, // data from slave
		output reg bi_rst,
		output reg SDO, //data to slave
		output reg SCK,
		output reg nSS		
		);
	
	parameter spi_half_cycle = 5;
	parameter spi_cycle      = 10;
	parameter spi_5_cycles = 50;
	parameter spi_50_cycles = 500;
	parameter t_delta = 1;
	
	integer i;

	initial begin
		SCK = 1; //SPI mode 3, the steady state of the SCK is 1
		nSS = 1; 
		bi_rst = 1;
		#spi_cycle;
		#spi_cycle;
		bi_rst = 0;
	end

//////////////////////////////////////////////////////////
// SPI mode 3	
	task send_byte;
		input [7:0] byte_to_send;
		begin
			nSS = 0;
			#t_delta;
			for (i = 7; i >= 0; i = i - 1)
			begin
				SCK = !SCK;
			    SDO = byte_to_send[i]; // sending MSB to LSB
			    #spi_half_cycle;
			    SCK = !SCK;
		        #spi_half_cycle;
			end	
			#t_delta;
			nSS = 1;	
		end
	endtask

//////////////////////////////////////////////////////////
	
	task receive_byte;
		begin
			nSS = 0;
			#t_delta;
			for (i = 7; i >= 0; i = i - 1)
			begin
				SCK = !SCK;
				#spi_half_cycle;
				SCK = !SCK;
				#spi_half_cycle;
			end	
			#t_delta;
			nSS = 1;
		end
	endtask
	
//////////////////////////////////////////////////////////
		
	task write_to_flash;
		input [15:0]addr;
		input [7:0] data;
		begin
			send_byte (8'h20); // opcode for Write Byte
			#(spi_cycle - t_delta);             // wait two cycles before sending nex byte
			#(spi_cycle - t_delta);
			send_byte (addr[15:8]); //send the upper byte of an address
			#(spi_cycle - t_delta);
			#(spi_cycle - t_delta);
			send_byte (addr[7:0]); //send the lower byte of an address
			#(spi_cycle - t_delta);
			#(spi_cycle - t_delta);
			send_byte (data);
		end
	endtask
	

//////////////////////////////////////////////////////////

	task read_from_flash;
		input [15:0] addr;
		begin
			send_byte (8'h10); // opcode for Read 
			#(spi_cycle - t_delta);
			#(spi_cycle - t_delta);
			send_byte (addr[15:8]); //send the upper byte of an address
			#(spi_cycle - t_delta);
			#(spi_cycle - t_delta);
			send_byte (addr[7:0]); //send the lower byte of an address
			#(spi_cycle - t_delta);
			#(spi_cycle - t_delta);
			#(spi_50_cycles - t_delta);
			receive_byte();
		end
	endtask
		
//////////////////////////////////////////////////////////
	
	initial begin
	    #(spi_5_cycles - t_delta);
	    read_from_flash (16'h1234);
	    #(spi_50_cycles - t_delta);
		write_to_flash (16'h1234, 8'h99);
		#(spi_50_cycles - t_delta);
		read_from_flash (16'h1234);
	end
	
endmodule 
/*
	task send_byte;
		input [7:0] byte_to_send;
		begin			
			for (i = 7; i >= 0; i = i - 1)
			begin
				nSS = 0;
				#t_delta;
				SCK = !SCK;
			    SDO = byte_to_send[i]; // sending MSB to LSB
			    #spi_half_cycle;
			    SCK = !SCK;
		        #spi_half_cycle;
			end	
			#t_delta;
			nSS = 1;	
		end
	endtask

	*/