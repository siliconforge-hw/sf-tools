// ============================================================
// Module      : sigreset_top
// Projet      : test sf-tools (tests/run_tests.sh)
// Description : top écrit à la main qui instancie le regblock PeakRDL de tests/regs/sigreset.rdl,
//               pour vérifier que make lint passe sur un top réel (non-régression sf-tools 0.11.3)
// Référence   : SF-REG-001 §7 (reset porté par un signal)
// ============================================================

`default_nettype none

module sigreset_top #(
	parameter	logic	[7:0]	DIV_RESET	= 8'd5
) (
	input	logic			clk_i,
	input	logic			rst_n_i,
	input	logic			s_axil_awvalid_i,
	output	logic			s_axil_awready_o,
	input	logic	[11:0]	s_axil_awaddr_i,
	input	logic			s_axil_wvalid_i,
	output	logic			s_axil_wready_o,
	input	logic	[31:0]	s_axil_wdata_i,
	input	logic	[3:0]	s_axil_wstrb_i,
	output	logic			s_axil_bvalid_o,
	input	logic			s_axil_bready_i,
	output	logic	[1:0]	s_axil_bresp_o,
	input	logic			s_axil_arvalid_i,
	output	logic			s_axil_arready_o,
	input	logic	[11:0]	s_axil_araddr_i,
	output	logic			s_axil_rvalid_o,
	input	logic			s_axil_rready_i,
	output	logic	[31:0]	s_axil_rdata_o,
	output	logic	[1:0]	s_axil_rresp_o,
	output	logic	[7:0]	div_o,
	output	logic			en_o
);

	// ============================================================
	// SIGNAUX INTERNES
	// ============================================================
	sigreset_regs_pkg::sigreset_regs__in_t	hwif_in;
	sigreset_regs_pkg::sigreset_regs__out_t	hwif_out;

	// ============================================================
	// LOGIQUE COMBINATOIRE
	// ============================================================
	// NOTE: reset de DIVR.DIV fixé par le paramètre (SF-REG-001 §7)
	assign hwif_in.div_reset = DIV_RESET;

	// ============================================================
	// INSTANCES
	// ============================================================
	sigreset_regs u_sigreset_regs (
		.clk			(clk_i),
		.rst_n			(rst_n_i),
		.s_axil_awready	(s_axil_awready_o),
		.s_axil_awvalid	(s_axil_awvalid_i),
		.s_axil_awaddr	(s_axil_awaddr_i),
		.s_axil_awprot	(3'b000),
		.s_axil_wready	(s_axil_wready_o),
		.s_axil_wvalid	(s_axil_wvalid_i),
		.s_axil_wdata	(s_axil_wdata_i),
		.s_axil_wstrb	(s_axil_wstrb_i),
		.s_axil_bready	(s_axil_bready_i),
		.s_axil_bvalid	(s_axil_bvalid_o),
		.s_axil_bresp	(s_axil_bresp_o),
		.s_axil_arready	(s_axil_arready_o),
		.s_axil_arvalid	(s_axil_arvalid_i),
		.s_axil_araddr	(s_axil_araddr_i),
		.s_axil_arprot	(3'b000),
		.s_axil_rready	(s_axil_rready_i),
		.s_axil_rvalid	(s_axil_rvalid_o),
		.s_axil_rdata	(s_axil_rdata_o),
		.s_axil_rresp	(s_axil_rresp_o),
		.hwif_in		(hwif_in),
		.hwif_out		(hwif_out)
	);

	// ============================================================
	// SORTIES
	// ============================================================
	assign div_o	= hwif_out.DIVR.DIV.value;
	assign en_o		= hwif_out.DIVR.EN.value;

endmodule : sigreset_top

`default_nettype wire
