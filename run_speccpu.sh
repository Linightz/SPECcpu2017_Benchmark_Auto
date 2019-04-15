#!/bin/bash
# Written by Kevin SJ Huang 2019/1/23

# This script can be used on RHEL7 only, or the pre-test environment checking machanism may not work. (SPECcpu should still run)
# This script checks all the testing environment settings under lily's requirement,
# including date / OS settings / DIMM speed / DIMM size / HDD space / HT setting.
# This script will automatically download the necessary tool packages from ESQ900 Smart Testing FTP and prep them for testing.

ftp="10.32.37.52"
ftpusr="ESQ900"
ftppwd="1234"

tool="SPECcpu2017.tar" # Put your specjbb compress file name here
bin="FOR-OEMs-cpu2017-1.0.2-ic18.0-lin-binaries-20170901.tar.xz" # Put your binary compress file name here

run="${1:-all}"

ftp_download()
{
	echo "Disabling firewall daemon..."
	service firewalld stop
	service firewalld status |grep inactive
	[ $? -ne 0 ] && echo "Firewall disabling failed. Try to connect to FTP server anyway..." |tee -a "${0%.*}"_log_"$datenow".txt \
	|| echo "Firewall disabled" |tee -a "${0%.*}"_log_"$datenow".txt
	echo;echo "Start to download $tool"
	wget -P /home/*/ ftp://${ftpusr}:${ftppwd}@${ftp}/Performance_Tools/SPECCPU/$tool
	if [ $? -eq 0 ]; then
		echo "Tools downloaded from FTP successfully" |tee -a "${0%.*}"_log_"$datenow".txt
	else
		echo "Download failed, exiting" |tee -a "${0%.*}"_log_"$datenow".txt
		exit 1
	fi
	wget -P /home/*/ ftp://${ftpusr}:${ftppwd}@${ftp}/Performance_Tools/SPECCPU/$bin
	if [ $? -eq 0 ]; then
		echo "Binaries downloaded from FTP successfully" |tee -a "${0%.*}"_log_"$datenow".txt
	else
		echo "Download failed, exiting" |tee -a "${0%.*}"_log_"$datenow".txt
		exit 1
	fi
}

tool_prep()
{
	chmod 777 /home/*/$tool /home/*/$bin
	tar -C /home/*/ -xvf /home/*/$tool
	if [ $? -eq 0 ]; then
		echo "Tools decompressed" |tee -a "${0%.*}"_log_"$datenow".txt
	else
		echo "Tools decompressed failed" |tee -a "${0%.*}"_log_"$datenow".txt
		exit 1
	fi
	cd /home/*/${tool%.*}
	chmod 777 -R *
	printf 'yes\n' | ./install.sh
	if [ $? -eq 0 ]; then
		echo "SPECcpu2017 installed" |tee -a ${dir}/"${0%.*}"_log_"$datenow".txt
	else
		echo "Something wrong, SPECcpu2017 is not installed" |tee -a ${dir}/"${0%.*}"_log_"$datenow".txt
		exit 1
	fi
	cd $dir
	tar -C /home/*/${tool%.*} -xvf /home/*/$bin
	if [ $? -eq 0 ]; then
		echo "Binaries decompressed" |tee -a "${0%.*}"_log_"$datenow".txt
	else
		echo "Binaries decompressed failed" |tee -a "${0%.*}"_log_"$datenow".txt
		exit 1
	fi
	chmod 777 -R /home/*/${tool%.*}
}

check_date()
{
	y=`date +%Y`
	if [ $y -lt 2019 ]; then
		echo "The system time is outdated, correcting to 2019/1/1..." |tee -a "${0%.*}"_log_"$datenow".txt
		date -s '2019-01-01 00:00:00'
	else
		echo "System time OK" |tee -a "${0%.*}"_log_"$datenow".txt
	fi
}

check_libstdc()
{
	rpm -q libstdc++ |grep '.i686'
	if [ $? -ne 0 ]; then
		echo "Please install libstdc++.i686 first, exiting" |tee -a "${0%.*}"_log_"$datenow".txt
		exit 1
	else
		echo "libstdc++ is installed, continue" |tee -a "${0%.*}"_log_"$datenow".txt
	fi
}

check_diskspace()
{
	df -h |grep "rhel-h" > /dev/null
	if [ $? -ne 0 ]; then
		echo "Seems like this OS is not RHEL7, unable to identify disk space left" |tee -a "${0%.*}"_log_"$datenow".txt
	else
		space=`df -h |grep "rhel-h" |awk '{print $4}'`
		echo; echo "6. Available disk space left: $space" |tee -a "${0%.*}"_log_"$datenow".txt
		space_num=${space%[A-Z]}
		i=$((${#space}-1)) ; unit="${space:$i:1}"
		if [ $unit = 'G' ]; then
			if [[ $space_num -lt 120 ]]; then
				echo "The available disk space is not enough for a full run!" |tee -a "${0%.*}"_log_"$datenow".txt
				echo "Please have at least 120GB of free space before running, exiting" |tee -a "${0%.*}"_log_"$datenow".txt
				exit 1
			fi
		elif [ $unit = 'T' ]; then
			:
		else
			echo "The available disk space is not enough for a full run!" |tee -a "${0%.*}"_log_"$datenow".txt
			echo "Please have at least 120GB of free space before running, exiting" |tee -a "${0%.*}"_log_"$datenow".txt
			exit 1
		fi
	fi
}
#check_selinux()
#{
#	grep "SELINUX=disabled" /etc/selinux/config
#	if [ $? -ne 0 ]; then
#		echo "SELinux is not disabled, please disable it and reboot." |tee -a "${0%.*}"_log_"$datenow".txt
#		exit 1
#	fi
#}

create_log()
{
	datenow="$(date +%Y%m%d%H%M%S)"
	touch "${0%.*}"_log_"$datenow".txt
}

check_grub(){
	bootCfg=$(grep -m1 "linuxefi" /boot/efi/EFI/redhat/grub.cfg)
	result=${bootCfg##*"quiet "}
	result=${result##*"LANG=en_US.UTF-8 "}
	echo "$result" |tee -a "${0%.*}"_log_"$datenow".txt
}
check_HT(){
	HT=$(lscpu |awk '/per\ core:/{print $4; exit}')
	[ $HT = 1 ] && echo "Disabled" || echo "Enabled"
}
check_mem_freq(){
	memFreq=$(dmidecode -t 17 | awk '/Speed:/{print $2$3; exit}')
	if [ $? -eq 0 ]; then
		echo "$memFreq"
	else
		echo "Unable to retrieve memory freq"
	fi
}
check_tuned_adm(){
	if [[ $(tuned-adm active) != "Current active profile: latency-performance" ]]
		then
		echo -ne ">> Change to latency-performance, Please wait...\r"
		tuned-adm profile latency-performance
		echo -ne "                                                \r"
	fi
	result=$(tuned-adm active)
	echo "$result"
}
check_dimm_size(){ #return total dimm size in GB
	each_dimm_size=($(dmidecode -t 17| grep "Size:.*B"| grep -o "[0-9]*"))
	for item in "${each_dimm_size[@]}"; do
		total_dimm_size=$(($total_dimm_size + $item))
	done
	[[ -n $(dmidecode -t 17| grep "Size:.*MB") ]] && total_dimm_size=$(($total_dimm_size/1024))
}

echo "This script will automatically download SPECcpu2017 from ESQ900 Smart Testing FTP"
echo 'When no parameter specified, this script will run a full SPECcpu2017 test (rate and speed)'
echo "To run only rate or speed, put \"rate\" or \"speed\" as the first parameter"
echo "Ex. $0 rate"
echo "This script will use $bin as the binaries which is designed to run on Purley SKL"
echo "To change any of above, Press Ctrl + C and make changes in the script"
sleep 10s

dir="$(cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )"

create_log

[ -d /home/*/SPECcpu2017 ] && rm -r /home/*/SPECcpu2017

ftp_download 	#Comment out this function invocation if you don't need to download from FTP
sleep 3s		#Put the tool compress package under /home/<user>/

tool_prep
sleep 2s
check_date
sleep 2s
check_libstdc
sleep 2s

echo; echo "> Please check below:"

echo; echo "1. Additional configuration in grub.cfg:" |tee -a "${0%.*}"_log_"$datenow".txt
check_grub

echo; echo "2. Tuned-adm profile:" |tee -a "${0%.*}"_log_"$datenow".txt
check_tuned_adm |tee -a "${0%.*}"_log_"$datenow".txt

echo; echo "3. Hyper-Threading: "$(check_HT) |tee -a "${0%.*}"_log_"$datenow".txt

echo; echo "4. System memory frequency: "$(check_mem_freq) |tee -a "${0%.*}"_log_"$datenow".txt
check_dimm_size
echo; echo "5. Installed DIMM size: $total_dimm_size GB" |tee -a "${0%.*}"_log_"$datenow".txt
if [[ $total_dimm_size -lt 32 ]]; then
	echo "Please install more memory to run SPECcpu2017, exiting" |tee -a "${0%.*}"_log_"$datenow".txt
	exit 1
elif [[ $total_dimm_size -ge 32 && $total_dimm_size -lt 64 ]]; then
	echo "Installed DIMM size may be insufficient, try to continue anyway" |tee -a "${0%.*}"_log_"$datenow".txt
fi

check_diskspace

echo; echo "Is the above setup correct? Tests will begin in 10s"
echo "Press Ctrl + C to stop now"
sleep 10s

echo "Start Running SPECcpu2017 $run..."

cd /home/*/${tool%.*}
HT=$(lscpu |awk '/per\ core:/{print $4; exit}')

case "$run" in
	all)
		if [ $HT -eq 1 ]; then
			./reportable-ic18.0-lin-skl-core-avx2-speed-smt-off-20170901.sh
			./reportable-ic18.0-lin-skl-core-avx2-rate-smt-off-20170901.sh
		else
			./reportable-ic18.0-lin-skl-core-avx2-speed-smt-on-20170901.sh
			./reportable-ic18.0-lin-skl-core-avx2-rate-smt-on-20170901.sh
		fi
		check=0
		for ((i=1;i<5;i++))
		do
			if [ ! -s /home/*/${tool%.*}/result/CPU2017.00${i}*.pdf ]; then
				check=1
			fi
		done
		[ $check -eq 1 ] && echo "Something wrong, SPECcpu2017 $run test(s) failed!" |tee -a ${dir}/"${0%.*}"_log_"$datenow".txt \
		|| echo "SPECcpu2017 $run test(s) completed!" |tee -a ${dir}/"${0%.*}"_log_"$datenow".txt
		;;
	rate)
		if [ $HT -eq 1 ]; then
			./reportable-ic18.0-lin-skl-core-avx2-rate-smt-off-20170901.sh
		else
			./reportable-ic18.0-lin-skl-core-avx2-rate-smt-on-20170901.sh
		fi
		check=0
		for ((i=1;i<3;i++))
		do
			if [ ! -s /home/*/${tool%.*}/result/CPU2017.00${i}*.pdf ]; then
				check=1
			fi
		done
		[ $check -eq 1 ] && echo "Something wrong, SPECcpu2017 $run test(s) failed!" |tee -a ${dir}/"${0%.*}"_log_"$datenow".txt \
		|| echo "SPECcpu2017 $run test(s) completed!" |tee -a ${dir}/"${0%.*}"_log_"$datenow".txt
		;;
	speed)
		if [ $HT -eq 1 ]; then
			./reportable-ic18.0-lin-skl-core-avx2-speed-smt-off-20170901.sh
		else
			./reportable-ic18.0-lin-skl-core-avx2-speed-smt-on-20170901.sh
		fi
		check=0
		for ((i=1;i<3;i++))
		do
			if [ ! -s /home/*/${tool%.*}/result/CPU2017.00${i}*.pdf ]; then
				check=1
			fi
		done
		[ $check -eq 1 ] && echo "Something wrong, SPECcpu2017 $run test(s) failed!" |tee -a ${dir}/"${0%.*}"_log_"$datenow".txt \
		|| echo "SPECcpu2017 $run test(s) completed!" |tee -a ${dir}/"${0%.*}"_log_"$datenow".txt
		;;
	*)
		echo "Please enter a valid selection. Ex. $0 rate" |tee -a ${dir}/"${0%.*}"_log_"$datenow".txt
		exit 1
		;;
esac

echo "Cleaning up..."
echo "Backing up the result logs to \"SPECcpu2017_Logs\" folder under /root/"
rm -rf /home/*/${tool%.*}/benchspec/CPU/*/run/*
mkdir /root/SPECcpu2017_Logs_$datenow
cp -r /home/*/${tool%.*}/result/ /root/SPECcpu2017_Logs_$datenow/
echo "Done!"
