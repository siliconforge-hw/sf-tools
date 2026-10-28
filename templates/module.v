// ============================================================
// Module      : <ip>_<role>
// Projet      : <IPxxx> <ip>
// Description : <une phrase>
// Référence   : <IPxxx>-DS-v1.0 §<x>
// Langage     : Verilog-2005 (pas de contrôle SF-HDL-001)
// ============================================================

`default_nettype none

module <ip>_<role> #(
	parameter	DATA_W	= 8		// <description>
) (
	// Horloge et reset
	input	wire				clk_i,
	input	wire				rst_n_i,
	// <Interface>
	input	wire	[DATA_W-1:0]	data_i,
	output	wire	[DATA_W-1:0]	data_o
);

	reg	[DATA_W-1:0]	data_r;

	always @(posedge clk_i) begin
		if (!rst_n_i) begin
			data_r	<= {DATA_W{1'b0}};
		end else begin
			data_r	<= data_i;
		end
	end

	assign data_o	= data_r;

endmodule

`default_nettype wire
