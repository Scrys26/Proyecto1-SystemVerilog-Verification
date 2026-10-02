#!/bin/csh -f

cd /mnt/vol_NFS_rh003/Est_Veri_II2026/FERNANDEZ_AGUILAR_RANDY_VeriII26/Proyecto1-SystemVerilog-Verification

#This ENV is used to avoid overriding current script in next vcselab run 
setenv SNPS_VCSELAB_SCRIPT_NO_OVERRIDE  1

/mnt/vol_NFS_rh003/tools/vcs/R-2020.12-SP2/linux64/bin/vcselab $* \
    -o \
    Reportes/build/simv_TestTP3_b1_d4_p16_bc255 \
    -nobanner \

cd -

