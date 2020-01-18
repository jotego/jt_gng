set_global_assignment -name VERILOG_MACRO "CORETOP=jtf1dream_unamiga"

set_global_assignment -name VERILOG_MACRO "CORENAME=\"JTF1DRM\""
set_global_assignment -name VERILOG_MACRO "GAMETOP=jttora_game"
set_global_assignment -name VERILOG_MACRO "JT12=1"
set_global_assignment -name VERILOG_MACRO "F1DREAM=1"
set_global_assignment -name VERILOG_MACRO "VIDEO_WIDTH=384"

# 3F = gray = mature core
set_global_assignment -name VERILOG_MACRO "JTFRAME_OSDCOLOR=6'h3f"
set_global_assignment -name VERILOG_MACRO "HAS_TESTMODE=1"
set_global_assignment -name VERILOG_MACRO "JOIN_JOYSTICKS=1"

set_global_assignment -name VERILOG_FILE ../../../modules/jt12/jt49/hdl/filter/jt49_dcrm2.v
set_global_assignment -name VERILOG_FILE ../../../modules/jt12/hdl/mixer/jt12_mixer.v
 

