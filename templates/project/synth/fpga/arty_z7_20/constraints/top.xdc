# ============================================================
# Contraintes XDC — Arty Z7-20 (xc7z020clg400-1)
# Décommenter et adapter les lignes selon les ports du top
# ============================================================

# --- Horloge système 125 MHz (broche H16) ---
# set_property -dict {PACKAGE_PIN H16 IOSTANDARD LVCMOS33} [get_ports clk_i]
# create_clock -period 8.000 -name clk [get_ports clk_i]

# --- Reset (BTN0 — D19) ---
# set_property -dict {PACKAGE_PIN D19 IOSTANDARD LVCMOS33} [get_ports rst_n_i]

# --- LEDs (4 LEDs RGB disponibles) ---
# set_property -dict {PACKAGE_PIN R14 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
# set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
# set_property -dict {PACKAGE_PIN N16 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
# set_property -dict {PACKAGE_PIN M14 IOSTANDARD LVCMOS33} [get_ports {led[3]}]

# --- Boutons (4 boutons) ---
# set_property -dict {PACKAGE_PIN D19 IOSTANDARD LVCMOS33} [get_ports {btn[0]}]
# set_property -dict {PACKAGE_PIN D20 IOSTANDARD LVCMOS33} [get_ports {btn[1]}]
# set_property -dict {PACKAGE_PIN L20 IOSTANDARD LVCMOS33} [get_ports {btn[2]}]
# set_property -dict {PACKAGE_PIN L19 IOSTANDARD LVCMOS33} [get_ports {btn[3]}]

# --- UART (USB-UART FTDI) ---
# set_property -dict {PACKAGE_PIN B19 IOSTANDARD LVCMOS33} [get_ports uart_tx]
# set_property -dict {PACKAGE_PIN A20 IOSTANDARD LVCMOS33} [get_ports uart_rx]

# --- Switchs (4 switchs) ---
# set_property -dict {PACKAGE_PIN G15 IOSTANDARD LVCMOS33} [get_ports {sw[0]}]
# set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33} [get_ports {sw[1]}]
# set_property -dict {PACKAGE_PIN W13 IOSTANDARD LVCMOS33} [get_ports {sw[2]}]
# set_property -dict {PACKAGE_PIN T16 IOSTANDARD LVCMOS33} [get_ports {sw[3]}]

# --- Contraintes timing globales ---
# set_input_delay  -clock clk -max 2.0 [all_inputs]
# set_output_delay -clock clk -max 2.0 [all_outputs]
