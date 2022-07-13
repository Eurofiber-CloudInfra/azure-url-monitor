targetScope = 'resourceGroup'

// PARAMETERS
param location string
param tags object

@description('Log Analytics Workspace resource id which the alert rule is scoped to')
param log_id string

@description('Resource group name of the Container Instance resource')
param ci_rg_name string

@description('Name of the Container Instance resource')
param ci_name string

@description('Name of the Container running the url monitor')
param container_name string

@description('Name of the alert')
param alert_displayname string

@minValue(0)
@maxValue(4)
@description('''
Alert Severity:
0 = critical
1 = error
2 = warning
3 = informational
4 = verbose
''')
param severity int = 2

// VARIABLES
var _query_tpl = '''
  ContainerEvent_CL
  | where ResourceGroup == '{0}'
  | where ContainerGroup_s == '{1}'
  | where ContainerName_s == '{2}'
  | where Reason_s == 'BackOff'
'''
var _query = format(_query_tpl, ci_rg_name, ci_name, container_name)

//RESOURCES
resource alert 'microsoft.insights/scheduledqueryrules@2021-08-01' = {
  name: alert_displayname
  location: location
  tags: tags
  kind: 'LogAlert'
  properties: {
    description: alert_displayname
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
