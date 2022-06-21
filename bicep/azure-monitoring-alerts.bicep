targetScope = 'resourceGroup'

param log_analytics_workspace_resource_id string
param location string = resourceGroup().location

param evaluationFrequency string = 'PT5M'
param minFailingPeriodsToAlert int = 1
param numberOfEvaluationPeriods int = 1
@allowed([
  'Equals' 
  'GreaterThan' 
  'GreaterThanOrEqual' 
  'LessThan' 
  'LessThanOrEqual' 
])
param operator string = 'GreaterThanOrEqual'
param name_base string = 'Web test "{0}" failed' 
param web_tests_names array
@allowed([
  0 // critical
  1 // error
  2 // warning
  3 // informational
  4 // verbose
])
param severity int = 2
param threshold int = 2

var _query_base = '''
    AppAvailabilityResults
    | where Name == "{0}"
    | where Success == false
    | project TimeGenerated
    '''

resource alert_error 'Microsoft.Insights/scheduledQueryRules@2021-08-01' = [for (web_test_name, i) in web_tests_names: {
  name: 'web_test_name_${i}'
  location: location
  properties: {
    displayName: format(name_base, web_test_name)
    description: '${format(name_base, web_test_name)} at least ${threshold} times in ${evaluationFrequency}'
    enabled: true
    autoMitigate: true 
    severity: severity
    evaluationFrequency: evaluationFrequency
    windowSize: evaluationFrequency
    overrideQueryTimeRange: null
    scopes: [
      log_analytics_workspace_resource_id
    ]
    targetResourceTypes: [
      'Microsoft.OperationalInsights/workspaces'
    ]
    checkWorkspaceAlertsStorageConfigured: false
    skipQueryValidation: false
    actions: {
      actionGroups: []
      customProperties: {}
    }
    criteria: {
      allOf: [
        {
          query: format(_query_base, web_test_name)
          timeAggregation: 'Count'
          metricMeasureColumn: null
          resourceIdColumn: null
          operator: operator
          threshold: threshold
          dimensions: null
          failingPeriods: {
            minFailingPeriodsToAlert: minFailingPeriodsToAlert
            numberOfEvaluationPeriods: numberOfEvaluationPeriods
          }
        }
      ]
    }
  }
}]
