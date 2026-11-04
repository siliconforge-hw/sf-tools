// ============================================================
// Module      : multidriven_bad
// Projet      : test sf-tools (tests/run_tests.sh)
// Description : contre-exemple écrit à la main, hors gen/ : cnt_r piloté par deux always_ff.
//               Le lint DOIT échouer (MULTIDRIVEN bloquant hors du code généré).
// Référence   : SF-HDL-001 §7
// ============================================================

`default_nettype none

module multidriven_bad (
	input	logic			clk_i,
	input	logic			rst_n_i,
	input	logic			clr_i,
	output	logic	[3:0]	cnt_o
);

	// ============================================================
	// SIGNAUX INTERNES
	// ============================================================
	logic	[3:0]	cnt_r;

	// ============================================================
	// LOGIQUE SÉQUENTIELLE
	// ============================================================
	always_ff @(posedge clk_i) begin
		if (!rst_n_i) begin
			cnt_r <= '0;
		end else begin
			cnt_r <= cnt_r + 4'd1;
		end
	end

	always_ff @(posedge clk_i) begin
		if (clr_i) begin
			cnt_r <= '0;
		end
	end

	// ============================================================
	// SORTIES
	// ============================================================
	assign cnt_o = cnt_r;

endmodule : multidriven_bad

`default_nettype wire
