targetScope = 'resourceGroup'

param tags object
param application_insights_id string
param alert_name string
@allowed([
  'Equals' 
  'GreaterThan' 
  'GreaterThanOrEqual' 
  'LessThan' 
  'LessThanOrEqual' 
])
param operator string = 'LessThanOrEqual'
param availability_percentage_threshold int = 80
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
param evaluation_frequency string = 'PT1M'
param windows_size string = 'PT15M'
param auto_mitigate bool = true

resource alert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: alert_name
  location: 'global'
  tags: tags
  properties: {
    description: alert_name
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
          threshold: availability_percentage_threshold
          name: 'availability'
          metricNamespace: 'microsoft.insights/components'
          metricName: 'availabilityResults/availabilityPercentage'
          timeAggregation: 'Average'
          operator: operator
         
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
