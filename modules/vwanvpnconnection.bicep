param location string
param linkBgpAsn int
param linkBgpPeeringAddress string
param linkPublicIP string
param vpnSiteName string
param vwanID string
param vwanHubName string
param vwanGatewayName string
@secure()
param sharedKey string
param tagsByResource object = {}

resource vpnsite 'Microsoft.Network/vpnSites@2021-05-01' = {
  name: vpnSiteName
  location: location
  properties: {
    deviceProperties: {
      deviceModel: 'LabBuilder'
      deviceVendor: 'LabBuilder'
      linkSpeedInMbps: 1000
    }
    addressSpace: {}
    vpnSiteLinks: [
      {
        name: '${vpnSiteName}-Link'
        properties: {
          linkProperties: {
            linkProviderName: 'Azure'
            linkSpeedInMbps: 1000
          }
          ipAddress: linkPublicIP
          bgpProperties: {
            asn: linkBgpAsn
            bgpPeeringAddress: linkBgpPeeringAddress
          }
        }
      }
    ]
    virtualWan: {
      id: vwanID
    }
  }
  tags: contains(tagsByResource, 'Microsoft.Network/vpnSites') ? tagsByResource['Microsoft.Network/vpnSites'] : {}
}

resource vpnconnection 'Microsoft.Network/vpnGateways/vpnConnections@2021-05-01' = {
  name: '${vwanGatewayName}/Connection-${vpnSiteName}'
  properties: {
    remoteVpnSite: {
      id: vpnsite.id
    }
    routingConfiguration: {
      associatedRouteTable: {
        id: resourceId('Microsoft.Network/virtualHubs/hubRouteTables', vwanHubName, 'defaultRouteTable')
      }
      propagatedRouteTables: {
        ids: [
          {
            id: resourceId('Microsoft.Network/virtualHubs/hubRouteTables', vwanHubName, 'defaultRouteTable')
          }
        ]
        labels: [
          'default'
        ]
      }
      vnetRoutes: {
        staticRoutes: []
      }
    }
    vpnLinkConnections: [
      {
        name: '${vpnSiteName}-Link'
        properties: {
          vpnSiteLink: {
            id: vpnsite.properties.vpnSiteLinks[0].id
          }
          enableBgp: true
          vpnConnectionProtocolType: 'IKEv2'
          sharedKey: sharedKey
          ipsecPolicies: []
          enableRateLimiting: false
          useLocalAzureIpAddress: false
          usePolicyBasedTrafficSelectors: false
          vpnLinkConnectionMode: 'Default'
        }
      }
    ]
  }
}
