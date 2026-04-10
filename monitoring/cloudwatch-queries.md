# CloudWatch Log Insights Queries

Log group: /pokeshop

## All errors across both namespaces
```
fields @timestamp, @message, kubernetes.namespace_name, kubernetes.container_name
| filter kubernetes.namespace_name in ["pokeshop-dev", "pokeshop-prod"]
| filter @message like /ERROR|error|Error/
| sort @timestamp desc
| limit 100
```

## Logs from a specific service
```
fields @timestamp, @message
| filter kubernetes.container_name = "auth-service"
| sort @timestamp desc
| limit 50
```

## Request counts per service (last hour)
```
fields @timestamp, @message, kubernetes.container_name
| filter @message like /POST|GET|DELETE/
| stats count() by kubernetes.container_name
```

## 5xx errors only
```
fields @timestamp, @message, kubernetes.namespace_name
| filter @message like /5[0-9][0-9]/
| sort @timestamp desc
| limit 100
```
