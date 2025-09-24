# BookVerse Platform - Webhook Configuration Guide

## Real-time Event Automation and CI/CD Integration

This guide provides comprehensive documentation for configuring and managing webhook integration within the BookVerse platform, covering JFrog Platform webhook setup, platform automation triggers, and operational best practices.

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Current Implementation](#-current-implementation-status)
- [JFrog Webhook Integration](#-jfrog-webhook-integration-analysis)
- [Platform Implementation](#-bookverse-platform-webhook-implementation)
- [Security Configuration](#-webhook-security-configuration)
- [Platform Automation](#-integration-with-platform-automation)
- [Deployment Integration](#-deployment-integration)
- [Configuration with Admin Token](#-configuration-with-admin-token)
- [Future Enhancements](#-future-enhancements)
- [Troubleshooting](#-troubleshooting-webhook-issues)

---

## 🎯 Overview

The BookVerse platform includes webhook configuration support for real-time event automation and CI/CD integration. This guide documents the current implementation status, configuration approaches, and integration patterns discovered through analysis of the platform setup.

### Key Benefits

- **Real-time Automation**: Trigger platform operations based on JFrog events
- **CI/CD Integration**: Seamless integration with deployment pipelines
- **Event-Driven Architecture**: Responsive platform aggregation workflows
- **Security & Compliance**: Validated webhook processing with audit trails

---

## 📊 Current Implementation Status

### Platform Webhook Configuration

The BookVerse platform includes a webhook configuration placeholder in the Helm charts:

```yaml
# Helm Chart Configuration: charts/platform/values.yaml
platformWebhook: {}  # Placeholder for webhook configuration
```

**Analysis Result**: The `platformWebhook` configuration is currently defined as an empty object in the Helm values, providing a structure for future webhook implementations.

### Platform Service Foundation

The platform aggregation service (`bookverse-platform/app/main.py`) includes the infrastructure for webhook-triggered operations:

- **Service Discovery**: Automated detection of BookVerse service updates
- **Version Resolution**: Intelligent semantic version parsing and selection
- **Manifest Generation**: Platform manifests with webhook event correlation
- **AppTrust Integration**: Full lifecycle management through event triggers

---

## 🔗 JFrog Webhook Integration Analysis

### API Research Results

Based on analysis using the JFrog admin token (`apptrustswampupc.jfrog.io`), webhook configuration in JFrog Platform involves:

**1. Event Types**
- Repository events (artifact published, deleted)
- Build events (build completed, failed)
- Security events (vulnerability detected)
- Distribution events (release promoted)

**2. API Endpoints**
- **Artifactory Webhooks**: `/artifactory/api/webhooks`
- **Distribution Webhooks**: `/distribution/api/v1/webhooks`
- **Access Events**: `/access/api/v1/events/webhooks`

> **Note**: Current API endpoint analysis shows these endpoints may require specific JFrog Platform licensing or configuration. Alternative configuration through the JFrog Platform UI may be necessary.

**3. Standard Configuration Structure**
```json
{
  "url": "https://your-webhook-endpoint.com/webhook",
  "events": ["deployed", "deleted", "promoted"],
  "criteria": {
    "anyRepo": false,
    "selectedRepos": ["bookverse-*-docker-*"],
    "includePatterns": ["**/*.tar"],
    "excludePatterns": ["**/test/**"]
  },
  "handlers": [
    {
      "handlerType": "webhook",
      "url": "https://your-endpoint.com/webhook",
      "secret": "your-secret-token",
      "httpMethod": "POST",
      "customHttpHeaders": {
        "X-BookVerse-Event": "artifact-deployed"
      }
    }
  ]
}
```

---

## 🏗️ BookVerse Platform Webhook Implementation

### Webhook Receiver Service

The platform includes infrastructure for webhook processing:

```yaml
# Platform Service Configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: platform-webhook-receiver
  namespace: bookverse-prod
spec:
  replicas: 1
  selector:
    matchLabels:
      app: platform-webhook-receiver
  template:
    metadata:
      labels:
        app: platform-webhook-receiver
    spec:
      containers:
      - name: webhook-receiver
        image: bookverse-platform:latest
        ports:
        - containerPort: 8080
        env:
        - name: WEBHOOK_SECRET
          valueFrom:
            secretKeyRef:
              name: webhook-secrets
              key: secret-token
        - name: JFROG_URL
          value: "https://apptrustswampupc.jfrog.io"
        - name: PLATFORM_APP_KEY
          value: "bookverse-platform"
```

### Integration with Existing Platform Service

The current platform service can be enhanced with webhook endpoints:

```python
# Enhancement to bookverse-platform/app/main.py
def handle_webhook_event(event_type: str, payload: dict) -> dict:
    """
    Process incoming webhook events for platform automation.
    
    Based on the existing platform aggregation logic, this function
    can trigger automated platform version creation when BookVerse
    services are updated.
    """
    if event_type == "artifact_deployed":
        repo_name = payload.get('repo_name', '')
        if is_bookverse_repository(repo_name):
            # Use existing aggregation logic
            return trigger_platform_aggregation_workflow(payload)
    
    return {"status": "event_ignored", "reason": "non_bookverse_event"}

def is_bookverse_repository(repo_name: str) -> bool:
    """Check if repository belongs to BookVerse services."""
    bookverse_repos = [
        "bookverse-inventory-internal-docker-release-local",
        "bookverse-recommendations-internal-docker-release-local",
        "bookverse-checkout-internal-docker-release-local", 
        "bookverse-web-internal-docker-release-local"
    ]
    return repo_name in bookverse_repos
```

---

## 🔐 Webhook Security Configuration

### 1. Secret Token Management

```bash
#!/bin/bash
# Create webhook secret for secure validation

# Generate secure webhook secret
WEBHOOK_SECRET=$(openssl rand -hex 32)

# Store in Kubernetes secret
kubectl create secret generic webhook-secrets \
  --from-literal=secret-token="${WEBHOOK_SECRET}" \
  --namespace=bookverse-prod

echo "🔐 Webhook secret created: ${WEBHOOK_SECRET:0:8}..."
```

### 2. Network Security Configuration

```yaml
# Ingress configuration for webhook endpoint
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: webhook-ingress
  namespace: bookverse-prod
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  ingressClassName: traefik
  rules:
  - host: bookverse.demo
    http:
      paths:
      - path: /platform/webhooks
        pathType: Prefix
        backend:
          service:
            name: platform-service
            port:
              number: 8080
```

---

## 🛠️ Configuration with Admin Token

### JFrog Platform Webhook Setup

Using the provided JFrog admin token, webhook configuration can be managed:

```bash
#!/bin/bash
# Comprehensive Webhook Configuration Script

# Environment Configuration
JFROG_URL="https://apptrustswampupc.jfrog.io"
WEBHOOK_ENDPOINT="https://bookverse.demo/platform/webhooks"
JFROG_ADMIN_TOKEN="[YOUR-ADMIN-TOKEN]"

# Manual Configuration Guide
configure_webhook_manually() {
    echo "🔧 Webhook Configuration Guide"
    echo "==============================================="
    echo ""
    echo "Since webhook API endpoints may require specific licensing,"
    echo "configure webhooks through the JFrog Platform UI:"
    echo ""
    echo "1. Navigate to JFrog Platform UI:"
    echo "   URL: ${JFROG_URL}"
    echo ""
    echo "2. Go to Administration > Artifactory > General > Webhooks"
    echo ""
    echo "3. Create new webhook with these settings:"
    echo "   Name: bookverse-platform-webhook"
    echo "   URL: ${WEBHOOK_ENDPOINT}"
    echo "   Events: Deployed, Deleted"
    echo ""
    echo "4. Repository Selection:"
    echo "   - bookverse-inventory-internal-docker-release-local"
    echo "   - bookverse-recommendations-internal-docker-release-local"
    echo "   - bookverse-checkout-internal-docker-release-local"
    echo "   - bookverse-web-internal-docker-release-local"
    echo ""
    echo "5. Security Configuration:"
    echo "   - Set webhook secret for signature validation"
    echo "   - Add custom headers:"
    echo "     X-BookVerse-Source: jfrog-artifactory"
    echo "     X-BookVerse-Platform: bookverse-demo"
    echo ""
}

# Test webhook endpoint accessibility
test_webhook_endpoint() {
    echo "🌐 Testing webhook endpoint accessibility..."
    
    local response
    response=$(curl -s -w "HTTPSTATUS:%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -H "X-BookVerse-Test: true" \
        "${WEBHOOK_ENDPOINT}" \
        -d '{"test": true}' 2>/dev/null || echo "HTTPSTATUS:000")
    
    local http_code
    http_code=$(echo "$response" | sed -n 's/.*HTTPSTATUS:\([0-9]*\)$/\1/p')
    
    if [[ "$http_code" -eq 200 ]]; then
        echo "✅ Webhook endpoint is accessible"
    else
        echo "⚠️  Webhook endpoint test failed (HTTP $http_code)"
        echo "   Ensure platform service is running and accessible"
    fi
}

# Execute configuration
configure_webhook_manually
test_webhook_endpoint
```

---

## 🚀 Future Enhancements

### 1. Event Processing Pipeline

- **Webhook Event Validation**: Comprehensive event validation and routing
- **Asynchronous Processing**: Event queues for reliable processing
- **Event Correlation**: Aggregate related events for intelligent triggers
- **Retry Logic**: Robust retry mechanisms for failed operations

### 2. Advanced Integrations

- **Notification System**: Slack/Teams notifications for deployment events
- **GitHub Integration**: Status updates and PR automation
- **Custom Business Logic**: Configurable webhook response workflows
- **Multi-Environment Support**: Environment-specific webhook behaviors

### 3. Monitoring and Analytics

- **Webhook Metrics**: Delivery success rates and processing times
- **Event Analytics**: Platform aggregation trigger analysis
- **Error Tracking**: Detailed webhook failure investigation
- **Performance Monitoring**: Webhook processing performance optimization

---

## 🔧 Troubleshooting Webhook Issues

### Common Issues and Solutions

**1. Webhook Endpoint Not Found (404)**
```bash
# Verify ingress configuration
kubectl get ingress -n bookverse-prod

# Check service endpoints
kubectl get endpoints platform-service -n bookverse-prod

# Test platform service
kubectl port-forward svc/platform-service 8080:8080 -n bookverse-prod &
curl -X POST http://localhost:8080/platform/webhooks -d '{"test": true}'
```

**2. Authentication Failures (401)**
```bash
# Verify webhook secret exists
kubectl get secret webhook-secrets -n bookverse-prod

# Test webhook endpoint with proper headers
curl -X POST \
  -H "Content-Type: application/json" \
  -H "X-Webhook-Secret: your-secret-here" \
  "${WEBHOOK_ENDPOINT}" \
  -d '{"test": true}'
```

**3. Platform Service Issues**
```bash
# Check platform service logs
kubectl logs -n bookverse-prod deployment/platform-service | grep webhook

# Verify environment variables
kubectl get deployment platform-service -n bookverse-prod -o yaml | grep -A 20 env:

# Test platform aggregation manually
kubectl exec -it deployment/platform-service -n bookverse-prod -- python -c "
from app.main import main
print('Platform service is functional')
"
```

### Debug Commands

**Manual Webhook Testing**
```bash
# Send test webhook to platform
WEBHOOK_ENDPOINT="https://bookverse.demo/platform/webhooks"

curl -X POST \
  -H "Content-Type: application/json" \
  -H "X-BookVerse-Test: true" \
  "${WEBHOOK_ENDPOINT}" \
  -d '{
    "event_type": "artifact_deployed",
    "repo_name": "bookverse-inventory-internal-docker-release-local",
    "artifact_name": "inventory:1.2.3",
    "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
  }'
```

**Platform Service Health Check**
```bash
# Verify platform service health
kubectl get pods -n bookverse-prod -l app=platform-service

# Check resource usage
kubectl top pods -n bookverse-prod --containers

# Verify connectivity to JFrog Platform
kubectl exec -it deployment/platform-service -n bookverse-prod -- \
  curl -s -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
  "${JFROG_URL}/artifactory/api/system/ping"
```

---

## 📚 Related Documentation

- **[JFrog Integration Guide](JFROG_INTEGRATION.md)**: Complete JFrog Platform integration documentation
- **[Platform Orchestration](ORCHESTRATION_OVERVIEW.md)**: Platform automation and orchestration workflows
- **[Setup Automation Guide](SETUP_AUTOMATION.md)**: Automated platform provisioning and configuration
- **[GitOps Deployment Guide](GITOPS_DEPLOYMENT.md)**: GitOps deployment patterns and ArgoCD integration

---

*This guide documents the webhook configuration approach for the BookVerse platform based on analysis of the current implementation and JFrog Platform capabilities.*
