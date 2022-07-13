targetScope = 'resourceGroup'

// PARAMETERS
param tags object

@description('Name of the alert that will be genrated. The alert name will be generic for all availability tests, the failed test name is in the dimension value')
param alert_displayname string

@description('Application Insights resource id which the alert rule is scoped to')
param application_insights_id string

@description('Theshold pecentage of successfull tests with "window_size". An alert is activated when the percentage is below this threshold')
param availability_threshold_percentage int = 80

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

@description('How often the metric alert is evaluated represented in ISO 8601 duration format')
param evaluation_frequency string = 'PT1M'

@description('The period of time (in ISO 8601 duration format) that is used to monitor alert activity based on the threshold')
param windows_size string = 'PT15M'

@description('The flag that indicates whether the alert should be auto resolved or not')
param auto_mitigate bool = true

// RESOURCES
resource alert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: alert_displayname
  location: 'global'
  tags: tags
  properties: {
    description: alert_displayname
    enabled: true
    autoMitigate: auto_mitigate 
    severity: severity
    evaluationFrequency: evaluation_frequency
    windowSize: windows_size
    scopes: [
      application_insights_id
    ]
    targetResourceType: 'Microsoft.Insights/components'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          threshold: availability_threshold_percentage
          name: 'availability'
          metricNamespace: 'microsoft.insights/components'
          metricName: 'availabilityResults/availabilityPercentage'
          timeAggregation: 'Average'
          operator: 'LessThan'        
          dimensions:[
            {
                name: 'availabilityResult/name'
                operator: 'Include'
                values: [
                  '*'
                ]
            }
          ]
        }
      ]
    }
  }
}
