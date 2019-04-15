# SPECcpu2017_Benchmark_Auto
Automation of SPECcpu2017 benchmarking with environment check and setup.

Written by Kevin SJ Huang 2019/1/23

This script can be used on RHEL7 only, or the pre-test environment checking machanism may not work. (SPECcpu should still run)

This script checks all the testing environment settings under lily's requirement, 
including date / OS settings / DIMM speed / DIMM size / HDD space / HT setting.

This script will automatically download the necessary tool packages from ESQ900 Smart Testing FTP and prep them for testing.

This script will automatically download SPECcpu2017 from ESQ900 Smart Testing FTP

When no parameter specified, this script will run a full SPECcpu2017 test (rate and speed)

To run only rate or speed, put "rate" or "speed" as the first parameter

Ex. ./speccpu2017.sh rate

This script will use $bin as the binaries which is designed to run on Purley SKL
