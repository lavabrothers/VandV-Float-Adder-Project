# Select the "Use run.bash shell script" option
# VCS
vcs -full64 -licqueue '-timescale=1ns/1ns' '+vcs+flush+all' '+warn=all' '-sverilog' '-ntb_opts' 'dtm' -f files.f
./simv +vcs+lic+wait
urg  -dir simv.vdb -format both 
ls -l urgReport/*txt
cat urgReport/*txt