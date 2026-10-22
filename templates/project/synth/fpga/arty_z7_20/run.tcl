# ============================================================
# run.tcl — Flow Vivado complet en mode batch
# Usage : vivado -mode batch -source run.tcl \
#           -tclargs <project_name> <top_module> <project_root>
# ============================================================

# --- Arguments ---
set project_name [lindex $argv 0]
set top_module   [lindex $argv 1]
set proj_root    [lindex $argv 2]

set part         "xc7z020clg400-1"
set out_dir      "$proj_root/synth/fpga/arty_z7_20"
set bit_dir      "$out_dir/bitstream"
set src_dir      "$proj_root/src"
set xdc_file     "$out_dir/constraints/top.xdc"

puts "============================================================"
puts " Projet   : $project_name"
puts " Top      : $top_module"
puts " Part     : $part"
puts " Racine   : $proj_root"
puts "============================================================"

# --- Créer le projet Vivado en mémoire (in-memory, pas de .xpr) ---
create_project -in_memory -part $part

# --- Ajouter les sources RTL ---
set rtl_files [glob -nocomplain \
    "$src_dir/**/*.v" \
    "$src_dir/**/*.sv" \
    "$src_dir/*.v" \
    "$src_dir/*.sv" \
]
if {[llength $rtl_files] == 0} {
    puts "ERREUR : aucun fichier RTL trouvé dans $src_dir"
    exit 1
}
add_files $rtl_files
set_property top $top_module [current_fileset]

# --- Ajouter les contraintes XDC ---
if {[file exists $xdc_file]} {
    add_files -fileset constrs_1 $xdc_file
} else {
    puts "ATTENTION : $xdc_file introuvable — synthèse sans contraintes"
}

# --- Synthèse ---
puts "\n--- SYNTHESE ---"
synth_design -top $top_module -part $part
report_utilization -file "$out_dir/report_utilization.rpt"
report_timing_summary -file "$out_dir/report_timing_pre_impl.rpt"

# --- Implémentation ---
puts "\n--- IMPLEMENTATION ---"
opt_design
place_design
phys_opt_design
route_design
report_timing_summary -file "$out_dir/report_timing_post_impl.rpt"
report_utilization    -file "$out_dir/report_utilization_impl.rpt"

# --- Génération bitstream ---
puts "\n--- BITSTREAM ---"
file mkdir $bit_dir
write_bitstream -force "$bit_dir/${top_module}.bit"

puts "\n============================================================"
puts " Bitstream : $bit_dir/${top_module}.bit"
puts "============================================================"
