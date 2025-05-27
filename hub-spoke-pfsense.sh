rg=hub-spoke-pfsense
location='centralindia'
vhdUri=https://wadvhds.blob.core.windows.net/vhds/pfsense.vhd
storageType=Premium_LRS
hub1_vnet_name='hub1'
hub1_vnet_address='10.1.0.0/16'
hub1_fw_subnet_name='fw'
hub1_fw_subnet_address='10.1.0.0/24'
hub1_vm_subnet_name='vm'
hub1_vm_subnet_address='10.1.1.0/24'

spoke1_vnet_name='spoke1'
spoke1_vnet_address='10.11.1.0/24'
spoke1_vm_subnet_name='vm'
spoke1_vm_subnet_address='10.11.1.0/24'

spoke2_vnet_name='spoke2'
spoke2_vnet_address='10.12.1.0/24'
spoke2_vm_subnet_name='vm'
spoke2_vm_subnet_address='10.12.1.0/24'

spoke3_vnet_name='spoke3'
spoke3_vnet_address='10.13.1.0/24'
spoke3_vm_subnet_name='vm'
spoke3_vm_subnet_address='10.13.1.0/24'

default='0.0.0.0/0'

vm_size=Standard_B2ats_v2
admin_username=$(whoami)
admin_password='Test#123#123'
myip=$(curl -s4 https://ifconfig.co/)


# create resource group
echo -e "\e[1;36mCreating $rg resource group...\e[0m"
az group create -l $location -n $rg -o none

# hub1
echo -e "\e[1;36mCreating $hub1_vnet_name VNet...\e[0m"
az network vnet create -g $rg -n $hub1_vnet_name -l $location --address-prefixes $hub1_vnet_address --subnet-name $hub1_vm_subnet_name --subnet-prefixes $hub1_vm_subnet_address -o none
az network vnet subnet create -g $rg -n $hub1_fw_subnet_name --address-prefixes $hub1_fw_subnet_address --vnet-name $hub1_vnet_name -o none

# create a managed disk from a vhd
echo -e "\e[1;36mCreating $hub1_vnet_name-fw managed disk from a vhd...\e[0m"
az disk create --resource-group $rg --name $hub1_vnet_name-fw --sku $storageType --location $location --size-gb 30 --source $vhdUri --os-type Linux
#Get the resource Id of the managed disk
diskId=$(az disk show --name $hub1_vnet_name-fw --resource-group $rg --query [id] -o tsv | tr -d '\r')

# Create pfsense VM by attaching existing managed disks as OS
echo -e "\e[1;36mCreating $hub1_vnet_name-fw VM...\e[0m"
az network public-ip create -g $rg -n $hub1_vnet_name-fw -l $location --allocation-method Static --sku Basic -o none
az network nic create -g $rg -n $hub1_vnet_name-fw-wan --subnet $hub1_fw_subnet_name --vnet-name $hub1_vnet_name --ip-forwarding true --private-ip-address 10.1.0.250 --public-ip-address $hub1_vnet_name-fw -o none
az network nic create -g $rg -n $hub1_vnet_name-fw-lan --subnet $hub1_vm_subnet_name --vnet-name $hub1_vnet_name --ip-forwarding true --private-ip-address 10.1.1.250 -o none
az vm create --name $hub1_vnet_name-fw --resource-group $rg --nics $hub1_vnet_name-fw-wan $hub1_vnet_name-fw-lan --size Standard_B2als_v2 --attach-os-disk $diskId --os-type linux
hub1_fw_public_ip=$(az network public-ip show -g $rg -n $hub1_vnet_name-fw --query 'ipAddress' -o tsv | tr -d '\r') && echo $hub1_vnet_name-fw public ip: $hub1_fw_public_ip
hub1_fw_wan_private_ip=$(az network nic show -g $rg -n $hub1_vnet_name-fw-wan --query ipConfigurations[].privateIPAddress -o tsv | tr -d '\r') && echo $hub1_vnet_name-fw wan private IP: $hub1_fw_wan_private_ip
hub1_fw_lan_private_ip=$(az network nic show -g $rg -n $hub1_vnet_name-fw-lan --query ipConfigurations[].privateIPAddress -o tsv | tr -d '\r') && echo $hub1_vnet_name-fw lan private IP: $hub1_fw_lan_private_ip

# pfsense vm boot diagnostics
echo -e "\e[1;36mEnabling VM boot diagnostics for $hub1_vnet_name-fw...\e[0m"
az vm boot-diagnostics enable -g $rg -n $hub1_vnet_name-fw -o none

# spoke1
echo -e "\e[1;36mCreating $spoke1_vnet_name VNet...\e[0m"
az network vnet create -g $rg -n $spoke1_vnet_name -l $location --address-prefixes $spoke1_vnet_address --subnet-name $spoke1_vm_subnet_name --subnet-prefixes $spoke1_vm_subnet_address -o none

# spoke2
echo -e "\e[1;36mCreating $spoke2_vnet_name VNet...\e[0m"
az network vnet create -g $rg -n $spoke2_vnet_name -l $location --address-prefixes $spoke2_vnet_address --subnet-name $spoke2_vm_subnet_name --subnet-prefixes $spoke2_vm_subnet_address -o none

# spoke3
echo -e "\e[1;36mCreating $spoke3_vnet_name VNet...\e[0m"
az network vnet create -g $rg -n $spoke3_vnet_name -l $location --address-prefixes $spoke3_vnet_address --subnet-name $spoke3_vm_subnet_name --subnet-prefixes $spoke3_vm_subnet_address -o none

# hub1 and spoke1 vnet peering
echo -e "\e[1;36mCreating VNet Peering between $hub1_vnet_name and $spoke1_vnet_name...\e[0m"
az network vnet peering create -g $rg -n $hub1_vnet_name-peering --remote-vnet $hub1_vnet_name --vnet-name $spoke1_vnet_name --allow-vnet-access -o none
az network vnet peering create -g $rg -n $spoke1_vnet_name-peering --remote-vnet $spoke1_vnet_name --vnet-name $hub1_vnet_name --allow-vnet-access --allow-forwarded-traffic -o none

# hub1 and spoke2 vnet peering
echo -e "\e[1;36mCreating VNet Peering between $hub1_vnet_name and $spoke2_vnet_name...\e[0m"
az network vnet peering create -g $rg -n $hub1_vnet_name-peering --remote-vnet $hub1_vnet_name --vnet-name $spoke2_vnet_name --allow-vnet-access -o none
az network vnet peering create -g $rg -n $spoke2_vnet_name-peering --remote-vnet $spoke2_vnet_name --vnet-name $hub1_vnet_name --allow-vnet-access --allow-forwarded-traffic -o none

# hub1 and spoke3 vnet peering
echo -e "\e[1;36mCreating VNet Peering between $hub1_vnet_name and $spoke3_vnet_name...\e[0m"
az network vnet peering create -g $rg -n $hub1_vnet_name-peering --remote-vnet $hub1_vnet_name --vnet-name $spoke3_vnet_name --allow-vnet-access -o none
az network vnet peering create -g $rg -n $spoke3_vnet_name-peering --remote-vnet $spoke3_vnet_name --vnet-name $hub1_vnet_name --allow-vnet-access --allow-forwarded-traffic -o none

# spoke1 vm
echo -e "\e[1;36mCreating $spoke1_vnet_name VM...\e[0m"
az network nic create -g $rg -n "$spoke1_vnet_name" -l $location --vnet-name $spoke1_vnet_name --subnet $spoke1_vm_subnet_name -o none
az vm create -g $rg -n $spoke1_vnet_name -l $location --image Ubuntu2404 --nics "$spoke1_vnet_name" --os-disk-name "$spoke1_vnet_name" --size $vm_size --admin-username $admin_username --generate-ssh-keys -o none
spoke1_vm_ip=$(az network nic show -g $rg -n $spoke1_vnet_name --query ipConfigurations[].privateIPAddress -o tsv | tr -d '\r') && echo $spoke1_vnet_name vm private ip: $spoke1_vm_ip

# spoke2 vm
echo -e "\e[1;36mCreating $spoke2_vnet_name VM...\e[0m"
az network nic create -g $rg -n "$spoke2_vnet_name" -l $location --vnet-name $spoke2_vnet_name --subnet $spoke2_vm_subnet_name -o none
az vm create -g $rg -n $spoke2_vnet_name -l $location --image Ubuntu2404 --nics "$spoke2_vnet_name" --os-disk-name "$spoke2_vnet_name" --size $vm_size --admin-username $admin_username --generate-ssh-keys -o none
spoke2_vm_ip=$(az network nic show -g $rg -n $spoke2_vnet_name --query ipConfigurations[].privateIPAddress -o tsv | tr -d '\r') && echo $spoke2_vnet_name vm private ip: $spoke2_vm_ip

# spoke3 vm
echo -e "\e[1;36mCreating $spoke3_vnet_name VM...\e[0m"
az network nic create -g $rg -n "$spoke3_vnet_name" -l $location --vnet-name $spoke3_vnet_name --subnet $spoke3_vm_subnet_name -o none
az vm create -g $rg -n $spoke3_vnet_name -l $location --image Ubuntu2404 --nics "$spoke3_vnet_name" --os-disk-name "$spoke3_vnet_name" --size $vm_size --admin-username $admin_username --generate-ssh-keys -o none
spoke3_vm_ip=$(az network nic show -g $rg -n $spoke3_vnet_name --query ipConfigurations[].privateIPAddress -o tsv | tr -d '\r') && echo $spoke3_vnet_name vm private ip: $spoke3_vm_ip

# spoke1 route table
echo -e "\e[1;36mCreating $spoke1_vnet_name route table....\e[0m"
az network route-table create -g $rg -n $spoke1_vnet_name -l $location -o none
az network route-table route create -g $rg -n to-default --address-prefix $default --next-hop-type virtualappliance --route-table-name $spoke1_vnet_name --next-hop-ip-address $hub1_fw_lan_private_ip -o none
az network vnet subnet update -g $rg -n $spoke1_vm_subnet_name --vnet-name $spoke1_vnet_name --route-table $spoke1_vnet_name -o none

# spoke2 route table
echo -e "\e[1;36mCreating $spoke2_vnet_name route table....\e[0m"
az network route-table create -n $spoke2_vnet_name -g $rg -l $location -o none
az network route-table route create -g $rg -n to-default --address-prefix $default --next-hop-type virtualappliance --route-table-name $spoke2_vnet_name --next-hop-ip-address $hub1_fw_lan_private_ip -o none
az network vnet subnet update -g $rg -n $spoke2_vm_subnet_name --vnet-name $spoke2_vnet_name --route-table $spoke2_vnet_name -o none

# spoke3 route table
echo -e "\e[1;36mCreating $spoke3_vnet_name route table....\e[0m"
az network route-table create -n $spoke3_vnet_name -g $rg -l $location -o none
az network route-table route create -g $rg -n to-default --address-prefix $default --next-hop-type virtualappliance --route-table-name $spoke3_vnet_name --next-hop-ip-address $hub1_fw_lan_private_ip -o none
az network vnet subnet update -g $rg -n $spoke3_vm_subnet_name --vnet-name $spoke3_vnet_name --route-table $spoke3_vnet_name -o none

#scp -o StrictHostKeyChecking=no ~/.ssh/id_rsa root@$hub1_fw_public_ip:/root/.ssh/

# copy config to pfsense
echo -e "\e[1;36mApplying config.xml to $hub1_vnet_name-fw....\e[0m"
config_file=~/config.xml
curl -o $config_file https://raw.githubusercontent.com/wshamroukh/hub-spoke-pfsense/refs/heads/main/config.xml
scp -o StrictHostKeyChecking=no $config_file root@$hub1_fw_public_ip:/conf/
az vm restart -g $rg -n $hub1_vnet_name-fw --force
rm $config_file

echo you can access pfsense web GUI interface at: https://$hub1_fw_public_ip , username: admin, password: pfsense
# cp ~/.ssh/* /mnt/c/temp
# az group delete -n $rg -y --no-wait