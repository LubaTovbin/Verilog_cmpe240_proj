module Flash_Core (
		
    input nEN        ,
    input nRE        ,
    input nWE        ,
    input nReset     ,
    input [15:0] Addr,
    inout [7:0] IO
);
	
    parameter t_acc = 5;
    reg [7:0] mem [0:65535]; // 2^16 = 65536
	reg oe = 0;	
	reg we = 0;
	reg in_flag = 0;
	reg cycle_1 = 0;
	reg cycle_2 = 0;
	reg cycle_3 = 0;
		
	reg [7:0] data_out;	
	wire[7:0] data_in;	
		
	assign data_in = IO;
	assign IO = (oe) ? data_out : 8'hzz; 
	
///////////////////////////////////////////////////////
	// Initializing flash  memory contents
	integer i;
	initial begin
		for ( i = 0; i < 65536; i = i + 1)
			mem[i] = i;
	end
///////////////////////////////////////////////////////
	always @(*)
		if (!nReset) // after reset go to read mode
		begin
			cycle_1 = 0;
			cycle_2 = 0;
			cycle_3 = 1;
			we = 0;  // disable input
			oe = 0;  // disable output till nRE is asserted
		end
		else
			if (!nEN)
			begin
				if (nWE && !nRE && cycle_3 == 1) // read
				begin
					#t_acc;
					data_out = mem[Addr];
					oe = 1;
					cycle_1 = 0;
					cycle_2 = 0;
					cycle_3 = 0;					
				end
		
			    if (!nWE && nRE) // falling edge of nWE
			    	begin
			    		in_flag = 1; // set input flag
			    		oe = 0;      // disable output
			    	end
			    	
			    if (nWE && nRE && in_flag == 1 && we == 0) // rising edge of nWE: enable input
			    begin
			    	in_flag = 0;
			    	case ({Addr, data_in})
			    		24'h5555aa: cycle_1 = 1;
			    		24'haaaa55: if (cycle_1 == 1) cycle_2 = 1;
			    		24'h555510: if (cycle_2 == 1) cycle_3 = 1; // read opcode, output is disabled till the nRE is asserted
			    		24'h555520: if (cycle_2 == 1)
			    				begin // write opcode
			    			            cycle_3 = 1;
			    			            we = 1;     
			    		        end
			    	endcase	
			    end
			    
			    if (nWE && nRE && in_flag == 1 && we == 1)
			    begin
			        mem[Addr] = data_in;
			        in_flag = 0;
			        we = 0;	
			        cycle_1 = 0;
			        cycle_2 = 0;
			        cycle_3 = 0;
			    end
			end

	
///////////////////////////////////////////////////////
	 
endmodule 