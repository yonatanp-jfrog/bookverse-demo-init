# JFrog Unified Policy Service API Reference

## Overview

The JFrog Unified Policy Service provides comprehensive APIs for managing policies across the JFrog Platform. This service enables organizations to create, manage, and enforce policies that govern various platform resources and operations.

### Key Features

- **Policy Management**: Create and manage reusable policy templates, rules, and policies
- **Real-time Evaluation**: Evaluate policies against resources in real-time
- **Lifecycle Integration**: Integrate with JFrog lifecycle stages and gates
- **Flexible Scoping**: Apply policies at project or application level
- **Audit Trail**: Track policy evaluations and decisions

### API Architecture

The Unified Policy Service consists of three main components:

1. **Policy Administration Point (PAP)** - Manage templates, rules, and policies
2. **Policy Decision Point (PDP)** - Real-time policy evaluation
3. **Evaluation History** - Track and query past evaluations

## Authentication

All API requests require a valid JWT bearer token in the Authorization header:

```http
Authorization: Bearer <your-jwt-token>
```

### OAuth2 Scopes

| Scope | Description |
|-------|-------------|
| `system:admin` | Full system administration access |
| `policy:read` | Read access to policies, templates, and rules |
| `policy:write` | Write access to policies, templates, and rules |
| `evaluation:read` | Read access to evaluation history |
| `evaluation:write` | Write access to create evaluations |

## Base URLs

| Environment | URL |
|-------------|-----|
| Production | `https://api.jfrog.com/unifiedpolicy/api/v1` |
| Local Self-Hosted | `http://localhost:8082/unifiedpolicy/api/v1` |
| Local Multi-Tenant | `http://localhost:8182/unifiedpolicy/api/v1` |
| Staging | `https://z0appstaging.jfrogdev.org/unifiedpolicy/api/v1` |

---

## Policy Administration Point (PAP) APIs

The PAP APIs manage the lifecycle of templates, rules, and policies.

### Templates

Templates are reusable Rego policy definitions with configurable parameters.

#### List Templates

```http
GET /templates
```

**Query Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | array[string] | Filter by template IDs |
| `name` | array[string] | Filter by template names |
| `page` | integer | Page offset (default: 0) |
| `limit` | integer | Items per page (1-250, default: 100) |
| `sort_by` | string | Sort field: `name`, `created_at` |
| `sort_order` | string | Sort direction: `asc`, `desc` |

**Response:**

```json
{
  "items": [
    {
      "id": "67890",
      "name": "Security Vulnerability Template",
      "description": "Template for creating security vulnerability policies",
      "created_at": "2024-01-10T09:00:00Z",
      "created_by": "system",
      "updated_at": "2024-01-10T09:00:00Z",
      "updated_by": "system",
      "version": "1.0.0",
      "category": "security",
      "scanners": ["sca"],
      "data_source_type": "xray",
      "is_custom": false,
      "rego": "package policy\\n\\ndefault allow = false\\n\\nallow {\\n  input.parameters.severity_threshold == \"critical\"\\n  count(input.vulnerabilities) <= input.parameters.max_vulnerabilities\\n}",
      "parameters": [
        {
          "name": "severity_threshold",
          "type": "string"
        },
        {
          "name": "max_vulnerabilities",
          "type": "int"
        }
      ]
    }
  ],
  "offset": 0,
  "limit": 100,
  "page_size": 1,
  "total_count": 1
}
```

#### Create Template

```http
POST /templates
```

**Request Body:**

```json
{
  "name": "Security Vulnerability Template",
  "description": "Template for creating security vulnerability policies",
  "version": "1.0.0",
  "category": "security",
  "scanners": ["sca", "exposures"],
  "data_source_type": "xray",
  "is_custom": false,
  "rego": "package policy\\n\\ndefault allow = false\\n\\nallow {\\n  input.parameters.severity_threshold == \"critical\"\\n  count(input.vulnerabilities) <= input.parameters.max_vulnerabilities\\n}",
  "parameters": [
    {
      "name": "severity_threshold",
      "type": "string"
    },
    {
      "name": "max_vulnerabilities",
      "type": "int"
    }
  ]
}
```

#### Get Template

```http
GET /templates/{templateId}
```

#### Update Template

```http
PUT /templates/{templateId}
```

#### Delete Template

```http
DELETE /templates/{templateId}
```

### Rules

Rules are instances of templates with specific parameter values.

#### List Rules

```http
GET /rules
```

**Query Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | array[string] | Filter by rule IDs |
| `name` | array[string] | Filter by rule names |
| `scanner_types` | array[string] | Filter by scanner types |
| `template_data_source` | string | Filter by template data source |
| `template_category` | string | Filter by template category |
| `expand` | string | Expand fields: `template` |
| `page` | integer | Page offset |
| `limit` | integer | Items per page |
| `sort_by` | string | Sort field: `name`, `created_at` |
| `sort_order` | string | Sort direction: `asc`, `desc` |

#### Create Rule

```http
POST /rules
```

**Request Body:**

```json
{
  "name": "Critical Vulnerability Check",
  "description": "Checks for critical security vulnerabilities in artifacts",
  "is_custom": false,
  "template_id": "67890",
  "parameters": [
    {
      "name": "severity_threshold",
      "value": "critical"
    },
    {
      "name": "max_vulnerabilities",
      "value": "5"
    }
  ]
}
```

#### Get Rule

```http
GET /rules/{ruleId}?expand=template
```

#### Update Rule

```http
PUT /rules/{ruleId}
```

#### Delete Rule

```http
DELETE /rules/{ruleId}
```

### Policies

Policies apply rules to specific scopes and actions.

#### List Policies

```http
GET /policies
```

**Query Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `enabled` | boolean | Filter by enabled status |
| `mode` | string | Filter by mode: `block`, `warning` |
| `action_type` | string | Filter by action type: `certify_to_gate` |
| `scope_type` | string | Filter by scope type: `project`, `application` |
| `stage_key` | array[string] | Filter by stage keys |
| `stage_gate` | array[string] | Filter by gates: `entry`, `exit`, `release` |
| `project_key` | string | Filter by project key |
| `application_key` | array[string] | Filter by application keys |
| `application_labels` | object | Filter by exact label matches |
| `expand` | string | Expand fields: `rules` |

#### Create Policy

```http
POST /policies
```

**Request Body:**

```json
{
  "name": "Security Vulnerability Policy",
  "description": "Enforces security vulnerability checks for application versions",
  "enabled": true,
  "mode": "block",
  "action": {
    "type": "certify_to_gate",
    "stage": {
      "key": "qa",
      "gate": "entry"
    }
  },
  "scope": {
    "type": "project",
    "project_keys": ["prj-security"],
    "application_labels": [
      {
        "key": "environment",
        "value": "production"
      }
    ]
  },
  "rule_ids": ["12345"]
}
```

#### Get Policy

```http
GET /policies/{policyId}
```

#### Update Policy

```http
PUT /policies/{policyId}
```

#### Delete Policy

```http
DELETE /policies/{policyId}
```

---

## Policy Decision Point (PDP) APIs

The PDP APIs provide real-time policy evaluation capabilities.

### Evaluate Policies

Perform real-time policy evaluation against resources.

```http
POST /pdp/evaluate
```

**Request Body:**

```json
{
  "action": {
    "type": "certify_to_gate",
    "stage": {
      "key": "qa",
      "gate": "entry"
    }
  },
  "resource": {
    "type": "application_version",
    "key": "web-application",
    "version": "2.1.0"
  },
  "context": {
    "user": "admin",
    "timestamp": "2024-01-20T14:30:00Z"
  },
  "enrichments": {
    "project": {
      "key": "prj-security"
    },
    "application": {
      "key": "web-application",
      "labels": [
        {
          "key": "environment",
          "value": "production"
        }
      ]
    },
    "application_version": {
      "version": "2.1.0"
    }
  },
  "response_fields": [
    "resource",
    "effective_policies",
    "decision_breakdown"
  ]
}
```

**Response:**

```json
{
  "id": "eval-12345",
  "timestamp": "2024-01-20T14:30:00Z",
  "decision": "fail",
  "explanation": "Application version promotion evaluation blocked due to presence of critical vulnerability",
  "action": {
    "type": "certify_to_gate",
    "stage": {
      "key": "qa",
      "gate": "entry"
    }
  },
  "resource": {
    "identifier": {
      "type": "application_version",
      "key": "web-application",
      "version": "2.1.0"
    },
    "hierarchy": {
      "project": {
        "key": "prj-security"
      },
      "application": {
        "key": "web-application",
        "labels": [
          {
            "key": "environment",
            "value": "production"
          }
        ]
      },
      "application_version": {
        "version": "2.1.0"
      }
    }
  },
  "policies": [
    {
      "id": "1001",
      "name": "Security Vulnerability Policy",
      "enabled": true,
      "mode": "block"
    }
  ],
  "decision_breakdown": [
    {
      "id": "rule-eval-1",
      "timestamp": "2024-01-20T14:30:00Z",
      "rule_id": "12345",
      "resource": {
        "type": "application_version",
        "key": "web-application",
        "version": "2.1.0"
      },
      "input": {
        "findings": [
          {
            "id": "vuln-001",
            "severity": "critical",
            "type": "vulnerability"
          }
        ]
      },
      "output": {
        "violated_findings": ["vuln-001"],
        "decision": "fail",
        "explanation": "Critical vulnerability found"
      }
    }
  ]
}
```

### Get Effective Policies

Retrieve policies that would be evaluated for a given resource and action.

```http
POST /pdp/effective-policies
```

**Request Body:**

```json
{
  "action": {
    "type": "certify_to_gate",
    "stage": {
      "key": "qa",
      "gate": "entry"
    }
  },
  "resource": {
    "type": "application_version",
    "key": "web-application",
    "version": "2.1.0"
  },
  "enrichments": {
    "project": {
      "key": "prj-security"
    },
    "application": {
      "key": "web-application",
      "labels": [
        {
          "key": "environment",
          "value": "production"
        }
      ]
    }
  }
}
```

---

## Evaluation History APIs

The Evaluation History APIs provide access to past policy evaluations.

### List Evaluations

```http
GET /evaluations
```

**Query Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `mode` | string | Filter by policy mode |
| `resource_type` | string | Filter by resource type |
| `action_type` | string | Filter by action type |
| `stage_key` | string | Filter by stage key |
| `stage_gate` | string | Filter by gate |
| `lifecycle_stage` | object | Filter by lifecycle stage and gate combinations |
| `decision` | string | Filter by decision: `fail`, `warn`, `pass`, `error` |
| `created_by` | string | Filter by creator |
| `rule_id` | string | Filter by rule ID |
| `project_key` | string | Filter by project key |
| `application_key` | string | Filter by application key |
| `application_version` | string | Filter by application version |
| `id` | array[string] | Filter by evaluation IDs |
| `page` | integer | Page offset |
| `limit` | integer | Items per page |
| `sort_by` | string | Sort field: `timestamp`, `decision` |
| `sort_order` | string | Sort direction: `asc`, `desc` |

### Create Evaluation

```http
POST /evaluations
```

### Get Evaluation

```http
GET /evaluations/{evaluationId}
```

### Delete Evaluation

```http
DELETE /evaluations/{evaluationId}
```

---

## Data Models

### Template Categories

| Category | Description |
|----------|-------------|
| `security` | Security-related policies (vulnerabilities, secrets) |
| `legal` | Legal compliance policies (licenses, copyrights) |
| `operational` | Operational policies (performance, availability) |
| `quality` | Code quality policies (coverage, complexity) |
| `audit` | Audit and compliance tracking |
| `workflow` | CI/CD workflow policies |

### Scanner Types

| Scanner | Description |
|---------|-------------|
| `secrets` | Secret detection scanners |
| `sca` | Software Composition Analysis |
| `exposures` | Security exposure scanners |
| `contextual_analysis` | Contextual security analysis |
| `malicious_package` | Malicious package detection |

### Data Source Types

| Data Source | Description |
|-------------|-------------|
| `noop` | No external data source |
| `evidence` | Evidence-based data |
| `xray` | JFrog Xray security data |
| `catalog` | JFrog catalog data |

### Lifecycle Gates

| Gate | Description |
|------|-------------|
| `entry` | Entry gate to a lifecycle stage |
| `exit` | Exit gate from a lifecycle stage |
| `release` | Release gate for production |

### Policy Modes

| Mode | Description |
|------|-------------|
| `block` | Block operations that fail policy evaluation |
| `warning` | Allow operations but warn on policy failures |

### Evaluation Decisions

| Decision | Description |
|----------|-------------|
| `pass` | Policy evaluation passed |
| `fail` | Policy evaluation failed |
| `warn` | Policy evaluation resulted in warning |
| `error` | Error occurred during evaluation |

### Resource Types

| Resource Type | Description |
|---------------|-------------|
| `application_version` | Application version resources |
| `source_location` | Source location patterns |

---

## Error Handling

All API endpoints return consistent error responses:

### Error Response Format

```json
{
  "code": "error_code",
  "message": "Human-readable error message",
  "details": [
    {
      "property": "field_name",
      "message": "Field-specific error message"
    }
  ],
  "trace_id": "uuid-for-tracking"
}
```

### Common HTTP Status Codes

| Status | Description |
|--------|-------------|
| `200` | Success |
| `201` | Created |
| `204` | No Content (successful deletion) |
| `400` | Bad Request (validation errors) |
| `401` | Unauthorized (invalid/missing token) |
| `403` | Forbidden (insufficient permissions) |
| `404` | Not Found |
| `409` | Conflict (resource conflicts) |
| `500` | Internal Server Error |

---

## Best Practices

### Template Design

1. **Keep Rego policies simple and focused**
2. **Use descriptive parameter names**
3. **Provide clear descriptions for templates and parameters**
4. **Test templates thoroughly before deployment**

### Policy Management

1. **Use project-level scoping when possible**
2. **Apply policies incrementally (warning mode first)**
3. **Monitor evaluation results regularly**
4. **Keep rule parameters up to date**

### Performance Optimization

1. **Use efficient filters when querying evaluations**
2. **Limit response fields using response_fields parameter**
3. **Implement pagination for large result sets**
4. **Cache effective policies when appropriate**

### Security Considerations

1. **Use least-privilege OAuth2 scopes**
2. **Regularly rotate authentication tokens**
3. **Monitor policy evaluation patterns**
4. **Implement proper audit logging**

---

## Examples

### Complete Policy Workflow

Here's a complete example of creating and using policies:

#### 1. Create a Template

```bash
curl -X POST https://api.jfrog.com/unifiedpolicy/api/v1/templates \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Critical Vulnerability Policy",
    "description": "Blocks deployments with critical vulnerabilities",
    "version": "1.0.0",
    "category": "security",
    "scanners": ["sca"],
    "data_source_type": "xray",
    "is_custom": false,
    "rego": "package policy\n\ndefault allow = false\n\nallow {\n  count(input.critical_vulnerabilities) == 0\n}",
    "parameters": []
  }'
```

#### 2. Create a Rule

```bash
curl -X POST https://api.jfrog.com/unifiedpolicy/api/v1/rules \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "No Critical Vulns Rule",
    "description": "Rule to block critical vulnerabilities",
    "is_custom": false,
    "template_id": "template-id-from-step-1",
    "parameters": []
  }'
```

#### 3. Create a Policy

```bash
curl -X POST https://api.jfrog.com/unifiedpolicy/api/v1/policies \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Production Security Policy",
    "description": "Security policy for production deployments",
    "enabled": true,
    "mode": "block",
    "action": {
      "type": "certify_to_gate",
      "stage": {
        "key": "production",
        "gate": "entry"
      }
    },
    "scope": {
      "type": "project",
      "project_keys": ["my-project"]
    },
    "rule_ids": ["rule-id-from-step-2"]
  }'
```

#### 4. Evaluate a Resource

```bash
curl -X POST https://api.jfrog.com/unifiedpolicy/api/v1/pdp/evaluate \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "action": {
      "type": "certify_to_gate",
      "stage": {
        "key": "production",
        "gate": "entry"
      }
    },
    "resource": {
      "type": "application_version",
      "key": "my-app",
      "version": "1.0.0"
    },
    "enrichments": {
      "project": {
        "key": "my-project"
      }
    }
  }'
```

### Querying Evaluations

```bash
# List recent failed evaluations
curl -X GET "https://api.jfrog.com/unifiedpolicy/api/v1/evaluations?decision=fail&sort_by=timestamp&sort_order=desc&limit=10" \
  -H "Authorization: Bearer $TOKEN"

# List evaluations for a specific project
curl -X GET "https://api.jfrog.com/unifiedpolicy/api/v1/evaluations?project_key=my-project" \
  -H "Authorization: Bearer $TOKEN"

# List evaluations for a specific application version
curl -X GET "https://api.jfrog.com/unifiedpolicy/api/v1/evaluations?application_key=my-app&application_version=1.0.0" \
  -H "Authorization: Bearer $TOKEN"
```

### Working with Lifecycle Stages

```bash
# Filter evaluations by specific lifecycle stage and gate
curl -X GET "https://api.jfrog.com/unifiedpolicy/api/v1/evaluations?lifecycle_stage[0][key]=QA&lifecycle_stage[0][gate]=Entry" \
  -H "Authorization: Bearer $TOKEN"

# Filter by multiple lifecycle stages
curl -X GET "https://api.jfrog.com/unifiedpolicy/api/v1/evaluations?lifecycle_stage[0][key]=DEV&lifecycle_stage[0][gate]=Exit&lifecycle_stage[1][key]=QA&lifecycle_stage[1][gate]=Entry" \
  -H "Authorization: Bearer $TOKEN"
```

---

## Summary

This comprehensive API reference provides complete documentation for the JFrog Unified Policy Service, enabling developers to effectively integrate policy management and evaluation into their JFrog Platform workflows. 

The service provides three main API groups:
- **PAP APIs** for managing templates, rules, and policies
- **PDP APIs** for real-time policy evaluation
- **Evaluation APIs** for accessing evaluation history

Use this reference to build robust policy-driven workflows that enhance security, compliance, and governance across your JFrog Platform deployments.
