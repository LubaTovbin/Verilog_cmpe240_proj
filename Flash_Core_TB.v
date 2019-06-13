module Flash_Core_TB ();
	
	parameter t_command = 20;
	parameter t_data_setup = 10;
	parameter t_data_hold = 7;
	parameter t_delta = 1; // to avoid race conditions making sure only one input changes at a time
	
	reg nEN = 1;
	reg nRE = 1;
	reg nWE = 1;
	reg nReset = 1;
	reg [15:0] Addr;

	reg oe  = 0;
	reg  [7:0] data_to_flash;
	wire [7:0] data_from_flash;	
	wire [7:0] IO;
	
	assign data_from_flash = IO; 
	assign IO = (oe) ? data_to_flash : 8'hzz;
	

	///////////////////////////////////////////////////	
	
	task send_byte;
		input [15:0] a; // address to write
		input [ 7:0] d; // data to write
		begin
			data_to_flash = d;
			nEN = 0;
			Addr = a;
			#t_delta;
			nWE = 0;						
			#(t_command - t_delta - t_data_setup);
			oe = 1;						
			#t_data_setup;
			nWE = 1;			
			#t_delta;
			nEN = 1;		
			#(t_data_hold - t_delta);
			oe = 0;
			#(t_command - t_data_hold);
		end
	endtask
	
	
	/////////////////////////////////////////////////////
	
	task receive_byte;
		input [15:0] a; // address to read
		begin
			nEN = 0;			
			Addr = a;
			#t_delta;
			nRE = 0;
			#(t_command - t_delta - t_delta);
			nRE = 1;	
			#t_delta;
			nEN = 1;
			#t_command;
		end
	endtask	

	///////////////////////////////////////////////////	
	
	task write_to_flash;
		input [15:0] a; // address to write 
		input [ 7:0] d; // data to write    
		begin
			send_byte (16'h5555, 8'hAA);			
			send_byte (16'hAAAA, 8'h55);
			send_byte (16'h5555, 8'h20); //0x20 is an opcode for "write"
			send_byte (a, d);
		end
	endtask
	    
	/////////////////////////////////////////////////////
	
	task read_from_flash;
		input [15:0] a; // address to read
		begin
			send_byte (16'h5555, 8'hAA);
			send_byte (16'hAAAA, 8'h55);
			send_byte (16'h5555, 8'h10); //0x10 is an opcode for "read"
			receive_byte (a);
		end
	endtask
		    
	/////////////////////////////////////////////////////
	
initial begin
	#t_command;
	#t_command;
	#t_command;
	#7;
	nReset = 0;
	#56;
	nReset = 1;
end

initial begin
	#t_command;
	write_to_flash (16'h1234, 8'h99);
	#t_command;
	#t_command;
	#t_command;
	#t_command;
	receive_byte (16'h1234);
	#t_command;
	#t_command;
	#t_command;
	write_to_flash (16'h1234, 8'h99);
	#t_command;
	#t_command;
	#t_command;
	read_from_flash (16'h1234);
end
	
	Flash_Core DUT(
		.nEN   (nEN   ),        
		.nRE   (nRE   ),        
		.nWE   (nWE   ),        
		.nReset(nReset),     
		.Addr  (Addr  ),
		.IO    (IO    )    
		);
endmodule 
