targetScope = 'subscription'

param location string
param AddressSpace string
param deployBastionInHub bool
param bastionSku string
param adminUsername string
@secure()
param adminPassword string
param deployVMinHub bool
param deployFirewallInHub bool
param AzureFirewallTier string
param hubRgName string
param deployFirewallrules bool
param deployUDRs bool
param deployGatewayInHub bool
param vmSize string
param tagsByResource object
param osType string
param AllSpokeAddressSpaces array

param vpnGwEnebaleBgp bool
param vpnGwBgpAsn int

param diagnosticWorkspaceId string

var vnetAddressSpace = replace(AddressSpace, '/16', '/24')
var defaultSubnetPrefix = replace(vnetAddressSpace, '/24', '/26')
var firewallSubnetPrefix = replace(vnetAddressSpace, '0/24', '64/26')
var bastionSubnetPrefix = replace(vnetAddressSpace, '0/24', '128/27')
var gatewaySubnetPrefix = replace(vnetAddressSpace, '0/24', '160/27')

var vmName = 'VM-Hub'
var nsgName = 'NSG-Hub'
var bastionName = 'Bastion-Hub'
var rtNameDefSubnet = 'RT-Hub-DefaultSubnet'
var rtNameVPNgwSubnet = 'RT-Hub-GatewaySubnet'
var hubVnetName = 'VNET-Hub'
var firewallName = 'Firewall-Hub'
var gatewayName = 'Gateway-Hub'

resource hubrg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: hubRgName
  location: location
  tags: contains(tagsByResource, 'Microsoft.Resources/subscriptions/resourceGroups') ? tagsByResource['Microsoft.Resources/subscriptions/resourceGroups'] : {}
}

module vnet 'modules/vnet.bicep' = {
  scope: hubrg
  name: 'hubvnet'
  params: {
    location: location
    vnetAddressSpcae: vnetAddressSpace
    nsgID: nsg.outputs.nsgID
    rtDefID: deployFirewallInHub && deployUDRs ? rtDefault.outputs.rtID : 'none'
    rtGwID: deployFirewallInHub && deployGatewayInHub? rtvpngw.outputs.rtID : 'none'
    vnetname: hubVnetName
    defaultSubnetPrefix: defaultSubnetPrefix
    bastionSubnetPrefix: bastionSubnetPrefix
    firewallSubnetPrefix: firewallSubnetPrefix
    GatewaySubnetPrefix: gatewaySubnetPrefix
    deployBastionSubnet: deployBastionInHub
    deployFirewallSubnet: deployFirewallInHub
    deployGatewaySubnet: deployGatewayInHub
    tagsByResource: tagsByResource
    diagnosticWorkspaceId: diagnosticWorkspaceId
  }
}

module vm 'modules/vm.bicep' = if (deployVMinHub) {
  scope: hubrg
  name: 'virtualMachine'
  params: {
    adminPassword: adminPassword
    adminUsername: adminUsername
    location: location
    subnetID: vnet.outputs.defaultSubnetID
    vmName: vmName
    vmSize: vmSize
    tagsByResource: tagsByResource
    osType: osType
    diagnosticWorkspaceId: diagnosticWorkspaceId
  }
}

module nsg 'modules/nsg.bicep' = {
  scope: hubrg
  name: 'nsg'
  params: {
    location: location
    nsgName: nsgName
    tagsByResource: tagsByResource
    diagnosticWorkspaceId: diagnosticWorkspaceId
  }
}

module bastion 'modules/bastion.bicep' = if (deployBastionInHub) {
  scope: hubrg
  name: 'bastion'
  params: {
    location: location
    subnetID: deployBastionInHub ? vnet.outputs.bastionSubnetID : ''
    bastionName: bastionName
    tagsByResource: tagsByResource
    bastionSku: bastionSku
    diagnosticWorkspaceId: diagnosticWorkspaceId
  }
}

module firewall 'modules/firewall.bicep' = if (deployFirewallInHub) {
  scope: hubrg
  name: 'hubFirewall'
  params: {
    deployInVWan: false
    location: location
    firewallName: firewallName
    azfwsubnetid: deployFirewallInHub ? vnet.outputs.firewallSubnetID : ''
    azfwTier: AzureFirewallTier
    tagsByResource: tagsByResource
    diagnosticWorkspaceId: diagnosticWorkspaceId
  }
}

module firewallrules 'modules/firewallpolicyrules.bicep' = if (deployFirewallrules && deployFirewallInHub) {
  scope: hubrg
  name: 'firewallRules'
  params: {
    azFwPolicyName: deployFirewallInHub && deployFirewallrules ? firewall.outputs.azFwPolicyName : ''
    AddressSpace: AddressSpace
  }
}

module rtDefault 'modules/routetable.bicep' = if (deployFirewallInHub && deployUDRs) {
  scope: hubrg
  name: 'routeTable-Default'
  params: {
    location: location
    rtName: rtNameDefSubnet
    tagsByResource: tagsByResource
  }
}

module routeDefault1 'modules/route.bicep' = if (deployFirewallInHub && deployUDRs) {
  scope: hubrg
  name: 'RouteToInternet'
  params: {
    routeAddressPrefix: '0.0.0.0/0'
    routeName: deployFirewallInHub && deployUDRs ? '${rtDefault.outputs.rtName}/toInternet' : 'dummy1'
    routeNextHopIpAddress: deployFirewallInHub && deployUDRs ? firewall.outputs.azFwIP : '1.2.3.4'
  }
}

module routeDefault2 'modules/route.bicep' = [for (addressRange, i) in AllSpokeAddressSpaces : if (deployFirewallInHub && deployUDRs) {
  scope: hubrg
  name: 'RouteToLocal${i}'
  params: {
    routeAddressPrefix: addressRange
    routeName: deployFirewallInHub && deployUDRs ? '${rtDefault.outputs.rtName}/LocalRoute${i}' : 'dummy2'
    routeNextHopIpAddress: deployFirewallInHub && deployUDRs ? firewall.outputs.azFwIP : '1.2.3.4'
  }
}]

module vpngw 'modules/vpngateway.bicep' = if (deployGatewayInHub) {
  scope: hubrg
  name: gatewayName
  params: {
    location: location
    vpnGatewayName: gatewayName
    vpnGatewaySubnetID: deployGatewayInHub ? vnet.outputs.gatewaySubnetID : ''
    tagsByResource: tagsByResource
    vpnGatewayBgpAsn: vpnGwEnebaleBgp ? vpnGwBgpAsn : 65515
    vpnGatewayEnableBgp: vpnGwEnebaleBgp
    diagnosticWorkspaceId: diagnosticWorkspaceId
  }
}

module rtvpngw 'modules/routetable.bicep' = if (deployFirewallInHub && deployGatewayInHub && deployUDRs) {
  scope: hubrg
  name: 'routeTable-VPNGW'
  params: {
    location: location
    rtName: rtNameVPNgwSubnet
  }
}

module routeVPNgw 'modules/route.bicep' = [for (addressRange, i) in concat(AllSpokeAddressSpaces,array(defaultSubnetPrefix)) : if (deployFirewallInHub && deployGatewayInHub && deployUDRs) {
  scope: hubrg
  name: 'Route-vpngw${i}'
  params: {
    routeAddressPrefix: addressRange
    routeName: deployFirewallInHub && deployGatewayInHub && deployUDRs ? '${rtvpngw.outputs.rtName}/LocalRoute${i}' : 'dummy3'
    routeNextHopIpAddress: deployFirewallInHub && deployUDRs ? firewall.outputs.azFwIP : '1.2.3.4'
  }
}]

output hubVnetID string = vnet.outputs.vnetID
output azFwIp string = deployFirewallInHub ? firewall.outputs.azFwIP : '1.2.3.4'
output HubResourceGroupName string = hubrg.name
output hubVnetName string = vnet.outputs.vnetName
output hubVnetAddressSpace string = vnetAddressSpace
output hubDefaultSubnetPrefix string = defaultSubnetPrefix
output hubGatewayPublicIP string = deployGatewayInHub ? vpngw.outputs.vpnGwPublicIP : 'none'
output hubGatewayID string = deployGatewayInHub ? vpngw.outputs.vpnGwID : 'none'
output HubGwBgpPeeringAddress string = deployGatewayInHub ? vpngw.outputs.vpnGwBgpPeeringAddress : 'none'
output HubVmResourceID string = deployVMinHub ? vm.outputs.vmResourceID : 'none'
