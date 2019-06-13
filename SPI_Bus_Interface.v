module SPI_Bus_Interface (
		
		input bi_rst,
		input  SCK,
		input  nSS,
		input  SDI,		
		output reg SDO,		
		output reg nEN    = 1,
		output reg nRE    = 1,
		output reg nWE    = 1,
		output reg nReset = 1,
		output reg [15:0] Addr,
		inout  [7:0]  IO
		);
// SPI interface parameters
	parameter spi_half_cycle = 5;
	parameter spi_cycle      = 10;
	parameter spi_ten_cycles = 100;
	
// Flash Core parameters
	parameter t_command = 20;
	parameter t_data_setup = 10;
	parameter t_data_hold = 7;
	parameter t_delta = 1; // to avoid race conditions making sure only one input changes at a time

	localparam IDLE         = 4'h0;
	localparam FTCH_OPCODE  = 4'h1;
	localparam FTCH_ADDR_HI = 4'h2;
	localparam FTCH_ADDR_LO = 4'h3;
	localparam FTCH_DATA    = 4'h4;
	localparam READ_FLSH    = 4'h5;
	localparam WRITE_FLSH   = 4'h6;
	localparam WAIT_4_FLASH = 4'h7;
	localparam SEND_SDO     = 4'h8;
// state names
	 
	reg [3:0] nxt_st;
	reg [3:0] cur_st;
	
	reg [2:0] cntr;
	reg done;
		
	reg bi_clk = 0;
	wire sck_local;
	reg bi_clk_en;
	
	reg [ 7:0] io_shft_reg;
	reg [ 7:0] opcode_ftchd;
	reg [ 7:0] addr_hi;
	reg [ 7:0] addr_lo;
	reg [ 7:0] data_ftchd;
	wire [15:0] addr_ftchd;
	
	reg oe  = 0;
	reg  [7:0] data_to_flash ; 
	wire [7:0] data_from_flash;
	
	assign data_from_flash = IO; 
	assign IO = (oe) ? data_to_flash : 8'hzz;
	assign addr_ftchd = {addr_hi,addr_lo};
		
/// local clock oscillator ////////////////////////	
	always	 #spi_half_cycle bi_clk = !bi_clk;

// clock mux	
	assign sck_local = (bi_clk_en) ? bi_clk : SCK;	
	
///////////////////////////////////////////////////
	
	always @(posedge sck_local or posedge bi_rst)  
	// SDI sampled on the rising edge of SCK, SPI mode 3
	begin
		if (bi_rst)
		begin
			opcode_ftchd <= 0;
		    addr_hi      <= 0;
		    addr_lo      <= 0;
		    data_ftchd   <= 0;		    
		    
		end
		else if (cur_st == FTCH_OPCODE)		   
		                               opcode_ftchd <= {opcode_ftchd[6:0],  SDI};
		
		      else if (cur_st == FTCH_ADDR_HI)		         
		                               addr_hi <= {addr_hi[6:0], SDI};
		      
		            else if (cur_st == FTCH_ADDR_LO)		            
		                               addr_lo <= {addr_lo[6:0], SDI};
		            
		               else if (cur_st == FTCH_DATA)		                  
		                               data_ftchd   <= {data_ftchd[6:0], SDI};
	end
	
////////// Bus Interface State Machine ////////////////////
	
	always @(negedge sck_local or posedge bi_rst)
	begin   
		if (bi_rst)
		begin
			cur_st <= IDLE;
			SDO <= 0;  
			io_shft_reg <= 0;
			cntr <= 0;
			done <= 0;
			bi_clk_en <= 0;
		end
		else
			begin
	           cur_st <= nxt_st;
	           cntr <= cntr + 1;
	           // SDO sent on the falling edge of SCK to be sampled on the rising edge of the master side
	           if (cur_st == SEND_SDO)
	               begin
	                   SDO <= io_shft_reg[7]; 
	                   io_shft_reg <= io_shft_reg << 1;
	               end
		    end
	end	
	
///////////////////////////////////////////////////	

	always @(*)
	begin
		nxt_st = cur_st;
		
		case (cur_st)
			
			IDLE: begin	
				bi_clk_en = 0;
				cntr = 0;
			         if (!nSS)	
			         begin
			         	nxt_st = FTCH_OPCODE;
			         end
			         else
			         	nxt_st = IDLE;				
			end
			
			FTCH_OPCODE: begin			
				             if (cntr == 0)
				             begin
				             	nxt_st = FTCH_ADDR_HI;
				             end
				             else
				             	nxt_st = FTCH_OPCODE;
			end
			
			FTCH_ADDR_HI: begin	
				              if (cntr == 0)	
				              begin
				                 nxt_st = FTCH_ADDR_LO;
				              end
				              else
				              	nxt_st = FTCH_ADDR_HI;				
			end
			
			FTCH_ADDR_LO: begin	
				               if (cntr == 0)	
				               	case (opcode_ftchd)
				               		8'h10: begin
				               			      bi_clk_en = 1;
				               			      nxt_st = READ_FLSH;
				               		end
				               		8'h20: nxt_st = FTCH_DATA;
				               	endcase
				               else
				               	nxt_st = FTCH_ADDR_LO;				
			end
			
			FTCH_DATA: begin
				           if (cntr == 0)	
				           begin
				           	  bi_clk_en = 1;
				           	  nxt_st = WRITE_FLSH;
				           end
				           else
				           	nxt_st = FTCH_DATA;		
			end
			
			READ_FLSH: begin
				             read_from_flash (addr_ftchd);	
				             //nxt_st = WAIT_4_FLASH;
				             if (done) begin
				             	           io_shft_reg = IO;
				                           nxt_st = SEND_SDO;
				                           #(spi_cycle - t_delta) bi_clk_en = 0;
				             end
			end
			
			WRITE_FLSH: begin
				              write_to_flash (addr_ftchd, data_ftchd);
				              nxt_st = IDLE;
			end
/*						
			WAIT_4_FLASH: begin
				cntr = 0;
				if (done) // done flag goes up when Bus Int module finishes the task read_from_flash,
					      //  when it asserts the appropriate inputs of Flash Core module
				      begin
				      	#(spi_cycle - t_delta) bi_clk_en = 0;
				      	  io_shft_reg = IO;
				      	  nxt_st = SEND_SDO;
				      end
				else 
					nxt_st = WAIT_4_FLASH;
			end
*/			
			SEND_SDO: begin
				done = 0;
				//bi_clk_en = 0; // to send the data wait from SCK from the bus master
				if (cntr == 0)
				begin
					nxt_st = IDLE;
				end
				else
					nxt_st = SEND_SDO;
			end
				
			default:
				    nxt_st = cur_st;
		endcase
	end	
	
	    
/////////////////////////////////////////////////////
	
	task read_from_flash;
		input [15:0] a; // address to read
		begin
			send_byte (16'h5555, 8'hAA);
			send_byte (16'hAAAA, 8'h55);
			send_byte (16'h5555, 8'h10); //0x10 is an opcode for "read"
			receive_byte (a);
			done = 1;
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
	
///////////////////////////////////////////////////	
	
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
	
/////////////////////////////////////////////////////

endmodule 
///////////////////////////////////////////////////
/*	
	always @(negedge sck_local or posedge bi_rst)
	begin
		if (bi_rst)
		   begin
		   	SDO <= 0;
		   	io_shft_reg <= 0;
		   end
		else 
			begin
		       SDO <= io_shft_reg[7];
		       io_shft_reg <= io_shft_reg << 1;
		    end
	end

 */		