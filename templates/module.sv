// ============================================================
// Module      : <ip>_<role>
// IP          : <IPxxx> <ip>
// Description : <une phrase>
// Référence   : <IPxxx>-DS-v1.0 §<x>
// ============================================================

`default_nettype none

module <ip>_<role> #(
	parameter	int	unsigned	DATA_W	= 8		// <description>
) (
	// Horloge et reset
	input	logic					clk_i,
	input	logic					rst_n_i,
	// <Interface>
	input	logic	[DATA_W-1:0]	data_i,
	output	logic	[DATA_W-1:0]	data_o
);

	// ============================================================
	// SIGNAUX INTERNES
	// ============================================================
	logic	[DATA_W-1:0]	data_r, data_next;

	// ============================================================
	// LOGIQUE SÉQUENTIELLE
	// ============================================================
	always_ff @(posedge clk_i) begin
		if (!rst_n_i) begin
			data_r	<= '0;
		end else begin
			data_r	<= data_next;
		end
	end

	// ============================================================
	// LOGIQUE COMBINATOIRE
	// ============================================================
	always_comb begin
		data_next	= data_i;
	end

	// ============================================================
	// SORTIES
	// ============================================================
	assign data_o	= data_r;

endmodule : <ip>_<role>

`default_nettype wire
