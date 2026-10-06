targetScope = 'resourceGroup'

param lockName string
param notes string = 'CanNotDelete lock.'

resource lock 'Microsoft.Authorization/locks@2020-05-01' = {
  name: lockName
  properties: {
    level: 'CanNotDelete'
    notes: notes
  }
}
