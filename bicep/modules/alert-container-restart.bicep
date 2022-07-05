targetScope = 'resourceGroup'

param location string
param log_id string
param tags object
param ci_rg_name string
param ci_name string
param container_name string

param alert_name string = 'Azure URL Monitor Container Restarted'
@minValue(0)
@maxValue(4)
@description('''
0 = critical
1 = error
2 = warning
3 = informational
4 = verbose
''')
param severity int = 2

var _query_tpl = '''
  ContainerEvent_CL
  | where ResourceGroup == '{0}'
  | where ContainerGroup_s == '{1}'
  | where ContainerName_s == '{2}'
  | where Reason_s == 'BackOff'
'''
var _query = format(_query_tpl, ci_rg_name, ci_name, container_name)

resource alert 'microsoft.insights/scheduledqueryrules@2021-08-01' = {
  name: alert_name
  location: location
  tags: tags
  kind: 'LogAlert'
  properties: {
    description: alert_name
    enabled: true
    autoMitigate: false 
    severity: severity
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    skipQueryValidation: true
    criteria: {
      allOf: [
        {
            query: _query
            timeAggregation: 'Count' 
            dimensions: []
            operator: 'GreaterThan'
            threshold: 0
            failingPeriods: {
                numberOfEvaluationPeriods: 1
                minFailingPeriodsToAlert: 1
            }
        }
      ]
    }
    scopes: [
      log_id
    ]
    actions: {
      actionGroups: []
    }
  }
}
