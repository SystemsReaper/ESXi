#!/bin/sh
#vim-cmd vmsvc/getallvm


########### Functions ###########

clone_procedure(){
	vmstate=$(vim-cmd vmsvc/power.getstate $vmid | tail -1)
	echo 'Virtual machine is in "'$vmstate'" state.'
	read -p "Enter new VM name: " new_vm

	echo 'New VM name: "'$new_vm'"'
	echo 'Selected VM name: "'$vmname'"'
	echo 'Selected VM VMX Path: "'$vmxpath'"'
	echo 'Selected VM VMDK Path: "'$vmdkpath'"'
#	echo 'Selected VMX_filename atribute: "'$vmx_filename'"'
	echo 'Selected datastore path: "'$defaultpath'"'
	echo 'Default selected VM path: "'$default_datastore_path'"'
	new_path=$defaultpath/$new_vm
	echo 'Cloned VM Path:"'$new_path'"'
	mkdir -p $new_path
	source=$(echo ''$vmx_filename'= "'$vmdkfile'"')
	destination=$(echo ''$vmx_filename'= "'$new_vm'.vmdk"')
#	echo $source
#	echo $destination
	vmkfstools -i $default_datastore_path/$vmdkpath -d thin $new_path/$new_vm.vmdk
	cp $default_datastore_path/$vmxpath $new_path/$new_vm.vmx
	sed -i 's/displayName = "'$vmname'"/displayName = "'$new_vm'"/g' $new_path/$new_vm.vmx
	sed -i "s/$source/$destination/g" $new_path/$new_vm.vmx
#	echo "s/$source/$destination/g"

}

log_poweroff(){
	
	grep "$vmname" /var/log/hostd.log | grep "powered off" | tail -1
}

log_poweron(){
	vmname=$(vim-cmd vmsvc/get.summary $id | grep name | cut -d '"' -f2)
	grep "$vmname" /var/log/hostd.log | grep "powered on" | tail -1
}


############# MAIN ###########
echo "
  _______ _            ______  _______   _______    _____           _       _   
 |__   __| |          |  ____|/ ____\ \ / /_   _|  / ____|         (_)     | |  
    | |  | |__   ___  | |__  | (___  \ V /  | |   | (___   ___ _ __ _ _ __ | |_ 
    | |  | '_ \ / _ \ |  __|  \___ \  > <   | |    \___ \ / __| '__| | '_ \| __|
    | |  | | | |  __/ | |____ ____) |/ . \ _| |_   ____) | (__| |  | | |_) | |_ 
    |_|  |_| |_|\___| |______|_____//_/ \_\_____| |_____/ \___|_|  |_| .__/ \__|
                                                                     | |        
                                                                     |_|        


"
  echo "##############################"
  echo "Choices: "
  echo "1 - List all VMs"
  echo "2 - Clone VM"
  echo "3 - Get VM config"
  echo "##############################"
read -p "Enter your choice:" command
case "$command" in
  help)
  echo "##############################"
  echo "Choices: "
  echo "1 - List all VMs"
  echo "2 - Clone VM"
  echo "3 - Get VM config"
  echo "##############################"
  ;;
  1)
  echo "VMs List:"
    vim-cmd vmsvc/getallvms
    ;;
  2)
  echo "Selected Option: Cloning"
  echo "###################################################################"
  echo "VMs List:"
	vim-cmd vmsvc/getallvms
	echo "Datastores:"
  echo "###################################################################"
  datastore_name=$(vim-cmd hostsvc/datastore/listsummary | grep name | cut -d '"' -f2)

	echo '"Available Datastores: "'
	for name in $datastore_name
	do
	datastore_url=$(vim-cmd hostsvc/datastore/summary $name | grep url | cut -d '"' -f2)
	datastore_capacity=$(vim-cmd hostsvc/datastore/summary $name | grep capacity | cut -d '"' -f2)
	datastore_free=$(vim-cmd hostsvc/datastore/summary $name | grep freeSpace | cut -d '"' -f2)
    echo "Datastore: $name $datastore_url $datastore_capacity $datastore_free"
	echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
	done
	defaultdatastore=datastore1
	echo 'Default datastore: "'$defaultdatastore'"'
	read -p "Change datastore?(yes/y or no/n): " datpath
	
	if [[ "$datpath" == "yes" || "$datpath" == "y" ]]; then
	read -p "Enter datastore name: " name
	defaultpath=$(vim-cmd hostsvc/datastore/summary $name | grep url | cut -d '"' -f2)
	echo '"Entered datastore path: '$defaultpath'"'
	else
	defaultpath=/vmfs/volumes/datastore1
	echo 'Default path: "'$defaultpath'"'
	fi
  echo "###################################################################"
  read -p "Enter VM ID which you want to clone: " vmid
  echo "Checking VM state..."
	vmstate=$(vim-cmd vmsvc/power.getstate $vmid | tail -1)
	vmname=$(vim-cmd vmsvc/get.summary $vmid | grep name | cut -d '"' -f2)
	vmdkpath=$(vim-cmd vmsvc/get.filelayout $vmid | grep ".vmdk" | cut -d '"' -f2 | cut -d ']' -f2 | cut -d ' ' -f2)
	vmxpath=$(vim-cmd vmsvc/get.filelayout $vmid | grep vmPathName | cut -d '"' -f2 | cut -d ']' -f2 | cut -d ' ' -f2)
	vmdkfile=$(echo "$vmdkpath" | cut -d '/' -f2)
	default_datastore_name=$(vim-cmd vmsvc/get.filelayout $vmid | grep vmPathName | cut -d ']' -f1 | cut -d '[' -f2)
	default_datastore_path=$(vim-cmd hostsvc/datastore/summary $default_datastore_name | grep url | cut -d '"' -f2)
	vmx_filename=$(grep "$vmdkfile" $default_datastore_path/$vmxpath | cut -d '=' -f1)
	
	
  if [[ "$vmstate" == "Powered on" ]]; then
   echo 'Virtual machine is in "'$vmstate'" state.'
   read -p "Turn off this VM?[yes|y/no|n]: " powerstate
	if [[ "$powerstate" == "yes" || "$powerstate" == "y" ]]; then
		vim-cmd vmsvc/power.off $vmid
		sleep 10
		log_poweroff
		clone_procedure
		log_poweron	id=$(vim-cmd solo/registervm $new_path/$new_vm.vmx | awk '{print $NF}')
		echo "New VM ID: $id"
		vim-cmd vmsvc/power.on $id
		sleep 10
		log_poweron
		
		
	else
		echo "VM is not turning off"
	fi
   elif [[ "$vmstate" == "Powered off" ]]; then
	clone_procedure
	id=$(vim-cmd solo/registervm $new_path/$new_vm.vmx | awk '{print $NF}')
	echo "New VM ID: $id"
	vim-cmd vmsvc/power.on $id
	sleep 10
	log_poweron
	
	else
	echo 'Wrong VM state "'$vmstate'"'
	fi
  ;;
  3)
  echo "============Chosen get VM config=============="
  vim-cmd vmsvc/getallvms
  read -p "Enter VM ID: " vmid
  vim-cmd vmsvc/get.config $vmid
  ;;
  *)
  echo "Unknown command: $command"
  echo 'Please enter: "help" to list all available commands'
  ;;

esac
