#!/bin/bash

#====================
#资源检查
sourcecheck=0
#日志
logcat=1
#设备检查
devicecheck=1
#ab分区机型
ABdevice=0
#完成后打包为zip
autopack=1
#====================
buildtype=clang
timezone="Asia/Shanghai"
build_device="perseus"
kernel_name="lulu-kernel"
defconfig_path="perseus_defconfig"
kbuild_build_user="perseus"
kbuild_build_host="luluz"
support="11"
#====================

print (){
case ${2} in
	"red")
	echo -e "\033[31m $1 \033[0m";;

	"sky")
	echo -e "\033[36m $1 \033[0m";;

	"green")
	echo -e "\033[32m $1 \033[0m";;

	*)
	echo $1
	;;
	esac
}

if [ ${sourcecheck} -eq 1 ];then
   sudo apt-get update
   sudo apt-get install -y build-essential bc python2 python3 curl git zip ftp gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi libssl-dev lftp wget libfl-dev bison flex clang
   git submodule update --init --recursive 
fi

if [ ${sourcecheck} -eq 1 ];then
    if [ -d "${HOME}/Anykernel3" ];then
        rm -rf ${HOME}/Anykernel3
        git clone --depth=1 https://github.com/Dedrimer/Anykernel3 ${HOME}/Anykernel3
    else
        git clone --depth=1 https://github.com/Dedrimer/Anykernel3 ${HOME}/Anykernel3
    fi
fi

if [ ${sourcecheck} -eq 1 ];then
    if [ -d "${HOME}/cbl" ];then
        rm -rf ${HOME}/cbl
        git clone --depth=1 https://github.com/HyperLYP/Clang-and-Binutils-for-ARM64-platforms ${HOME}/cbl
    else
        git clone --depth=1 https://github.com/HyperLYP/Clang-and-Binutils-for-ARM64-platforms ${HOME}/cbl
    fi
fi

source=`pwd`
START_TIME=$(date +"%s")
date="`date +"%m%d%H%M"`"
timedatectl set-timezone ${timezone}

print "正在构建的版本:${date}" yellow

clang_path="${HOME}/cbl/bin"
gcc_path="/usr/bin/aarch64-linux-gnu-"
gcc_32_path="/usr/bin/arm-linux-gnueabi-"

args="-j$(nproc --all)  \
            O=out  \
            ARCH=arm64 "

if [ ${buildtype} == gcc ];then
    export PATH=$PATH:/usr/bin/aarch64-linux-gnu-
    args+="-Wno-unused-function \
    SUBARCH=arm64 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_ARM32=arm-linux-gnueabi- "
else [ ${buildtype} == clang ]
    args+="CC=${clang_path}/clang \
	    CLANG_TRIPLE=aarch64-linux-gnu- \
	    CROSS_COMPILE=${gcc_path} \
	    AR=${clang_path}/llvm-ar \
        LD=${clang_path}/ld.lld \
	    NM=${clang_path}/llvm-nm \
	    OBJCOPY=${clang_path}/llvm-objcopy \
	    OBJDUMP=${clang_path}/llvm-objdump \
	    STRIP=${clang_path}/llvm-strip \
        CROSS_COMPILE_ARM32=${gcc_32_path} "
fi

config_update(){
    if  [ -d "arch/arm64/configs/vendor/xiaomi" ];then
        if [ -f "arch/arm64/configs/vendor/output/${build_device}_defconfig" ];then
            echo -e "\033[32m [INFO] defconfig was definded \033[0m"
        else
            ./scripts/update_defconfig ${build_device}
            echo -e "\033[32m [INFO] Build defconfig successfully \033[0m"
        fi
    fi      
}

building(){
    export KBUILD_BUILD_USER=${kbuild_build_user}
    export KBUILD_BUILD_HOST=${kbuild_build_host}
    print "为 ${build_device} 构建内核" sky
    if [ ${logcat} -eq 1 ];then
        make ${args} ${defconfig_path}&&make ${args} 2>&1 | tee out/kernel.log
    else
        make ${args} ${defconfig_path}&&make ${args}
    fi
    if [ $? = 0 ];then
        echo -e "\033[32m [INFO] 构建完成 \033[0m"
    else
        echo -e "\033[31m [ERROR] 构建失败 \033[0m"
        exit 1
    fi
}

building_unclean(){
    export KBUILD_BUILD_USER=${kbuild_build_user}
    export KBUILD_BUILD_HOST=${kbuild_build_host}
	if [ ${logcat} -eq 1 ];then
        make ${args} 2>&1 | tee out/kernel.log
    else
        make ${args}
    fi
    if [ $? = 0 ];then
        echo -e "\033[32m [INFO] 构建完成 \033[0m"
    else
        echo -e "\033[31m [ERROR] 构建失败 \033[0m"
        exit 1
    fi
}

zipfile(){
    if [ -f "out/arch/arm64/boot/Image" ];then
        zipfiles="${kernel_name}-${build_device}-${date}.zip"
        cp -f out/arch/arm64/boot/Image ~/Anykernel3
        #cp -f out/arch/arm64/boot/dtbo.img ~/Anykernel3
        cd ~/Anykernel3
        sed -i "s|kernel.string=|kernel.string=${kernel_name}|" "anykernel.sh"
        sed -i "s|do.devicecheck=|do.devicecheck=${devicecheck}|" "anykernel.sh"
        sed -i "s|device.name1=|device.name1=${build_device}|" "anykernel.sh"
        sed -i "s|supported.versions=|supported.versions=${support}|" "anykernel.sh"
        if [ ${ABdevice} -eq 1 ];then
            sed -i "s|is_slot_device=|is_slot_device=1|" "anykernel.sh"
        else
            sed -i "s|is_slot_device=|is_slot_device=0|" "anykernel.sh"
        fi
        zip -r "${zipfiles}" *
        mv -f "${zipfiles}" ${HOME}
        sed -i "s|kernel.string=${kernel_name}|kernel.string=|" "anykernel.sh"
        sed -i "s|do.devicecheck=${devicecheck}|do.devicecheck=|" "anykernel.sh"
        sed -i "s|device.name1=${build_device}|device.name1=|" "anykernel.sh"
        sed -i "s|supported.versions=${support}|supported.versions=|" "anykernel.sh"
        if [ ${ABdevice} -eq 1 ];then
            sed -i "s|is_slot_device=1|is_slot_device=|" "anykernel.sh"
        else
            sed -i "s|is_slot_device=0|is_slot_device=|" "anykernel.sh"
        fi
        cd ${HOME}
        cd $source
        print "All done.Find it at ${HOME}/${zipfiles}" green
    else
        exit 1
    fi
}

#if [ -d "${HOME}/cbl" ];then
#    print "You have lost some important sources,please echo sourcecheck=1 to fix it" red
#    exit 1
#fi

if [ -d "out" ];then
    read -p "有未完成的构建,继续?" -a Dev
        if  [ "$Dev" = n ];then
            if [ ${autopack} -eq 1 ];then
                rm -rf out
                rm -rf arch/arm64/configs/vendor/output/*
                config_update
                building
                zipfile
            else
                rm -rf out
                rm -rf arch/arm64/configs/vendor/output/*
                config_update
                building
            fi
        elif [ "$Dev" = y ];then
            if [ ${autopack} -eq 1 ];then
                building_unclean
                zipfile
            else
                building_unclean
            fi
        else
        echo "输的什么东西"
        exit 1
        fi
else
    if [ ${autopack} -eq 1 ];then
        rm -rf arch/arm64/configs/vendor/output/*
        config_update
        building
        zipfile
    else
        rm -rf arch/arm64/configs/vendor/output/*
        config_update
        building
    fi
fi
END_TIME=`date +%s`
EXEC_TIME=$((${END_TIME} - ${START_TIME}))
EXEC_TIME=$((${EXEC_TIME}/60))
echo "运行时间: ${EXEC_TIME} 分"