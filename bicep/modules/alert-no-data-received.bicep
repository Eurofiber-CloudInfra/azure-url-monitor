targetScope = 'resourceGroup'

// PARAMETERS
param location string
param tags object

@description('Application Insights resource id which the alert rule is scoped to')
param application_insights_id string

@description('Name of the alert')
param alert_displayname string

@description('How often the log alert is evaluated represented in ISO 8601 duration format')
param evaluation_frequency string = 'PT5M'

@description('The period of time (in ISO 8601 duration format) that is used to monitor alert activity based on the threshold')
param windows_size string = 'PT5M'

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
param severity int = 1

// VARIABLES
var _query = '''
availabilityResults
| where customDimensions.monitor_type == 'azure-url-monitor'
'''

//RESOURCES
resource alert 'microsoft.insights/scheduledqueryrules@2021-08-01' = {
  name: alert_displayname
  location: location
  tags: tags
  kind: 'LogAlert'
  properties: {
    description: alert_displayname
    enabled: true
    autoMitigate: true
    severity: severity
    evaluationFrequency: evaluation_frequency
    windowSize: windows_size
    skipQueryValidation: true
    criteria: {
      allOf: [
        {
            query: _query
            timeAggregation: 'Count'
            dimensions: []
            operator: 'LessThanOrEqual'
            threshold: 0
            failingPeriods: {
              numberOfEvaluationPeriods: 2
              minFailingPeriodsToAlert: 2
            }
        }
      ]
    }
    scopes: [
      application_insights_id
    ]
    actions: {
      actionGroups: []
    }
  }
}
