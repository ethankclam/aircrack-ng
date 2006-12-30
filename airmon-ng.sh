#!/bin/sh

IFACE=""
KISMET=/etc/kismet/kismet.conf
CH=$3; [ x$3 = "x" ] && CH=10
IFACE_FOUND="false"

usage() {
	printf "usage: `basename $0` <start|stop> <interface> [channel]\n"
	echo
	exit
}

startStdIface() {
	iwconfig $1 mode monitor 2> /dev/null >/dev/null
	iwconfig $1 channel $2 2> /dev/null >/dev/null
	iwconfig $1 key off 2> /dev/null >/dev/null
	ifconfig $1 up
	printf " (monitor mode enabled)"
}


stopStdIface() {
	ifconfig $1 down 2> /dev/null >/dev/null
	iwconfig $1 mode Managed 2> /dev/null >/dev/null
	ifconfig $1 down 2> /dev/null >/dev/null
	printf " (monitor mode disabled)"
}

which iwpriv > /dev/null 2> /dev/null || 
  { echo Wireless tools not found ; exit ; }

echo && echo

if [ x$1 != "xstart" ] && [ x$1 != "xstop" ] && [ $# -ne "0" ]
then
	usage
fi

if [ x$2 = "x" ] && [ $# -ne "0" ]
then
	usage		
fi

printf "Interface\tChipset\t\tDriver\n" && echo


for iface in `ifconfig -a 2>/dev/null | egrep HWaddr | cut -b 1-7`
do
 if [ -e "/proc/sys/dev/$iface/fftxqmin" ]
 then
    ifconfig $iface up
    printf "$iface\t\tAtheros\t\tmadwifi-ng"       
    if [ x$1 = "xstart" ] && [ x$2 = x$iface ]
    then
        IFACE=`wlanconfig ath create wlandev $iface wlanmode monitor`
        cp $KISMET~ $KISMET 2>/dev/null &&
        echo "source=madwifi_g,$iface,Atheros" >>$KISMET
        iwconfig $IFACE channel $CH
        #printf " (monitor mode enabled)"
    fi
    if [ x$1 = "xstop" ] && [ x$2 = x$iface ]
    then
            echo "$iface does not support 'stop', do it on ath interface"
    fi
    echo
    continue
 fi
done

sleep 1s

for iface in `iwconfig 2>/dev/null | egrep '(IEEE|ESSID|802\.11)' | cut -b 1-7 | grep -v wifi`
do
 if [ x"`iwpriv $iface 2>/dev/null | grep force_reset`" != "x" ]
 then
    printf "$iface\t\tHermesI\t\torinoco"
    if [ x$1 = "xstart" ] && [ x$2 = x$iface ]
    then
        cp $KISMET~ $KISMET 2>/dev/null &&
        echo "source=orinoco,$iface,HermesI" >>$KISMET
        iwconfig $iface mode Monitor channel $CH &>/dev/null
        iwpriv $iface monitor 1 $CH &>/dev/null
        ifconfig $iface up
        printf " (monitor mode enabled)"
    fi
    if [ x$1 = "xstop" ] && [ x$2 = x$iface ]
    then
        ifconfig $iface down
        iwpriv $iface monitor 0 &>/dev/null
        iwconfig $iface mode Managed &>/dev/null
        printf " (monitor mode disabled)"
    fi
    echo
    continue
 fi


 if [ `iwpriv $iface 2>/dev/null | grep -v $iface | md5sum | awk '{print $1}'` == "2310629be8b9051238cde37520d97755" ]
 then
    printf "$iface\t\tCentrino b\tipw2100"
    if [ x$1 = "xstart" ] && [ x$2 = x$iface ]
    then
        cp $KISMET~ $KISMET 2>/dev/null &&
        echo "source=ipw2100,$iface,Centrino_b" >>$KISMET
        startStdIface $iface $CH
    fi
    if [ x$1 = "xstop" ] && [ x$2 = x$iface ]
    then
        stopStdIface $iface
    fi
    echo
    continue
 fi


 if [ x"`iwpriv $iface 2>/dev/null | grep sw_reset`" != "x" ]
 then
    MODINFO=`modinfo ipw2200 | awk '/^version/ {print $2}'`
    if { echo "$MODINFO" | grep -E '^1\.0\.(0|1|2|3)$' ; }
    then
    	echo "Monitor mode not supported, please upgrade"
    else
	printf "$iface\t\tCentrino b/g\tipw2200"
	if [ x$1 = "xstart" ] && [ x$2 = x$iface ]
	then
	    cp $KISMET~ $KISMET 2>/dev/null &&
	    echo "source=ipw2200,$iface,Centrino_g" >>$KISMET
	    startStdIface $iface $CH
	fi
	if [ x$1 = "xstop" ] && [ x$2 = x$iface ]
	then
	    stopStdIface $iface
	fi

    	if { echo "$MODINFO" | grep -E '^1\.0\.(5|7|8|11)$' ; }
	then
		printf " (Warning: bad module version, you should upgrade)"
	fi
     fi
     echo
     continue
 fi

 if [ x"`iwpriv $iface 2>/dev/null | grep set_preamble`" != "x" ]
  then
        printf "$iface\t\tCentrino b/g\tipw3945"
        if [ x$1 = "xstart" ] && [ x$2 = x$iface ]
         then
                cp $KISMET~ $KISMET 2>/dev/null &&
                echo "source=ipw3945,$iface,Centrino_g" >>$KISMET
                startStdIface $iface $CH
        fi
        if [ x$1 = "xstop" ] && [ x$2 = x$iface ]
         then
                stopStdIface $iface
        fi
        echo
        continue
 fi

 if [ x"`iwpriv $iface 2>/dev/null | grep inact_auth`" != "x" ]
 then
     if [ -e "/proc/sys/net/$iface/%parent" ]
     then
        printf "$iface\t\tAtheros\t\tmadwifi-ng VAP (parent: `cat /proc/sys/net/$iface/%parent`)"
	if [ x$2 = x$iface ] && [ x$1 = "xstop" ]
	then
		wlanconfig $iface destroy
		printf " (VAP destroyed)"
	fi
	if [ $iface = "$IFACE" ]  &&  [ x$1 = "xstart" ]
	then
		printf " (monitor mode enabled)"
	fi
	echo ""
        continue
     	
     fi
     printf "$iface\t\tAtheros\t\tmadwifi"
     if [ x$1 = "xstart" ] && [ x$2 = x$iface ]
     then
         cp $KISMET~ $KISMET 2>/dev/null &&
         echo "source=madwifi_g,$iface,Atheros" >>$KISMET
         startStdIface $iface $CH
     fi
     if [ x$1 = "xstop" ] && [ x$2 = x$iface ]
     then
         stopStdIface $iface
     fi
     echo
     continue
 fi


 if [ x"`iwpriv $iface 2>/dev/null | grep extrates`" != "x" ]
 then
     printf "$iface\t\tPrismGT\t\tprism54"
     if [ x$1 = "xstart" ] && [ x$2 = x$iface ]
     then
         cp $KISMET~ $KISMET 2>/dev/null &&
         echo "source=prism54g,$iface,Prism54" >>$KISMET
         ifconfig $iface up
         iwconfig $iface mode Monitor channel $CH
         iwpriv $iface set_prismhdr 1 &>/dev/null
         printf " (monitor mode enabled)"
     fi
     if [ x$1 = "xstop" ] && [ x$2 = x$iface ]
     then
         stopStdIface $iface
     fi
     echo
     continue
 fi


 if [ x"`iwpriv $iface 2>/dev/null | grep antsel_rx`" != "x" ]
 then
     printf "$iface\t\tPrism2\t\tHostAP"
     if [ x$1 = "xstart" ] && [ x$2 = x$iface ]
     then
         cp $KISMET~ $KISMET 2>/dev/null &&
         echo "source=hostap,$iface,Prism2" >>$KISMET
         iwconfig $iface mode Monitor channel $CH
         iwpriv $iface monitor_type 1 &>/dev/null
         ifconfig $iface up
         printf " (monitor mode enabled)"
     fi
     if [ x$1 = "xstop" ] && [ x$2 = x$iface ]
     then
         stopStdIface $iface
     fi
     echo
     continue
 fi


 if [ x"`wlancfg show $iface 2>/dev/null | grep p2CnfWEPFlags`" != "x" ]
 then
     printf "$iface\t\tPrism2\t\twlan-ng"
     if [ x$1 = "xstart" ] && [ x$2 = x$iface ]
     then
         cp $KISMET~ $KISMET 2>/dev/null &&
         echo "source=wlanng,$iface,Prism2" >>$KISMET
         wlanctl-ng $iface lnxreq_ifstate ifstate=enable >/dev/null
         wlanctl-ng $iface lnxreq_wlansniff enable=true channel=$CH \
                           prismheader=true wlanheader=false \
                           stripfcs=true keepwepflags=true >/dev/null
         echo p2CnfWEPFlags=0,4,7 | wlancfg set $iface
         ifconfig $iface up
         printf " (monitor mode enabled)"
     fi
     if [ x$1 = "xstop" ] && [ x$2 = x$iface ]
     then
         ifconfig $iface down
         wlanctl-ng $iface lnxreq_wlansniff enable=false  >/dev/null
         wlanctl-ng $iface lnxreq_ifstate ifstate=disable >/dev/null
         printf " (monitor mode disabled)"
     fi
     echo
     continue
 fi


 if [ x"`iwpriv $iface 2>/dev/null | grep bbp`" != "x" ]
 then
     printf "$iface\t\tRalink b/g\trt2500"
     if [ x$1 = "xstart" ] && [ x$2 = x$iface ]
     then
         cp $KISMET~ $KISMET 2>/dev/null &&
         echo "source=rt2500,$iface,Ralink_g" >>$KISMET
         iwconfig $iface mode ad-hoc 2> /dev/null >/dev/null
         startStdIface $iface $CH
     fi
     if [ x$1 = "xstop" ] && [ x$2 = x$iface ]
     then
         stopStdIface $iface
     fi
     echo
     continue
 fi


 if [ x"`iwpriv $iface 2>/dev/null | grep wpapsk`" != "x" ]
 then
     printf "$iface\t\tRalink USB\trt2570"
     if [ x$1 = "xstart" ] && [ x$2 = x$iface ]
     then
         cp $KISMET~ $KISMET 2>/dev/null &&
         echo "source=rt2500,$iface,Ralink_g" >>$KISMET
         iwconfig $iface mode ad-hoc 2> /dev/null >/dev/null
         startStdIface $iface $CH
         iwpriv $iface forceprismheader 1
     fi
     if [ x$1 = "xstop" ] && [ x$2 = x$iface ]
     then
         stopStdIface $iface
     fi
     echo
     continue
 fi


 if [ x"`iwpriv $iface 2>/dev/null | grep debugtx`" != "x" ]
 then
     printf "$iface\t\tRTL8180\t\tr8180"
     if [ x$1 = "xstart" ] && [ x$2 = x$iface ]
     then
         cp $KISMET~ $KISMET 2>/dev/null &&
         echo "source=rt8180,$iface,Realtek" >>$KISMET
         iwconfig $iface mode Monitor channel $CH
         iwpriv $iface prismhdr 1 &>/dev/null
         ifconfig $iface up
         printf " (monitor mode enabled)"
     fi
     if [ x$1 = "xstop" ] && [ x$2 = x$iface ]
     then
         stopStdIface $iface
     fi
     echo
     continue
 fi


 if [ x"`iwpriv $iface 2>/dev/null | grep badcrc`" != "x" ]
 then
     printf "$iface\t\tRTL8187\t\tr8187"
     if [ x$1 = "xstart" ] && [ x$2 = x$iface ]
     then
         cp $KISMET~ $KISMET 2>/dev/null &&
         echo "source=rt8180,$iface,Realtek" >>$KISMET
         iwconfig $iface mode Monitor channel $CH
         iwpriv $iface rawtx 1 &>/dev/null
         ifconfig $iface up
         printf " (monitor mode enabled)"
     fi
     if [ x$1 = "xstop" ] && [ x$2 = x$iface ]
     then
         stopStdIface $iface
     fi
     echo
     continue
 fi


 if [ x"`iwpriv $iface 2>/dev/null | grep dbg_flag`" != "x" ]
 then
     printf "$iface\t\tZyDAS\t\tzd1211"
     if [ x$1 = "xstart" ] && [ x$2 = x$iface ]
     then
         cp $KISMET~ $KISMET 2>/dev/null &&
         echo "source=wlanng_legacy,$iface,ZyDAS" >>$KISMET
         startStdIface $iface $CH
     fi
     if [ x$1 = "xstop" ] && [ x$2 = x$iface ]
     then
         stopStdIface $iface
     fi
     echo
     continue
 fi


 if [ x"`iwpriv $iface 2>/dev/null | grep GetAcx1`" != "x" ]
 then
     printf "$iface\t\tTI\t\tacx111"
     if [ x$1 = "xstart" ] && [ x$2 = x$iface ]
     then
         cp $KISMET~ $KISMET 2>/dev/null &&
         echo "source=acx100,$iface,TI" >>$KISMET
         startStdIface $iface $CH
     fi
     if [ x$1 = "xstop" ] && [ x$2 = x$iface ]
     then
         stopStdIface $iface
     fi
     echo
     continue
 fi


 if [ x"`iwpriv $iface 2>/dev/null | grep write_sprom`" != "x" ]
 then
     printf "$iface\t\tBroadcom\t\tbcm43xx"
     if [ x$1 = "xstart" ] && [ x$2 = x$iface ]
     then
         cp $KISMET~ $KISMET 2>/dev/null &&
         echo "source=bcm43xx,$iface,broadcom" >>$KISMET
         startStdIface $iface $CH
     fi
     if [ x$1 = "xstop" ] && [ x$2 = x$iface ]
     then
         stopStdIface $iface
     fi
     echo
     continue
 fi


 if [ x"`iwpriv $iface 2>/dev/null | grep ndis_reset`" != "x" ]
 then
     printf "$iface\t\tUnknown\t\tndiswrapper"
     if [ x$2 = x$iface ]
     then
         echo " (MONITOR MODE NOT SUPPORTED)"
     fi
     echo
     continue
 fi


printf "$iface\t\tUnknown\t\tUnknown (MONITOR MODE NOT SUPPORTED)" && echo


done


echo
