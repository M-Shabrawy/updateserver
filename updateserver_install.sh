#!/bin/bash

# FireEye HX AV Update Server Installer script
# Version: 1.0.0
# Created 09/06/2021
# By: Mohamed Al-Shabrawy
# Usage: sudo sh ./updateserver_install.sh.sh


# Exit if this is not some sort of RedHat/CentOS Release
if [[ ! -f /etc/redhat-release ]] ; then
    echo "  Error: not a RedHat/CentOS release, exiting."
    exit
fi

echo
echo "FireEye HX AV Update Server Installer v1.0.0"
echo

read -p "Enter Bitdefender mirroring location [/usr/local/bitdefender/]: " mirrorPath
mirrorPath=${mirrorPath:-/usr/local/bitdefender/}
echo $mirrorPath

read -p "Enter the IP address of the LogRhythm Platform Manager database: " dbIP
echo

echo "Enter the user for the LogRhythm Platform Manager database."
echo "This should be the lrsommapp least privileged user."
read -p "DB Username: " dbUserName
echo

echo
read -s -p "Enter the password for the LogRhythm Platform Manager database: " dbPassword
echo


read -p "Enter the IP address(es) of the LogRhythm Data Indexer: " dxIP
echo

read -p "Enter the Type of LogRhythm Data Indexer [XM/DX]: " dxType
echo


echo "Starting installation..."
echo
echo

if [[ dxType -eq 'XM' ]] ; then
    echo 'Please Excute XM_Setup.ps1 on XM using PowerShell'
    read -p 'Once done press ENTER to continue:'
elif [[ dxType -eq 'DX' ]] ; then
    echo 'Connecting to DX'
    read -p 'Please enter logrhythm account password:' dxPass
    read -p 'Enter DX IP:' dxIP
    $(sshpass -p $dxPass ssh logrhythm@$dxIP firewall-cmd --permanent --add-port=9200/tcp --add-source $externalIP/32)
    $(sshpass -p $dxPass ssh logrhythm@$dxIP firewall-cmd --reload) 
else
  read -p 'Invalid DX Type, press ENTER to exit:'
  exit
fi

yum install --assumeyes net-tools

yum install --assumeyes java
echo 'Installed java'

firewall-cmd --permanent --add-port=5601/tcp
firewall-cmd --reload

/bin/systemctl daemon-reload

###### Begin Kibana Install ##########
rpm -ihv https://artifacts.elastic.co/downloads/kibana/kibana-5.6.16-x86_64.rpm
echo 'Installed kibana'

/bin/systemctl daemon-reload 
/bin/systemctl enable kibana.service

sed -i "s/#server.host:.*/server.host: \"$externalIP\"/" /etc/kibana/kibana.yml
sed -i 's/#elasticsearch.url:.*/elasticsearch.url: "http:\/\/'$dxIP':9200\"/' /etc/kibana/kibana.yml

/bin/systemctl start kibana.service
##### End Kibana Install ###########


##### SQL JDBC Driver Install ##########
sqlDriver="${script_full_path}/sqljdbc_4.2.8112.200_enu.tar.gz"
if [ ! -d /opt/sqljdbc_4.2 ]; then
  echo "/opt/sqljdbc_4.2 does not exist, check if ${sqlDriver} is present"
  if [ -f "$sqlDriver" ]; then
    echo "${sqlDriver} file present, extracting to /opt"
    tar -zxf "$sqlDriver" -C /opt
  else
    echo "file ${sqlDriver} not found"
  fi	
else
  echo "directory /opt/sqljdbc_4.2 already exists"
fi
echo "Installed ${sqlDriver}"

##### Begin LogStash install #########
rpm -ihv https://artifacts.elastic.co/downloads/logstash/logstash-5.6.16.rpm
echo 'Installed logstash'
cp cases.conf /etc/logstash/conf.d/
echo 'Installed LogRhythm SOMM Metrics App logstash conf file'

echo "Updating cases.conf"
sed -i "s/sqlserver:\/\/0.0.0.0/sqlserver:\/\/$dbIP/" /etc/logstash/conf.d/cases.conf
sed -i "s/jdbc_user => \"sa\"/jdbc_user => \"$dbUserName\"/" /etc/logstash/conf.d/cases.conf
sed -i 's/jdbc_password =>.*/jdbc_password => \"'$dbPassword'\"/' /etc/logstash/conf.d/cases.conf
sed -i 's/hosts =>.*/hosts => \[\"'$dxIP'\"\]/' /etc/logstash/conf.d/cases.conf
chmod 660 "/etc/logstash/conf.d/cases.conf"

scp 

### LogStash aggregate plugin
echo 'Installing LogStash Aggregate Plugin'
echo 'This will take some, Please wait'
/usr/share/logstash/bin/logstash-plugin install logstash-filter-aggregate

### Start LogStatsh service
echo 'Starting LogStash service'
systemctl start logstash
echo 'Started LogStash service'
### End logstash ####################

echo
echo
echo
echo Finished installing the LogRhythm SOMM Metrics App
echo
echo