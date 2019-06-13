module Top_proj_2 (	
		);

	wire serial_data_to_master;
	wire serial_data_to_bi;
	wire serial_clk;
	
	wire nSS;
	wire flash_nEN   ;
	wire flash_nRE   ;
	wire flash_nWE   ;
	wire flash_nReset;
	
    wire [15:0] flash_addr;
    wire [7:0] flash_IO;

	
SPI_Bus_Master master (		
		.SDI(serial_data_to_master),
		.bi_rst(bi_rst),
		.SDO(serial_data_to_bi),
		.SCK(serial_clk),
		.nSS(nSS)
	);
	
SPI_Bus_Interface bi (
		.bi_rst(bi_rst),
		.SCK   (serial_clk),
		.nSS   (nSS),
		.SDI   (serial_data_to_bi),
		.SDO   (serial_data_to_master),
        .nEN   (flash_nEN   ),
		.nRE   (flash_nRE   ),
		.nWE   (flash_nWE   ),
        .nReset(flash_nReset),
        .Addr  (flash_addr  ),
        .IO    (flash_IO    )
	);
	
Flash_Core flash(
		.nEN   (flash_nEN   ),     
		.nRE   (flash_nRE   ),     
		.nWE   (flash_nWE   ),     
		.nReset(flash_nReset),     
		.Addr  (flash_addr   ),            
		.IO    (flash_IO    )
	);
				
endmodule 
