JFrog AppTrust related Operations
Application Operations
Create Application
Get Applications
Get Application Details
Update Application
Delete Application
Application Version Operations
Create Application Version
Get Application Versions
Get Application Version
Get Application Version Content
Update Application Version
Delete Application Version
Promote Application Version
Release Application Version
Roll Back Application Version Promotion
Get Application Version Promotions
Stages Operations
Create Stage
Get Stage
Get Stages
Update Stage
Delete Stage
Get Lifecycle
Update Lifecycle
Packages Operations
Get Application Packages
Get Package Versions
Bind Package
Unbind Package
Get Activity Log
AppTrust Webhooks
RLM Operations
Get Release Bundle Content
GET RBv2 Promotions

Application Operations
Create Application
API

Description
Create a new application in the system.

Request URL
POST https://{{artifactory-host}}/apptrust/api/v1/applications/

Request Headers
Parameter Name
Description






Query Parameter
Parameter Name
Type
Description








Request Body
Parameter Name
Type
Description
application_name
Required
string
Application display name. Must be 1-255 alphanumeric characters, containing underscores, hyphens and spaces. Must be unique within the scope of the project. 
application_key
Required
string
Application Key. Must be 2 - 64 lowercase alphanumeric characters, beginning with a letter, can contain dashes,  unique and immutable.
project_key
Required
string
The project key for the project that is associated with the Application.
description
string
Free text description of the application.
maturity_level
string
Default: unspecified
Maturity level of the application (unspecified, experimental, production, end_of_life).
criticality
string
Default: unspecified
The Business Criticality of the application. (unspecified, low, medium, high, critical).
labels
map[string]string
Key-value pairs to label the application. Each key and value should be free text, limited to 255 characters, beginning and ending with an alphanumeric character ([a-z0-9A-Z]) with dashes (-), underscores (_), dots (.), and alphanumerics between.
If provided, each label must have a key (mandatory), with the value being optional.
user_owners
array: string
List of application owners. User-owners are users defined in the project.
group_owners
array: string
List of application owners. Group-owners are groups defined in the project.


Response
On Success 
HTTP Return code: 201
Parameter Name
Type
Description
application_name
string
Application display name. Must be 1-255 alphanumeric characters, containing underscores, hyphens and spaces. Must be unique within the scope of the project.
application_key
string
Application Key. Must be 2 - 64 lowercase alphanumeric characters, beginning with a letter, can contain dashes,  unique and immutable.
project_key
string
The project key for the project that is associated with the Application.
description
string
Free text description of the application.
signing_key
string
The GPG/RSA key-pair name given in Artifactory. 
maturity
string
Maturity level of the application (unspecified, experimental, production, end_of_life).
criticality
string
The Business Criticality of the application. (unspecified, low, medium, high, critical).
labels
map[string]string
Key-value pairs to label the application. Each key and value should be free text, limited to 255 characters, beginning and ending with an alphanumeric character ([a-z0-9A-Z]) with dashes (-), underscores (_), dots (.), and alphanumerics between.
If provided, each label must have a key (mandatory), with the value being optional.
user_owners
array: string
List of application owners. User-owners are users defined in the project.
group_owners
array: string
List of application owners. Group-owners are groups defined in the project.



On Failure
Status Code
Description
400
Bad Request
409
Conflict
401
Bad Credentials
403
Permissions Denied



Parameter Name
Type
Description













Example
Request HTTP Example:

POST 'https://{host}.jfrog.io/apptrust/api/v1/applications'
Content-Type: application/json
Authorization: ••••••

Request Body Example:
{
    "application_name": "Catalina-App",
    "application_key": "catalina-app",
    "project_key": "catalina",
    "description": "This application contains enhancements to login performance.",
    "maturity_level": "production",
    "criticaly": "low",
    "labels": {
        "environment": "production",
        "region": "us-east"
    },
    "user_owners": { 
        "JohnD", 
        "Dave Rice", 
        "Alina Hood" 
    },
    "group_owners": { 
        "DevOps", 
        "Platform Admins" 
    }
}

Response Body Example:
{
    "application_name": "Catalina-App",
    "application_key": "catalina-app",
    "project_key": "catalina"
    "signing_key": "catalina-key",
    "description": "This application contains enhancements to login performance.",
    "maturity_level": "production",
    "criticality": "low",
    "labels": {
        "environment": "production",
        "region": "us-east"
    },
    "user_owners": [ 
        "JohnD", 
        "Dave Rice", 
        "Alina Hood" 
    ],
    "group_owners": [ 
        "DevOps", 
        "Platform Admins" 
    ]
}


CLI

Command:
jf apptrust app-create <app-key> --application-name [application-name] [--project “<project-key>”] [--desc "<description>"] [--business-criticality "<level>"] [--maturity-level "<level>"] [--labels "<key1>=<value1>;<key2>=<value2>"] [--user-owners "<user-owner1>,<user-owner2>"] [--group-owners "<group-owner1>, <group-owner2>"] [--signing-key “myKey”]
 [--spec “/file1.txt”] [--spec-vars “key1:val1, key2:val2”] 


Short command: jf at ac


Parameters:
<app-key>: Required - Application Key. Must be 2 - 64 lowercase alphanumeric characters, beginning with a letter, can contain dashes,  unique and immutable.
--application-name <application-name>: Optional - Application display name. Must be a unique string without spaces or special characters, within the scope of the project. If missing, the app-key will be used as the display name as well.
--project “<project-key>”: Project key associated with the Release Bundle version.
--desc "<description>": Optional - Free text description of the application.
--business-criticality "<level>": Optional - The Business Criticality of the application. Choices include:
unspecified (default)
low
medium
high
critical
--maturity-level "<level>": Optional - The Maturity Level of the application. Choices include:
unspecified (default)
experimental
production 
end_of_life
--labels "<key1>=<value1>; <key2>=<value2>": Optional - Key-value pairs to label the application. Each key and value should be free text, limited to 255 characters, beginning and ending with an alphanumeric character ([a-z0-9A-Z]) with dashes (-), underscores (_), dots (.), and alphanumerics between.
Example for labels: "tier" : "frontend", "release" : "canary", "AppGroup" : "wordpress"
If provided, each label must have a key (mandatory), with the value being optional.
--users-owners "<user-owner1>; <user-owner2>": Optional - List of application owners. User-owners are users defined in the project.
--groups-owners "<group-owner1>; <group-owner2>": Optional - List of application owners. Group-owners are groups defined in the project.
--spec "<path>": Optional - Path to a File Spec.
--spec-vars "<key-value-pairs>": Optional - List of variables in the form of "key1=value1;key2=value2;..." (wrapped by quotes) to be replaced in the File Spec. In the File Spec, the variables should be used as follows: ${key1}.
Description:
Creates a new application in the JFrog platform with specified display name and key. Additional details such as description, business criticality, maturity level, labels, and owners can be provided to further describe the application’s attributes.
Examples:
Basic Creation :
jf apptrust app-create myapp-001 --application-name MyApp --user-owners "john.doe"
With Optional Fields :
jf apptrust app-create myapp-001 --application-name MyApp --desc "A sample application" --business-criticality "High" --maturity-level "Production" --labels "tier:frontend; release:canary" --user-owners "john.doe;Jane.Smith"
Validation Criteria :
Ensure that the display name is unique and adheres to format constraints (no spaces, no special characters).
Application Key must be unique and immutable across the system.
All mandatory fields must be provided; appropriate error messages should be displayed if not.


Get Applications 
API

Description
Returns a list of Application and for each element include the latest version and the total number of versions.

Request URL
GET https://{{artifactory-host}}/apptrust/api/v1/applications/

Query Parameter
Parameter Name
Type
Description
project_key
string
The project key for the project that contains the applications.
offset
integer
Sets the number of records to skip before returning the query response. Used for pagination purposes.
limit
integer
Sets the maximum number of versions to return at one time. Used for pagination purposes.
Name
string
Filter by Application name based on a substring.
owners
array:string
Filter by Application owners (user or group). This filter can be used multiple times (once for each name).
maturity
string
Filter by Application maturity.
criticality
string
Filter by Application criticality.
labels
string
Filter by Application labels. This filter can be used multiple times (once for each label). The Key and Value are separated by a colon (:).
order_by
string
Default: created
Defines whether to order the application by name or created. 
order_asc
boolean
Default: false
Defines whether to list the application in ascending (true) or descending (false) order.


Request Body
Parameter Name
Type
Description








Response
On Success 
HTTP Return code: 200
Parameter Name
Type
Description
array (top-level)
array: object
The response is a top-level JSON array, where each element represents an application object.
application_name
string
Application display name. Must be 1-255 alphanumeric characters, containing underscores, hyphens and spaces. Must be unique within the scope of the project.
application_key
string
Application key must be 2 - 64 lowercase alphanumeric characters, beginning with a letter, can contain dashes,  unique and immutable.
project_key
string
The project key for the project that is associated with the Application.
project_name
string
The project name for the project that is associated with the Application.
created
string
The timestamp in ISO 8601 format indicating when the application was created.
application_version_latest
string
The latest version of the application currently by timestamp.
application_version_tag
string
A tag associated with the latest application version (e.g., stable, beta).
application_versions_count
integer
The total number of versions for the application.



On Failure
Status Code
Description
401
Bad Credentials
403
Permissions Denied



Parameter Name
Type
Description









Example
Request HTTP Example:

GET 'https://{host}.jfrog.io/apptrust/api/v1/applications?project_key=catalina&labels=environment:production&labels=region=us-east&owners=JohnD&owners=DevOps&name=backend&order_by=name&order_asc=true'
Authorization: ••••••

Request Body Example:


Response Body Example:
{
    "applications": [
        {
            "project_name": "Catalina",
            "project_key": "catalina",
            "created": "2024-05-18T11:26:02.912Z",
            "application_name": "Catalina-App",
            "application_key": "catalina-app",
            "application_version_latest": "1.0.0",
            "application_version_tag": "stable",
            "application_versions_count": 1
        },
        {
            "project_name": "Default",
            "project_key": "default",
            "created": "2024-05-18T11:25:35.936Z",
            "application_name": "Commons-App",
            "application_key": "commons-app",
            "application_version_latest": "2.1.1",
            "application_version_tag": "nightly",
            "application_versions_count": 5
        }
    ],
    "total": 2,
    "limit": 10,
    "offset": 0
}


Get Application Details
API

Description
Returns the details of a selected Application, such as its creation time, the owners, the labels, and so on.

Request URL
GET https://{{artifactory-host}}/apptrust/api/v1/applications/{{application_key}}

Query Parameter
Parameter Name
Type
Description








Request Body
Parameter Name
Type
Description








Response
On Success 
HTTP Return code: 200
Parameter Name
Type
Description
application
object


application.application_name
string
Application display name. Must be 1-255 alphanumeric characters, containing underscores, hyphens and spaces. Must be unique within the scope of the project.
application.application_key
string
Application Key. Must be 2 - 64 lowercase alphanumeric characters, beginning with a letter, can contain dashes,  unique and immutable.
application.project_name
string
The project name for the project that is associated with the Application.
application.project_key
string
The project key for the project that is associated with the Application.



On Failure
Status Code
Description
400
Bad Parameters
401
Bad Credentials
403
Permissions Denied
404
Application not found



Parameter Name
Type
Description









Example
Request HTTP Example:

GET 'https://{host}.jfrog.io/apptrust/api/v1/applications/catalina-app'
Authorization: ••••••

Request Body Example:
{
}

Response Body Example:
{
    "project_name": "Catalina"
    "project_key": "catalina"
    "application_name": "Catalina-App",
    "application_key": "catalina-app",
    "signing_key": "catalina-key",
    "description": "This application contains enhancements to login performance.",
    "maturity": "production",
    "criticality": "low",
    "labels": {
        "environment": "production",
        "region": "us-east"
    },
    "user-owners": { 
        "JohnD", 
        "Dave Rice", 
        "Alina Hood" 
    },
    "group_owners": { 
        "DevOps", 
        "Platform Admins" 
    }
}



Update Application
API

Description
Updates the details of the specified application with new data. All fields in the body are optional and only the existing fields will be replaced.

Request URL
PATCH https://{{artifactory-host}}/apptrust/api/v1/applications/{application_key}
Query Parameter
Parameter Name
Type
Description








Request Body
Parameter Name
Type
Description
application_name
string
Application display name. Must be 1-255 alphanumeric characters, containing underscores, hyphens and spaces. Must be unique within the scope of the project.
description
string
Free text description of the application.
maturity
string
Maturity level of the application (unspecified, experimental, production, end-of-life).
criticality
string
The Business Criticality of the application. (unspecified, low, medium, high, critical).
labels
map[string]string
Key-value pairs to label the application. Each key and value should be free text, limited to 255 characters, beginning and ending with an alphanumeric character ([a-z0-9A-Z]) with dashes (-), underscores (_), dots (.), and alphanumerics between.
If provided, each label must have a key (mandatory), with the value being optional.
users_owners
array: string
List of application owners. User-owners are users defined in the project.
group_owners
array: string
List of application owners. Group-owners are groups defined in the project.


Response
On Success 
HTTP Return code: 200
Parameter Name
Type
Description
application_name
string
Application display name. Must be a unique string without spaces or special characters, within the scope of the project. 
application_key
string
Application Key. Must be 2 - 64 lowercase alphanumeric characters, beginning with a letter, can contain dashes,  unique and immutable.
project_name
string
The project name for the project that is associated with the Application.
project_key
string
The project key for the project that is associated with the Application.
description
string
Free text description of the application.
signing_key
string
The GPG/RSA key-pair name given in Artifactory. 
maturity
string
Maturity level of the application (unspecified, experimental, production, end-of-life).
criticality
string
The Business Criticality of the application. (unspecified, low, medium, high, critical).
labels
map[string]string
Key-value pairs to label the application. Each key and value should be free text, limited to 255 characters, beginning and ending with an alphanumeric character ([a-z0-9A-Z]) with dashes (-), underscores (_), dots (.), and alphanumerics between.
If provided, each label must have a key (mandatory), with the value being optional.
users_owners
array: string
List of application owners. User-owners are users defined in the project.
group_owners
array: string
List of application owners. Group-owners are groups defined in the project.



On Failure
Status Code
Description
400
Bad Request
403
Permission Denied



Parameter Name
Type
Description







Example
Request HTTP Example:

PATCH 'https://{host}.jfrog.io/apptrust/api/v1/catalina-app'
Content-Type: application/json
Authorization: ••••••

Request Body Example:
{
    "application_name": "Catalina-App",
    "description": "This application contains enhancements to login performance.",
    "maturity": "production",
    "criticality": "low",
    "labels": {
        "environment": "production",
        "region": "us-east"
    },
    "user-owners": { 
        "JohnD", 
        "Dave Rice", 
        "Alina Hood" 
    },
    "group_owners": { 
        "DevOps", 
        "Platform Admins" 
    }
}

Response Body Example:
{
    "project_name": "Catalina",
    "project_key": "catalina",
    "application_name": "Catalina-App",
    "application_key": "catalina-app",
    "description": "This application contains enhancements to login performance.",
    "maturity": "production",
    "criticaly": "low",
    "labels": {
        "environment": "production",
        "region": "us-east"
    },
    "user-owners": { 
        "JohnD", 
        "Dave Rice", 
        "Alina Hood" 
    },
    "group_owners": { 
        "DevOps", 
        "Platform Admins" 
    }
}


CLI


Command:
jf apptrust app-update <app-key> [--application-name "<application-name>"]  [--desc "<description>"] [--business-criticality "<level>"] [--maturity-level "<level>"] [--labels "<key1>=<value1>; <key2>=<value2>"] [--user-owners "<user-owner1>, <user-owner2>"] [--group-owners "<group-owner1>, <group-owner2>"]


Short command: jf at au


Parameters:
<app-key>: Required - Application Key.
--application-name <application-name>: Optional - new Application display name. Must be a unique string without spaces or special characters, within the scope of the project.
--desc "<new-description>": Optional new description for the application.
--business-criticality "<level>": Optional - new Business criticality of the application. Choices include:
Unspecified
Low
Medium
High
Critical
--maturity-level "<level>": Optional - new Maturity Level of the application. Choices include:
Unspecified
Experimental
Production (default)
End Of Life
--labels "<key1>=<value1>; <key2>=<value2>": Optional - if supplied will replace the existing Key-value pairs to label the application. Each key and value should be free text, limited to 255 characters, beginning and ending with an alphanumeric character ([a-z0-9A-Z]) with dashes (-), underscores (_), dots (.), and alphanumerics between.
Example for labels: "tier" : "frontend", "release" : "canary", "AppGroup" : "wordpress"
If provided, each label must have a key (mandatory), with the value being optional.
--users-owners "<user-owner1>; <user-owner2>": Optional - List of application owners. User-owners are users defined in the project.
--groups-owners "<group-owner1>; <group-owner2>": Optional - List of application owners. Group-owners are groups defined in the project.


Description:
Updates the details of the specified application with new data.

Delete Application
API

Description
Deletes the specified application from the JFrog platform, along with all associated versions.

Request URL
DELETE https://{{artifactory-host}}/apptrust/api/v1/applications/{application_key}

Query Parameter
Parameter Name
Type
Description
async
boolean
Default: false
Determines whether the operation should be asynchronous (true) or synchronous (false).


Request Body
Parameter Name
Type
Description








Response
On Success 
HTTP Return code: 204 (synchronous) or 202 (asynchronous)
Parameter Name
Type
Description








On Failure
Status Code
Description
401
Bad Credentials
403
Permissions Denied



Parameter Name
Type
Description







Example
Request HTTP Example:

DELETE 'https://{host}.jfrog.io/apptrust/api/v1/applications/catalina-app'
Authorization: ••••••

Request Body Example:


Response Body Example:
{
}


CLI
Command:
jf apptrust app-delete <app-key>


Short command: jf at ad


Parameters:
<app-key>: The application key for the application to be deleted.
Description:
Deletes the specified application from the JFrog platform, along with all associated versions.

Application Version Operations
Create Application Version
API

Description
Create an application version.

Request URL
POST https://{{artifactory-host}}/apptrust/api/v1/applications/{{application_key}}/versions/

Request Headers
Parameter Name
Description
X-JFrog-Signing-Key-Name
The GPG/RSA key-pair name given in Artifactory. If the key isn't provided, the command creates or uses the default key.


Query Parameter
Parameter Name
Type
Description
async
boolean
Default: true
Whether to perform the promotion operation asynchronously (true) or synchronously (false).


Request Body
Parameter Name
Type
Description
version
Required
string
The application version to be created.It is recommended to use ​SemVer​​ formatting to maintain clarity and support your CI/CD pipeline automations.
sources
array: object
A list of sources to include in the version. Sources can be artifacts, packages, builds, release bundles, or other versions (from either this or other applications).
sources.aql
object
The contents of the AQL query to include.
sources.skip_docker_manifest_resolution
boolean
Default: false
Controls whether docker manifest resolution should be skipped
sources.artifacts
array: object
A list of artifacts to include.
sources.artifacts.path
Required
string
The path to the artifact.
sources.artifacts.sha256
string
The artifact’s SHA256.
sources.packages
array: object
A list of packages to include.
sources.packages.type
Required
string
The package type.
sources.packages.name
Required
string
The package name.
sources.packages.version
Required
string
The package version.
sources.builds
array: object
A list of package names/versions to include.
sources.builds.repository_key
string
The repository key of the build. If omitted, the system uses the default built-in repository artifactory-build-info.
sources.builds.name
Required
string
The build name.


sources.builds.number
Required
string
The build number (run).
sources.builds.started
string
Timestamp when the build was created. If omitted, the system uses the latest build run, as identified by the build_name and build_number combination.
The timestamp is provided according to the ISO 8601 standard.
sources.builds.include_dependencies


Determines whether to include build dependencies in the Release Bundle. 
sources.release_bundles
array: object
A list of release bundles to include
sources.release_bundles.project_key
Required
string
The project key of the release bundle
sources.release_bundles.repository_key
Required
string
The bundle repo
sources.release_bundles.name
Required
string
The release bundle name
sources.release_bundles.version
Required
string
The release bundle version
sources.versions
array: object


sources.versions.application_key
string
Default: same application_key as the application for which the version is created
sources.versions.version
Required
string


tag
string
A tag to be associated with the Release Bundle.  A tag is a single free text value, limited to 128 characters, beginning and ending with an alphanumeric character ([a-z0-9A-Z]) with dashes (-), underscores (_), dots (.), and alphanumerics between. Usually used to represent the branch. 


Response
On Success 
HTTP Return code: 201 (synchronous) or 202 (asynchronous)
Parameter Name
Type
Description
application_key
string
The unique key of the application for which the version was created.
version
string
The version string of the newly created application version (e.g., "1.0.0").
created_by
string
The user ID that created this application version.
created
string
The ISO 8601 timestamp, indicating when the application version was created.
tag
string
The tag associated with the version, if one was provided during creation.
status
string
The initial status of the application version (e.g., "IN_PROGRESS" if async).



On Failure
Status Code
Description
400
Bad Parameters
401
Bad Credentials
403
Permissions Denied
404
Not Found 
409
Conflict



Parameter Name
Type
Description
errors
array:object
A list of error objects detailing what went wrong.
message
string
A descriptive message for a specific error.



Example
Request HTTP Example:

POST 'https://{host}.jfrog.io/apptrust/api/v1/applications/my-super-app/versions/?async=false'
X-JFrog-Signing-Key-Name: my-signing-key 
Content-Type: application/json
Authorization: ••••••

Request Body Example:
{
    "version": "1.2.3",
    "sources": {
      "artifacts": [
        {
          "path": "my-repo/path/to/artifact.jar",
          "sha256": "a1b2c3d4e5f6..."
        }
      ],
      "builds": [
        {
          "name": "my-app-build",
          "number": "15",
          "include_dependencies": "true"
        }
      ],
      "versions": [
        {
          "application_key": "alpha-app",
          "version": "2.5.0"
        }
      ]
    },
    "tag": "stable-release"
  }

Response Body Example:
{
  "application_key": "my-super-app",
  "version": "1.2.3",
  "created_by": "user@example.com",
  "created": "2025-05-30T10:00:00Z",
  "tag": "stable-release",
  "status": "IN_PROGRESS"
}


CLI


Command:
jf apptrust version-create <app-key> <version> --tag "<tag>" --packages "<package1>:<version1>,<package2>:<version2>" --source-type-builds "name=<buildname1>, id=runID1, [include-deps=true]; name=<buildName2>, id=runID2" --source-type-release-bundles "name=<release-bundle-name1>, version=<releas-bundle-version1>; name=<release-bundle-name2>, version=<release-bundle-version2>" --source-type-application-version "application-key=<appkey1>, version=<application-version1>; application-key=<appkey2>, version=<application-version2>" [--promote="<stage>"] [--spec “/file1.txt”] [--spec-vars “key1:val1, key2:val2”]


Short command: jf at vc


Parameters:
<app-key>:  Required - The application key of the application for which the version is being created.
<version>: Required - The version number (in SemVer format) for the new application version.
--tag "<tag>": Optional - A tag associated with the version. A tag is a single free text value, limited to 255 characters, beginning and ending with an alphanumeric character ([a-z0-9A-Z]) with dashes (-), underscores (_), dots (.), and alphanumerics between.
--source-type-builds: Optional - List of semicolon-separated(;) builds in the form of 'name=buildName1, id=runID1, include-deps=true; name=buildName2, id=runID2' to be included in the new bundle.
--source-type-release-bundles: Optional - List of semicolon-seperated(;) release bundles in the form of 'name=releaseBundleName1, version=version1; name=releaseBundleName2, version=version2' to be included in the new bundle. 
--source-type-application-versions: Optional - List of semicolon-seperated(;) application versions in the form of 'application-key=app_key1, version=version1;  application-key=app_key2, version=version2' to be included in the new bundle. 
--spec "<path>": Optional - Path to a File Spec.
--spec-vars "<path>": Optional - List of variables in the form of "key1=value1;key2=value2;..." (wrapped by quotes) to be replaced in the File Spec. In the File Spec, the variables should be used as follows: ${key1}.
Description:
Creates a new version of the specified application with the given version number, tag, and associated packages.



Get Application Versions


API

Description
Retrieves a list of all application versions associated with the specified application key.

Request URL
GET https://{{artifactory-host}}/apptrust/api/v1/applications/{{application_key}}/versions

Query Parameter
Parameter Name
Type
Description
filter_by
string
Defines a filter for the list of Release Bundle versions, using a semi-colon separated list of key:value pairs. Supported keys are version, created_by (prefix), tag, and release_status.
application_version
string
Filters by the application version. Supports a trailing wildcard (*) for prefix searching, and multiple comma-separated values.


created_by
string
Filters by the user who created the application version.
release_status
string
Filters by the release status of the application version (e.g. PRE_RELEASE, RELEASED, TRUSTED_RELEASE).
Supports multiple comma-separated values.
tag
string
Filters by the assigned version tag. Supports a trailing wildcard (*), and multiple comma-separated values.
order_by
string
Defines the sorting criterion. Supported values: created, created_by, release_bundle_name, release_bundle_version, release_bundle_semver. Note: release_bundle_semver is limited to the latest 1000 records and does not support pagination.
offset
integer
Sets the number of records to skip before returning the query response. Used for pagination purposes.
limit
integer
Sets the maximum number of versions to return at one time. Used for pagination purposes.
order_by
string
Default: created
Defines whether to order the application by name or created. 
order_asc
boolean
Default: false
Defines whether to list the application in ascending (true) or descending (false) order.



Request Body
Parameter Name
Type
Description








Response
On Success 
HTTP Return code: 200
Parameter Name
Type
Description
versions
array: object
A list containing objects, where each object represents a distinct application version.
versions.release_status
string
release_status | string | Indicates the release's promotion status with one of three possible values:
PRE_RELEASE: The version has not yet been promoted to PROD.
RELEASED: The version has been promoted to PROD.
TRUSTED_RELEASE: The version was promoted to PROD and evaluated by rules on the PROD release gate.
versions.current_stage
string
Indicates the most recent environment (e.g., QA, Staging) where the release bundle was successfully promoted. If the bundle has not yet been promoted, this value will be an empty string..
versions.status
string
The current status of the version based on the latest action (e.g., "success", "pending", "failed").
versions.created_by
string
The unique identifier or name of the user or process that created this version.
versions.created
string
The date and time when this version was created in ISO 8601 format.
versions.application_key
string
The key of the application this version belongs to.
versions.version
string
The specific version identifier, often following semantic versioning (e.g., "v2.1.3").
versions.tag
string
A tag used for grouping or identifying the version (e.g., "latest", "stable", "beta"). Usually represents the branch. 
versions.messages
array: object
An error message (if exists).
total
int
The total number of records returned.
limit
int
The limit value used for this request.
offset
int
The offset value used for this request.



On Failure
Status Code
Description
400
Bad Parameters
401
Bad Credentials
403
Permissions Denied
404
Version not found


Example
Request HTTP Example:

GET 'https://{host}.jfrog.io/apptrust/api/v1/applications/catalina-app/versions?limit=3&release_status=PRE_RELEASE' Authorization: •••••• 

Request Body Example:
{
}

Response Body Example:
{
  "versions": [
    {
      "version": "1.0.1",
      "tag": "release",
      "status": "COMPLETED",
      "release_status": "PRE_RELEASE",
      "current_stage": "QA",
      "created_by": "user@example.com",
      "created": "2025-07-15T09:30:00Z"
    },
    {
      "version": "1.0.0",
      "tag": "stable",
      "status": "COMPLETED",
      "release_status": "TRUSTED_RELEASE",
      "current_stage": "PROD",
      "created_by": "user@example.com",
      "created": "2025-07-14T11:20:15Z"
    },
    {
      "version": "0.9.0-beta",
      "tag": "beta",
      "status": "FAILED",
      "release_status": "PRE_RELEASE",
      "current_stage": "",
      "created_by": "automation-service",
      "created": "2025-07-11T18:05:00Z"
    }
  ],
  "total": 3,
  "limit": 3,
  "offset": 0
}





Get Application Version Content
API

Description
Retrieves the detailed content for a specified application version, including its components (artifacts, packages, builds), sources, and the ownership details for each component.

Request URL
GET https://{{artifactory-host}}/apptrust/api/v1/applications/{{application_key}}/versions/{{version}}/content

Request Headers
Parameter Name
Description
application_key
The unique key of the application.
version
The version identifier of the application version.


Query Parameter
Parameter Name
Type
Description
offset
int
Default: 0
The number of records to skip for pagination.
limit
int
Default: 25
The maximum number (up to 250) of records to return.
include
string
The level of detail for the response. Can be one of: sources, releasables,releasables_expanded.
filter_by
string
Filters the releasables list. Format: <key>:<value> separated by commas and pipe separator between types. Supported keys: package_types, source_builds, source_release_bundles, and source_application_version. 
Example:filter_by=”package_types:docker,maven|source_builds:build1:21,build2:v2|source_release_bundles:mybundle:1.22.4”
order_by
string
Default: name:asc
The field and order to sort the results by. Format: field:order. Supported fields: name, package_type, . Supported orders: asc, desc. (e.g., name:asc)


Request Body
Parameter Name
Type
Description








Response
On Success HTTP Return code: 200
Parameter Name
Type
Description
application_key
string
The key of the application this version belongs to.
version
string
The version identifier of the application version.
project_key
string
The key of the project this release bundle belongs to.
application_version_sha256
string
The application version digest.
status
string
The overall status of the release bundle version. Can be STARTED, FAILED, COMPLETED, DELETING.
created_by
string
The user ID that created this application version.
created_at
string
The ISO 8601 timestamp, indicating when the application version was created.
tag
string
A tag to be associated with the Release Bundle.  
release_status
string
The release status of the bundle. Can be PRE_RELEASE, RELEASED, or TRUSTED_RELEASE.
releasables_count	
int
The total number of releasables in the bundle.
artifacts_count
int
The total number of artifacts in the bundle.
total_size
int
The total size of all artifacts in the bundle in bytes.
releasables
array:object
An array of releasable items included in the bundle.
releasables.name
string
The name of the releasable (e.g., package name or artifact file name).
releasables.version
string
The version of the package. Empty for non-package files.
releasables.releasable_type
string
The type of releasable. .Can be an artifact or package_version.
releasables.sha256
string
The SHA256 checksum of the leading file.
releasables.package_type
string
The repo-type where the package or artifact is found (e.g., docker, maven, generic,). 
releasables.owning_application_key
string
The application key of the application that owns this releasable. null for 3rd party releasables.
releasables.connection_level
string
The ownership relationship of the releasable to the current application. Can be 1st_party, 2nd_party, 3rd_party, or unknown.
releasables.total_size
int
The total size of all artifacts in the releasable, in bytes.
releasables.sources
array:object
Describes how the releasable was added to this bundle.
releasables.sources.type
string
The type of the source (e.g., application_version,release_bundle, build, direct).
releasables.sources.application_version.application_key


The name of the source release bundle. This field only exists if the type is application_version.
releasables.sources.application_version.version


The version of the source release bundle.This field only exists if the type is application_version.
releasables.sources.release_bundle.name
string
The name of the source release bundle. This field only exists if the type is release_bundle.
releasables.sources.release_bundle.version
string
The version of the source release bundle.This field only exists if the type is release_bundle.
releasables.sources.release_bundle.repo_key
string
The repository key where the source release bundle is stored.This field only exists if the type is release_bundle.
releasables.sources.build.name
string
The name of the source build.This field only exists if the type is build.
releasables.sources.build.number
string
The number of the source build.This field only exists if the type is build.
releasables.sources.build.timestamp
string
The timestamp of when the build was created.This field only exists if the type is build.
releasables.sources.build.repo_key
string
The repository key of the build-info repository.This field only exists if the type is build.
releasables.artifacts
array:object
An array of artifacts that are part of this releasable.
releasables.artifacts.path
string
The repository path to the artifact.
releasables.artifacts.sha256
string
The SHA256 checksum of the artifact.
releasables.artifacts.size
int
The size of the artifact in bytes.
sources
array:object
A hierarchical list of sources from which this bundle was created.
sources.type
string
The type of the source (e.g., release_bundle, build, direct).
sources.build
object
Details for a build source. Present only if type is build.
sources.build.name
string
The name of the source build.
sources.build.number
string
The number of the source build.
sources.build.timestamp
string
The timestamp of when the build was created.
sources.build.repo_key
string
The repository key of the build-info repository.
sources.release_bundle
object
Details for a release_bundle source. Present only if type is release_bundle.
sources.release_bundle.name
string
The name of the source release bundle.
sources.release_bundle.version
string
The version of the source release bundle.
sources.release_bundle.repo_key
string
The repository key where the source release bundle is stored.
sources.application_version
string
Details for an application_version source. Present only if type is application_version.
sources.application_version.application_key
string
The name of the source release bundle. This field only exists if the type is application_version.
sources.application_version.version
string
The version of the source release bundle.This field only exists if the type is application_version.
sources.child_sources
array:object
A nested array of source objects, creating a hierarchy.
offset
int
The offset value used for this request.
limit
int
The limit value used for this request.



On Failure
Status Code
Description
message
400
Bad Request
The request was malformed. This could be due to an invalid value for a query parameter like view.
401
Bad Credentials
The request lacks valid authentication credentials.
403
Permissions Denied
The authenticated user does not have the necessary permissions to access the requested resource.
404
Resource not found
The requested release bundle name or version does not exist.



Parameter Name
Type
Description
status
int


message
string



Example
Query parameter ‘view=summary’ (default)
Request HTTP Example:

GET 'https://{host}.jfrog.io/apptrust/api/v1/applications/my-super-app/versions/1.2.3/content?include=releasables'
Authorization: ••••••

Request Body Example:
{
}

include=null
Response Body Example:
{
  "application_key": "my-super-app",
  "version": "1.2.3",
  "project_key": "super-proj",
  "status": "COMPLETED",
  "created_by": "user@example.com",
  "created_at": "2025-07-15T08:58:00Z",
  "tag": "stable-release",
  "release_status": "PRE_RELEASE",
  "releasables_count": 3,
  "artifacts_count": 5,
  "total_size": 15822848
}


include=sources
Response Body Example:
{
  "application_key": "my-super-app",
  "version": "1.2.3",
  "project_key": "super-proj",
  "status": "COMPLETED",
  "created_by": "user@example.com",
  "created_at": "2025-07-15T08:58:00Z",
  "tag": "stable-release",
  "release_status": "PRE_RELEASE",
  "releasables_count": 3,
  "artifacts_count": 5,
  "total_size": 15822848,
  "sources": [
    {
      "type": "build",
      "build": { "name": "my-super-app-build", "number": "15", "timestamp": "2023-10-27T08:00:00.000Z", "repo_key": "artifactory-build-info"  }
    },
    {
      "type": "version",
      "version": { "application_key": "shared-services-app", "version": "2.5.0" },
      "child_sources": [
        {
          "type": "build",
          "build": { "name": "shared-services-build", "number": "42", "timestamp": "2023-10-27T08:00:00.000Z", "repo_key": "artifactory-build-info" }
        }
      ]
    },
    {
      "type": "direct"
    }
  ]
}

include=releasables
Response Body Example:
{
  "application_key": "my-super-app",
  "version": "1.2.3",
  "project_key": "super-proj",
  "status": "COMPLETED",
  "created_by": "user@example.com",
  "created_at": "2025-07-15T08:58:00Z",
  "tag": "stable-release",
  "release_status": "PRE_RELEASE",
  "releasables_count": 3,
  "artifacts_count": 5,
  "total_size": 15822848,
  "releasables": [
    {
      "name": "my-super-app-service",
      "version": "1.2.3",
      "sha256": "a1b2c3d4e5f6...",
      "releasable_type": "package_version",
      "package_type": "docker",
      "owning_application_key": "my-super-app",
      "connection_level": "1st_party",
      "total_size": 10485760,
      "source": {
        "type": "build",
        "build": { "name": "my-super-app-build", "number": "15" }
      }
    },
    {
      "name": "com.my-org:shared-library",
      "version": "2.5.0",
      "sha256": "f6e5d4c3b2a1...",
      "releasable_type": "package_version",
      "package_type": "maven",
      "owning_application_key": "shared-services-app",
      "connection_level": "2nd_party",
      "total_size": 5242880,
      "source": {
        "type": "version",
        "version": { "application_key": "shared-services-app", "version": "2.5.0" }
      }
    },
    {
      "name": "react",
      "version": "18.2.0",
      "sha256": "c3d4e5f6a1b2...",
      "releasable_type": "package_version",
      "package_type": "npm",
      "owning_application_key": null,
      "connection_level": "3rd_party",
      "total_size": 94208,
      "source": {
        "type": "direct"
      }
    }
  ],
  "offset": 0,
  "limit": 25
}

include=sources, releasables_expanded
Response Body Example:
{
  "application_key": "my-super-app",
  "version": "1.2.3",
  "project_key": "super-proj",
  "status": "COMPLETED",
  "created_by": "user@example.com",
  "created_at": "2025-07-15T08:58:00Z",
  "tag": "stable-release",
  "release_status": "PRE_RELEASE",
  "releasables_count": 3,
  "artifacts_count": 5,
  "total_size": 15822848,
  "releasables": [
    {
      "name": "my-super-app-service",
      "version": "1.2.3",
      "sha256": "a1b2c3d4e5f6...",
      "releasable_type": "package_version",
      "package_type": "docker",
      "owning_application_key": "my-super-app",
      "connection_level": "1st_party",
      "total_size": 10485760,
      "source": { "type": "build", "build": { "name": "my-super-app-build", "number": "15", "timestamp": "2023-10-27T08:00:00.000Z", "repo_key": "artifactory-build-info" }},
      "artifacts": [
        { "path": "my-super-app-service/1.2.3/manifest.json", "sha256": "a1b2c3d4e5f6...", "size": 5240 },
        { "path": "my-super-app-service/1.2.3/layer1.tar.gz", "sha256": "...", "size": 10480520 }
      ]
    },
    {
      "name": "com.my-org:shared-library",
      "version": "2.5.0",
      "sha256": "f6e5d4c3b2a1...",
      "releasable_type": "package_version",
      "package_type": "maven",
      "owning_application_key": "shared-services-app",
      "connection_level": "2nd_party",
      "total_size": 5242880,
      "source": { "type": "version", "version": { "application_key": "shared-services-app", "version": "2.5.0" }},
      "artifacts": [
        { "path": "com/my-org/shared-library/2.5.0/shared-library-2.5.0.jar", "sha256": "f6e5d4c3b2a1...", "size": 5242880 }
      ]
    },
    {
      "name": "react",
      "version": "18.2.0",
      "sha256": "c3d4e5f6a1b2...",
      "releasable_type": "package_version",
      "package_type": "npm",
      "owning_application_key": null,
      "connection_level": "3rd_party",
      "total_size": 94208,
      "source": { "type": "direct" },
      "artifacts": [
        { "path": "react/-/react-18.2.0.tgz", "sha256": "c3d4e5f6a1b2...", "size": 94208 }
      ]
    }
  ],
  "sources": [
    { "type": "build", "build": { "name": "my-super-app-build", "number": "15", "timestamp": "2023-10-27T08:00:00.000Z", "repo_key": "artifactory-build-info" }},
    { "type": "version", "version": { "application_key": "shared-services-app", "version": "2.5.0" }, "child_sources": [
        { "type": "build", "build": { "name": "shared-services-build", "number": "42" }}
    ]},
    { "type": "direct" }
  ],
  "offset": 0,
  "limit": 25
}





Update Application Version
API

Description
Updates the tag and/or properties of a specific application version. Allows setting or replacing values for specific property keys, clearing values for a key,

Request URL
PATCH https://{{artifactory-host}}/apptrust/api/v1/applications/{{application_key}}/versions/{{version}}

Query Parameter
Parameter Name
Type
Description








Request Body
Parameter Name
Type
Description
tag
string
The new tag to associate with the application version. Max length 128 characters. If an empty string ("") is provided, the existing tag will be removed. If the field is omitted, the tag remains unchanged. The tag must adhere to defined format rules (e.g., alphanumeric start/end, with dashes, underscores, dots). Commonly used to represent the branch.
properties
object
An object where each key is a property name (string) and its value is an array of strings representing the values for that property. Providing a key with an array of strings replaces any existing values for that specific key. Providing a key with an empty array ([]) clears all values for that key, but the key itself remains. Property keys not included in this object are not affected.
delete_properties
array:string
A list of property keys (strings) to completely remove from the application version. These keys and their associated values will be deleted.


Response
On Success 
HTTP Return code: 200
Parameter Name
Type
Description
application_key
string
The unique key of the application.
version
string
The version string of the application version.
tag
string
The updated tag of the application version. Will be null or absent if removed.
properties
object
The updated key-value map of custom properties, where each value is an array of strings. Will be an empty object if all properties were removed or never existed. Keys with cleared values will be present with an empty array [].
modified_by
string
User who performed this update.
modified_at
string
ISO 8601 timestamp of when this update occurred.
status
string
Current status of the application version. 


On Failure
Status Code
Description
400
Bad Request
401
Bad Credentials
403
Permissions Denied
404
Not Found



Parameter Name
Type
Description








Example
Request HTTP Example:

PATCH 'https://{host}.jfrog.io/apptrust/api/v1/applications/my-app/versions/1.2.3'
Content-Type: application/json
Authorization: ••••••

Request Body Example:
{
  "tag": "release/1.2.3",
  "properties": {
    "status": ["rc", "validated"],
    "deployed_to": ["staging-A", "staging-B"],
    "old_feature_flag": []
  },
  "delete_properties": ["legacy_param", "toBeDeleted"] 
}

Response Body Example:
{
  "application_key": "my-app",
  "version": "1.2.3",
  "tag": "release",
  "properties": {
    "status": ["rc", "validated"],
    "tested_on": ["ubuntu20.04"],
    "old_feature_flag": [],
    "deployed_to": ["staging-A", "staging-B"]
  },
  "modified_by": "user@example.com",
  "modified_at": "2025-06-04T10:06:00Z"
}


CLI


Command:
jf apptrust version-update <app-key> <version> --tag "<tag>" --properties "<key>=<value1>[,<value2>,...]"] --delete-property "<key>" 


Short command: jf at vu


Parameters:
<app-key>:  Required - The application key of the application for which the version is being created.
<version>: Required - The version number (in SemVer format) for the new application version.
--tag "<tag>": Optional - A tag associated with the version. A tag is a single free text value, limited to 255 characters, beginning and ending with an alphanumeric character ([a-z0-9A-Z]) with dashes (-), underscores (_), dots (.), and alphanumerics between.
--properties "<key>=<value1>[,<value2>,...]": Optional - Sets or updates a custom property for the application version.
--delete-property "<key>": Optional - Completely removes the specified property key and all its associated values from the application version. 
Description:
Updates the user-defined annotations (tag and custom key-value properties) for a specified application version. This command allows for setting, changing, or removing the version's tag. For properties, it enables adding new properties, updating the values of existing ones (replacing all current values for a given key with new ones), clearing all values for a property while keeping the key, or completely deleting specified property keys. All specified changes are applied in a single update operation. 



Delete Application Version

API

Description
Deletes the specified version of the application.

Request URL
DELETE https://{{artifactory-host}}/apptrust/api/v1/applications/{{application_key}}/versions/{{version}}

Query Parameter
Parameter Name
Type
Description
async
boolean
Default: true
Determines whether the operation should be asynchronous (true) or synchronous (false).


Request Body
Parameter Name
Type
Description








Response
On Success 
HTTP Return code: 204 (synchronous) or 202 (asynchronous)
Parameter Name
Type
Description








On Failure
Status Code
Description
401
Bad Credentials
403
Permissions Denied



Parameter Name
Type
Description








CLI

Command:
jf apptrust version-delete <app-key> <version>


Short command: jf at vd


Parameters:
<app-key>: Required - The application key.
<version>: Required - The version number to be deleted.




Promote Application Version
API

Description
Promotes the specified application version to the desired stage, with options for including/excluding repositories, running conditions, and providing comments.
Note: To move a version to the Release stage, you must use the Release Application Version API.

Request URL
POST https://{{artifactory-host}}/apptrust/api/v1/applications/{{application_key}}/versions/{{version}}/promote

Query Parameter
Parameter Name
Type
Description
async
boolean
Default: false
Determines whether the operation should be asynchronous (true) or synchronous (false).


Request Body
Parameter Name
Type
Description
target_stage
Required
string
The target stage
promotion_type
string
Default: copy
Specifies how promotion affects artifacts.
copy (default) duplicates to the target stage, preserving source artifacts. No physical copy occurs if an artifact's source/target repositories are identical.
move transfers, removing from differing source repositories. 
dry_run validates the operation without actual changes.
included_repository_keys
array: string
Defines specific repositories to include in the promotion.
If this property is left undefined, all repositories (except those specifically excluded) are included in the promotion.
Important: If one or more repositories are specifically included, all other repositories are excluded (regardless of what is defined in excluded_repository_keys).
excluded_repository_keys
array: string
Defines specific repositories to exclude from the promotion.
artifact_additional_properties
array:string
An object containing key-value string pairs that will be added or updated as properties on each promoted artifact. If a property key provided here already exists on an artifact, its original value will be overridden by the new value. If the key is new, the property will be added to the artifact.


Response
On Success 
HTTP Return code: 201 (synchronous) or 200 (asynchronous)
Parameter Name
Type
Description
application_key
string
The unique key of the application.
version
string
The version string of the application version.
source_stage
string
The source environment from which the application version was promoted.
target_stage
string
The target environment to which the application version was promoted.
promotion_type
string
Specifies how promotion affects artifacts.
copy duplicates to the target stage, preserving source artifacts. No physical copy occurs if an artifact's source/target repositories are identical.
move transfers, removing from differing source repositories. 
dry_run validates the operation without actual changes.
status
string
The outcome of the request (e.g., "success").
message
string
A human-readable summary of the outcome.
included_repository_keys
array: string
Defines specific repositories to include in the promotion.
If this property is left undefined, all repositories (except those specifically excluded) are included in the promotion.
Important: If one or more repositories are specifically included, all other repositories are excluded (regardless of what is defined in excluded_repository_keys).
excluded_repository_keys
array: string
Defines specific repositories to exclude from the promotion.
artifact_additional_properties
array:string
An object containing key-value string pairs that will be added or updated as properties on each promoted artifact. If a property key provided here already exists on an artifact, its original value will be overridden by the new value. If the key is new, the property will be added to the artifact.
created
string
Timestamp when the new version was created (ISO 8601 standard).
evaluations
object
Contains the results of policy evaluations for the source and target stage gates.
evaluations.exit_gate
object
The evaluation result for the source stage's exit gate.
evaluations.exit_gate.eval_id
string
The unique ID for the evaluation. null if no applicable policies are defined. 
evaluations.exit_gate.stage
string
The name of the source stage.
evaluations.exit_gate.decision
string
The overall decision for the source stage's exit gate (pass, warn, fail).
evaluations.exit_gate.explanation
string
A human-readable summary of the exit gate evaluation outcome. This field is omitted if the overall decision is pass.
evaluations.exit_gate.violated_policies
object
A list of policies that resulted in a warn or fail decision. This field is omitted if the overall decision is pass.
evaluations.exit_gate.violated_policies.name
string
The name of the violated policy
evaluations.exit_gate.violated_policies.policy_id
string
The unique ID of the violated policy.
evaluations.exit_gate.violated_policies.rule_name
string
The name of the rule within the policy that was violated.
evaluations.exit_gate.violated_policies.rule_category
string
The category of the rule that was violated.
evaluations.exit_gate.violated_policies.decision
string
The decision for this specific policy  ( warn, fail).
evaluations.exit_gate.violated_policies.resources_evaluated
array: string
A list of resource IDs that were evaluated by the policy.
evaluations.exit_gate.violated_policies.resources_evaluated.pass
int
The number of resources that passed the evaluation.
evaluations.exit_gate.violated_policies.resources_evaluated.warn
int
The number of resources that passed with warnings.
evaluations.exit_gate.violated_policies.resources_evaluated.fail
int
The number of resources that failed the evaluation.
evaluations.entry_gate
object
The evaluation result for the source stage's entry gate.
evaluations.entry_gate.eval_id
string
The unique ID for the evaluation. null if no applicable policies are defined. 
evaluations.entry_gate.stage
string
The name of the source stage.
evaluations.entry_gate.decision
string
The overall decision for the source stage's exit gate (pass, warn, fail).
evaluations.entry_gate.explanation
string
A human-readable summary of the exit gate evaluation outcome. This field is omitted if the overall decision is pass.
evaluations.entry_gate.violated_policies
object
A list of policies that resulted in a warn or fail decision. This field is omitted if the overall decision is pass.
evaluations.entry_gate.violated_policies.name
string
The name of the violated policy
evaluations.entry_gate.violated_policies.policy_id
string
The unique ID of the violated policy.
evaluations.entry_gate.violated_policies.rule_name
string
The name of the rule within the policy that was violated.
evaluations.entry_gate.violated_policies.rule_category
string
The category of the rule that was violated.
evaluations.entry_gate.violated_policies.decision
string
The decision for this specific policy  ( warn, fail).
evaluations.entry_gate.violated_policies.resources_evaluated
array: string
A list of resource IDs that were evaluated by the policy.
evaluations.entry_gate.violated_policies.resources_evaluated.pass
int
The number of resources that passed the evaluation.
evaluations.entry_gate.violated_policies.resources_evaluated.warn
int
The number of resources that passed with warnings.
evaluations.entry_gate.violated_policies.resources_evaluated.fail
int
The number of resources that failed the evaluation.


On Failure
Status Code
Error Code
Description
400
Bad Request
The request is malformed. This could be due to a missing required parameter (e.g., stage), an invalid value for promotion_type, promotion to the release stage, or invalid JSON in the request body.
401
Bad Credentials
The request lacks valid authentication credentials. The user needs to provide a valid token or API key.
403
Permissions Denied
The authenticated user does not have the necessary permissions to perform the promotion for the specified application or stage.
404
Not Found
The specified application_key, version, or stage does not exist.



Parameter Name
Type
Description
status
string
The outcome of the request (e.g., "success").
message
string
A message explaining the reason for failure.
details
string
A detailed explanation for technical failure or for the policy evaluation failure.


Example
Request HTTP Example:

POST 'https://{host}.jfrog.io/apptrust/api/v1/applications/my-web-app/versions/1.2.0/promote'
Content-Type: application/json
Authorization: ••••••

Request Body Example:
{
  "target_stage": "QA",
  "promotion_type": "copy",
  "included_repository_keys": [
    "docker-prod-local"
  ],
  "artifact_additional_properties": {
    "release.status": "approved",
    "promoted.by": "jane.doe"
  }
}

Response Body Example (pass):
{
  "application_key": "my-web-app",
  "version": "1.2.0",
  "source_stage": "dev",
  "target_stage": "QA",
  "promotion_type": "copy",
  "status": "success",
  "message": "Copy promotion from 'dev' to 'QA' was successful.",
  "included_repository_keys": [
    "docker-prod-local"
  ],
  "excluded_repository_keys": [],
  "artifact_additional_properties": {
    "release.status": "approved",
    "promoted.by": "jane.doe"
  },
  "created": "2023-10-27T10:00:00Z",
  "evaluations": {
   "exit_gate": {                            # No applicable policies defined on this gate
      "stage": "dev",
      "eval_id": null,
      "decision": "pass",
      "explanation": "No policies to evaluate."
    },
    "entry_gate": {
      "stage": "QA",
      "eval_id": "eval-entry-e5f6g7h8",
      "decision": "pass"
    }
  }
}

Response Body Example (warn):
{
  "application_key": "my-web-app",
  "version": "1.2.0",
  "source_stage": "staging",
  "target_stage": "QA",
  "promotion_type": "copy",
  "status": "success",
  "message": "Copy promotion from 'staging' to 'QA' was successful, but with warnings.",
  "created": "2025-07-28T12:17:46.787Z",
  "evaluations": {
    "exit_gate": {
      "stage": "staging",
      "eval_id": "eval-exit-dbeeff5a",
      "decision": "pass"
    },
    "entry_gate": {
      "stage": "QA",
      "eval_id": "eval-entry-8a9cf92f",
      "decision": "warn",
      "explanation": "Evaluation passed with warnings due to security and quality issues.",
      "violated_policies": [
        {
          "policy_name": "Security Scans",
          "policy_id": "pol-sec-001",
          "rule_name": "Warn on High CVEs",
          "rule_category": "Security",
          "policy_decision": "warn",
          "resources_evaluated": {
            "pass": 5,
            "warn": 2,
            "fail": 0
          }
        }
      ]
    }
  }
}


Response Body Example (fail):
{
  "application_key": "my-web-app",
  "version": "1.2.0",
  "source_stage": "staging",
  "target_stage": "prod",
  "promotion_type": "copy",
  "status": "failure",
  "message": "Copy promotion from 'staging' to 'prod' failed due to policy violations.",
  "created": "2025-07-30T13:00:00.000Z",
  "evaluations": {
    "exit_gate": {
      "stage": "staging",
      "eval_id": "eval-exit-a1b2c3d4",
      "decision": "pass" 
    },
    "entry_gate": {
      "stage": "prod",
      "eval_id": "eval-entry-e5f6g7h8",
      "decision": "fail",
      "explanation": "Promotion blocked due to critical security vulnerabilities.",
      "violated_policies": [
        {
          "policy_name": "Block Critical Vulnerabilities",
          "policy_id": "pol-sec-002",
          "rule_name": "Block on Critical CVEs",
          "rule_category": "Security",
          "policy_decision": "fail",
          "resources_evaluated": {
            "pass": 10,
            "warn": 1,
            "fail": 3
          }
        }
      ]
    }
  }
}

Dry-run Response Body Example:
{
  "application_key": "my-web-app",
  "version": "1.2.0",
  "source_stage": "staging",
  "target_stage": "QA",
  "promotion_type": "dry_run",
  "status": "success",
  "message": "Dry run promotion from 'staging' to 'QA' was successful. No changes were made.",
  "created": "2025-07-30T13:01:00.000Z",
  "evaluations": {
    "exit_gate": {
      "stage": "staging",
      "eval_id": "eval-exit-dbeeff5a",
      "decision": "pass"
    },
    "entry_gate": {
      "stage": "QA",
      "eval_id": "eval-entry-8a9cf92f",
      "decision": "warn",
      "explanation": "Policy evaluation completed with warnings. The resource meets critical requirements but has some quality issues that should be addressed.",
      "violated_policies": [
        {
          "policy_name": "Code Quality Check",
          "policy_id": "policy-quality-003",
          "rule_name": "Code Quality Check Rule",
          "rule_category": "Quality",
          "policy_decision": "warn",
          "resources_evaluated": {
            "pass": 25,
            "warn": 4,
            "fail": 0
          }
        }
      ]
    }
  }
}

Error Response Body Example:
{
  "errors": [
    {
      "status": 404,
      "message": "Target stage 'non-existent-stage' not found."
    }
  ]
}



CLI

Command:
jf apptrust version-promote <app-key> <version> <target-stage> [--sync <true|false>][--promotion-type <copy|move>] [--dry-run <true|false>]

Short command: jf at vp 

Parameters:
<app-key>: Required - The unique key of the application whose version is to be promoted (e.g., APP001).
<version>: Required - The version number of the application to be promoted (e.g., 1.0.0).
<target-stage>: Required - The target stage to which the application version should be promoted (e.g., DEV, QA, PROD).
--sync <true|false>: Optional - Default: true - Set to true to run the promotion synchronously.
If not defined, all repositories (except those excluded) are included.
If defined, all other repositories not listed are excluded.
--promotion-type <copy|move>: Optional - Default: copy - Specifies the promotion type. (Valid values: move / copy) .
--dry-run <true|false>: Optional - Default: false - If set to true, the promotion is simulated, and the version is not promoted.
--exclude-repos: [Optional] List of semicolon-separated(;) repositories to exclude from the promotion.
--include-repos: [Optional] List of semicolon-separated(;) repositories to include in the promotion. If this property is left undefined, all repositories (except those specifically excluded) are included in the promotion. If one or more repositories are specifically included, all other repositories are excluded.


Output:
The command provides a status update on the promotion process, indicating whether the promotion was successful, any errors encountered, and details about the operation.

Error Response :
{
   "message": "Failed to promote version.",
   "error": "<error-message>"
}
Success Response :

{
    "message": "Version promotion initiated successfully.",
    "details": {
        "app-key": "<app-key>",
        "version": "<version>",
        "target-stage": "<target-stage>",
        "synchronous": "<sync>",
        "excluded-repositories": ["<repo1>", "<repo2>"],
        "included-repositories": ["<repo3>", "<repo4>"],
        "comment": "<promotion-comment>",
        "promotion-type": "<copy>",
        "dry-run": "<dry-run>",
        "fail-fast": "<fail-fast>",
        "status": "<status>"
    }
}

Error Response :
{
   "message": "Failed to promote version.",
   "error": "<error-message>"
}

Examples:
Basic Promotion Command :
jfrog app version-promote APP001 1.0.0 PROD

Promotion with Optional Flags :
jfrog app version-promote APP001 1.0.0 DEV --sync true --exclude-repos "repoA;repoB" --include-repos "repoC" --promotion-type copy 

Dry Run Example :
jfrog app version-promote APP001 1.0.0 QA --dry-run true

Validation Criteria :
Ensure that the specified application version exists and is in a promotable state.
Validations should be performed against the provided parameters and flags to check for conflicts or invalid values.
Error messages should provide clear feedback when there's an issue with the promotion process.


Release Application Version
API

Description
Release the specified application version (move the version to the release category stage).

Request URL
POST https://{{artifactory-host}}/apptrust/api/v1/applications/{{application_key}}/versions/{{version}}/release

Query Parameter
Parameter Name
Type
Description
async
boolean
Default: false
Determines whether the operation should be asynchronous (true) or synchronous (false).


Request Body
Parameter Name
Type
Description
promotion_type
string
Default: copy
Specifies how promotion affects artifacts.
copy (default) duplicates to the target stage, preserving source artifacts. No physical copy occurs if an artifact's source/target repositories are identical.
move transfers, removing from differing source repositories. 
dry_run validates the operation without actual changes.
included_repository_keys
array: string
Defines specific repositories to include in the promotion.
If this property is left undefined, all repositories (except those specifically excluded) are included in the promotion.
Important: If one or more repositories are specifically included, all other repositories are excluded (regardless of what is defined in excluded_repository_keys).
excluded_repository_keys
array: string
Defines specific repositories to exclude from the promotion.
artifact_additional_properties
array:string
An object containing key-value string pairs that will be added or updated as properties on each promoted artifact. If a property key provided here already exists on an artifact, its original value will be overridden by the new value. If the key is new, the property will be added to the artifact.


Response
On Success 
HTTP Return code: 200 (synchronous) or 202 (asynchronous)
Parameter Name
Type
Description
application_key
string
The unique key of the application.
version
string
The version string of the application version.
source_stage
string
The source environment from which the application version was promoted.
status


The outcome of the release  (e.g., "success").
message


A human-readable summary of the outcome.
included_repository_keys
array: string
Defines specific repositories to include in the promotion.
If this property is left undefined, all repositories (except those specifically excluded) are included in the promotion.
Important: If one or more repositories are specifically included, all other repositories are excluded (regardless of what is defined in excluded_repository_keys).
excluded_repository_keys
array: string
Defines specific repositories to exclude from the promotion.
artifact_additional_properties
array:string
An object containing key-value string pairs that will be added or updated as properties on each promoted artifact. If a property key provided here already exists on an artifact, its original value will be overridden by the new value. If the key is new, the property will be added to the artifact.
created
string
Timestamp when the new version was created (ISO 8601 standard).
evaluations
array:object
Contains the results of policy evaluations for the source and target stage gates.
evaluations.exit_gate
object
The evaluation result for the source stage's exit gate.
evaluations.exit_gate.eval_id
string
The unique ID for the evaluation. null if no applicable policies are defined. 
evaluations.exit_gate.stage
string
The name of the source stage.
evaluations.exit_gate.decision
string
The overall decision for the source stage's exit gate (pass, warn, fail).
evaluations.exit_gate.explanation
string
A human-readable summary of the exit gate evaluation outcome. This field is omitted if the overall decision is pass.
evaluations.exit_gate.violated_policies
object
A list of policies that resulted in a warn or fail decision. This field is omitted if the overall decision is pass.
evaluations.exit_gate.violated_policies.name
string
The name of the violated policy
evaluations.exit_gate.violated_policies.policy_id
string
The unique ID of the violated policy.
evaluations.exit_gate.violated_policies.rule_name
string
The name of the rule within the policy that was violated.
evaluations.exit_gate.violated_policies.rule_category
string
The category of the rule that was violated.
evaluations.exit_gate.violated_policies.decision
string
The decision for this specific policy  ( warn, fail).
evaluations.exit_gate.violated_policies.resources_evaluated
array: string
A list of resource IDs that were evaluated by the policy.
evaluations.exit_gate.violated_policies.resources_evaluated.pass
int
The number of resources that passed the evaluation.
evaluations.exit_gate.violated_policies.resources_evaluated.warn
int
The number of resources that passed with warnings.
evaluations.exit_gate.violated_policies.resources_evaluated.fail
int
The number of resources that failed the evaluation.
evaluations.release_gate
object
The evaluation result for the release_gate on PROD.
evaluations.release_gate.eval_id
string
The unique ID for the evaluation. null if no applicable policies are defined. 
evaluations.release_gate.stage
string
Set to ‘PROD’ stage.
evaluations.release_gate.decision
string
The status of the evaluation (passed, warn, failed).
evaluations.release_gate.explanation
string
A human-readable summary of the release gate evaluation outcome. This field is omitted if the overall decision is pass.
evaluations.release_gate.violated_policies
object
A list of policies that resulted in a warn or fail decision. This field is omitted if the overall decision is pass.
evaluations.release_gate.violated_policies.name
string
The name of the violated policy
evaluations.release_gate.violated_policies.policy_id
string
The unique ID of the violated policy.
evaluations.release_gate.violated_policies.rule_name
string
The name of the rule within the policy that was violated.
evaluations.release_gate.violated_policies.rule_category
string
The category of the rule that was violated.
evaluations.exit_gate.violated_policies.decision
string
The decision for this specific policy  ( warn, fail).
evaluations.exit_gate.violated_policies.resources_evaluated
array: string
A list of resource IDs that were evaluated by the policy.
evaluations.release_gate.violated_policies.resources_evaluated.pass
int
The number of resources that passed the evaluation.
evaluations.release_gate.violated_policies.resources_evaluated.warn
int
The number of resources that passed with warnings.
evaluations.release_gate.violated_policies.resources_evaluated.fail
int
The number of resources that failed the evaluation.


On Failure
Status Code
Description


400
Bad Request
The request is malformed. This could be due to an invalid value for promotion_type, using the release stage as the source_stage, or invalid JSON in the request body.
401
Bad Credentials
The request lacks valid authentication credentials. The user needs to provide a valid token or API key.
403
Permissions Denied
The authenticated user does not have the necessary permissions to perform the promotion for the specified application or stage.
404
Not Found
The specified application_key, version, or stage does not exist.



Parameter Name
Type
Description
message
string
A message explaining the reason for failure.
details
string
A detailed explanation for technical failure or for the policy evaluation failure.


Example
Request HTTP Example:

POST 'https://{host}.jfrog.io/apptrust/api/v1/applications/my-web-app/versions/1.2.0/release
Content-Type: application/json
Authorization: ••••••

Request Body Example:
{
  "promotion_type": "copy",
  "included_repository_keys": [
    "docker-prod-local"
  ],
  "artifact_additional_properties": {
    "release.status": "approved",
    "promoted.by": "jane.doe"
  }
}

Response Body Example (pass):
{
  "application_key": "my-web-app",
  "version": "1.2.0",
  "source_stage": "staging",
  "promotion_type": "copy",
  "status": "success",
  "message": "Releasing version using Copy from 'staging' was successful.",
  "included_repository_keys": [
    "docker-prod-local"
  ],
  "excluded_repository_keys": [],
  "artifact_additional_properties": {
    "release.status": "approved",
    "promoted.by": "jane.doe"
  },
  "created": "2023-10-27T10:00:00Z",
  "evaluations": {
   "exit_gate": {                             # No applicable policies defined on this gate
      "stage": "staging",
      "eval_id": null,
      "decision": "pass",
      "explanation": "No policies to evaluate."
    },
    "release_gate": {
      "eval_id": "eval_tgt_1698399605",
      "stage": "PROD",
      "decision": "pass"
    }
  }
}

Response Body Example (fail):
{
  "application_key": "my-web-app",
  "version": "1.2.0",
  "source_stage": "staging",
  "promotion_type": "copy",
  "status": "failure",
  "message": "Releasing version using Copy from 'staging' failed due to policy violations.",
  "created": "2025-07-30T13:00:00.000Z",
  "evaluations": {
    "exit_gate": {
      "stage": "staging",
      "eval_id": "eval-exit-a1b2c3d4",
      "decision": "pass"
    },
    "release_gate": {
      "stage": "PROD",
      "eval_id": "eval-release-e5f6g7h8",
      "decision": "fail",
      "explanation": "Release blocked due to critical security vulnerabilities.",
      "violated_policies": [
        {
          "policy_name": "Block Critical Vulnerabilities",
          "policy_id": "pol-sec-002",
          "rule_name": "Block on Critical CVEs",
          "rule_category": "Security",
          "policy_decision": "fail",
          "resources_evaluated": {
            "pass": 10,
            "warn": 1,
            "fail": 3
          }
        }
      ]
    }
  }
}


Error Response Body Example:
{
  "errors": [
    {
      "status": 404,
      "message": "Source stage 'non-existent-stage' not found."
    }
  ]
}



CLI

Command:
jfrog app version-release <app-key> <version> [--sync <true|false>] [--promotion-type <copy|move>] [--dry-run <true|false>]

Short command: jf at vr

Parameters:
<app-key>: Required - The unique key of the application whose version is to be promoted (e.g., APP001).
--sync <true|false>: Optional - Default: true - Set to true to run the promotion synchronously.
--promotion-type <copy|move>: Optional - Default: false - If set to true, the build artifacts and dependencies are copied to the target repository; otherwise, they are moved.
--dry-run <true|false>: Optional - Default: false - If set to true, the promotion is simulated, and the version is not promoted.
--exclude-repos: [Optional] List of semicolon-separated(;) repositories to exclude from the promotion.
--include-repos: [Optional] List of semicolon-separated(;) repositories to include in the promotion. If this property is left undefined, all repositories (except those specifically excluded) are included in the promotion. If one or more repositories are specifically included, all other repositories are excluded.


Roll Back Application Version Promotion
API

Description
Rolls back the latest promotion of the specified application version to its previous stage. This action removes the promotion record, but the audit log will retain a history of the rollback. The behavior of the artifact rollback depends on the original promotion type:
Copy Promotion: Artifacts in the target stage's repositories are deleted.
Move Promotion: Artifacts are removed from the current stage's repositories and restored to the previous stage's repositories from a secure internal repository.
Request URL
POST https://{{artifactory-host}}/apptrust/api/v1/applications/{{application_key}}/versions/{{version}}/rollback

Query Parameter
Parameter Name
Type
Description
async
boolean
Default: false
Determines whether the operation should be asynchronous (true) or synchronous (false).


Request Body
Parameter Name
Type
Description
from_stage
string
The name of the stage from which to roll back the application version.


Response
On Success 
HTTP Return code: 200 or 202
Parameter Name
Type
Description
application_key	
string
The unique key of the application.
version
string
The version of the application that was rolled back.
project_key
string
The project key associated with the application.
rollback_from_stage
string
The stage from which the application version was rolled back.
rollback_to_stage
string
The stage to which the application version was reverted.


On Failure
Status Code
Description


400
Bad Request
The request is malformed. This could be due to an invalid value for promotion_type, using the release stage as the source_stage, or invalid JSON in the request body.
401
Bad Credentials
The request lacks valid authentication credentials. The user needs to provide a valid token or API key.
403
Permissions Denied
The authenticated user does not have the necessary permissions to perform the promotion for the specified application or stage.
404
Not Found
The specified application_key, version, or stage does not exist.



Parameter Name
Type
Description








Example
Request HTTP Example:

POST 'https://{host}.jfrog.io/apptrust/api/v1/applications/video-encoder/versions/1.5.0/rollback
Content-Type: application/json
Authorization: ••••••

Request Body Example:
{
  "from_stage": "qa"
}

Response Body Example:
{
  "application_key": "video-encoder",
  "version": "1.5.0",
  "project_key": "MEDIA-PROJ",
  "rollback_from_stage": "qa",
  "rollback_to_stage": "dev"
}
CLI

Command:
jfrog app version-rollback <app-key> <version> <from-stage>

Short command: jf at vrb

Parameters:
<app-key>:	 	Required. The unique key of the application.
<version>:		Required. The version of the application to roll back.
<from-stage>:	Required. The name of the stage from which to roll back the application version.


Get Application Version Promotions
API

Description
Returns the details of all promotions for the specified Application version. 

Request URL
GET https://{{artifactory-host}}/apptrust/api/v1/applications/{{application_key}}/versions/{{version}}/promotions

Query Parameter
Parameter Name
Type
Description
include 
string
Permitted value:
message: Returns any error messages generated when creating the promotion.
offset
integer
Sets the number of records to skip before returning the query response. Used for pagination purposes.
limit
integer
Sets the maximum number of versions to return at one time. Used for pagination purposes.
filter_by
string
Defines a filter for the list of promotions.
You can filter according to:
application_version (for example, filter_by=1.0.0)
target_stage (for example, filter_by=QA)
promoted_by (for example, filter_by=user1)
status (e.g., "success", "pending", "failed").
order_by
string
Default: created
Defines the criterion by which to order the list of promotions: created (standard timestamp or milliseconds),  created_by, version , stage
order_asc
boolean
Default: false
Defines whether to list the application in ascending (true) or descending (false) order.


Request Body
Parameter Name
Type
Description








Response
On Success 
HTTP Return code: 200
Parameter Name
Type
Description
application_key
String
The unique key of the application.


application_version
String
The version number of the application being promoted.
project_key
String
The project key associated with the application.
status
String
Status of the promotion: STARTED, FAILED, COMPLETED, DELETING
source_stage
String
The name of the stage from which the application version was promoted.
target_stage
String
The name of the target stage for the promotion.
promoted_by
String
Name of the user who initiated the promotion.
promoted_at
String
Timestamp when the promotion was created (ISO 8601 standard).
promoted_millis
Int
Timestamp when the promotion was created in milliseconds.
evaluations
object
Contains the results of policy evaluations for the source and target stage gates.
evaluations.exit_gate
object
The evaluation result for the source stage's exit gate.
evaluations.exit_gate.eval_id
string
The unique ID for the evaluation.
evaluations.exit_gate.stage
string
The name of the source stage.
evaluations.exit_gate.decision
string
The overall decision for the source stage's exit gate (pass, warn, fail).
evaluations.exit_gate.explanation
string
A human-readable summary of the exit gate evaluation outcome. This field is omitted if the overall decision is pass.
evaluations.entry_gate
object
The evaluation result for the target stage's entry gate.
evaluations.entry_gate.eval_id
string
The unique ID for the evaluation.
evaluations.entry_gate.stage
string
The name of the target stage.
evaluations.entry_gate.decision
string
The overall decision for the source stage's exit gate (pass, warn, fail).
evaluations.entry_gate.explanation
string
A human-readable summary of the exit gate evaluation outcome. This field is omitted if the overall decision is pass.
total
int
The total number of releasable records returned.
limit
int
The offset value used for this request.
offset
int
The limit value used for this request.


On Failure
Status Code
Description
401
Bad Credentials
403
Permissions Denied



Parameter Name
Type
Description








Example
Request HTTP Example:

GET 'https://{host}.jfrog.io/apptrust/api/v1/applications/catalina-app/versions/1.0.0/promotions?limit=2'
Content-Type: application/json
Authorization: ••••••

Request Body Example:
{
}

Response Body Example:
{
    "promotions": [
        {
            "status": "FAILED",
            "project_key": "catalina",
            "application_key": "my-app",
            "application_version": "1.0.0",
            "source_stage": "QA",
            "target_stage": "PROD",
            "promoted_by": "admin",
            "promoted": "2023-05-19T06:47:56.518Z",
            "created_millis": 1684478876518,
            "evaluations": {
              "exit_gate": {
          "stage": "QA",
          "eval_id": "eval-exit-b4c3d2a1",
          "decision": "pass"
       	 },
        "entry_gate": {
          "stage": "PROD",
          "eval_id": "eval-entry-h8g7f6e5",
          "decision": "fail",
          "explanation": "Promotion blocked due to critical security vulnerabilities."
        }
     	     }
        },
        {
            "status": "COMPLETED",
            "project_key": "catalina",
            "application_key": "my-app",
            "application_version": "1.0.0",
            "source_stage": "DEV",
            "target_stage": "QA",
            "created_by": "admin",
            "created": "2023-05-19T06:21:44.916Z",
            "created_millis": 1684477304916,
      "evaluations": {
        "exit_gate": {
          "stage": "DEV",
          "eval_id": "eval-exit-a1b2c3d4",
          "decision": "pass"
        },
        "entry_gate": {
          "stage": "QA",
          "eval_id": "eval-entry-e5f6g7h8",
          "decision": "pass"
        }
      }
    ],
    "total": 2,
    "limit": 1000,
    "offset": 0
}



Stages Operations

Create Stage
API

Description
Creates a new global or project-level stage.

Request URL
POST https://{{artifactory-host}}/access/api/v2/stages/

Query Parameter
Parameter Name
Type
Description








Request Body
Parameter Name
Type
Description
name
Required
string
The unique name of the stage (e.g., "dev", "qa", "prod"). Must be unique within its scope.
project_key
string
The project key. Required if scope is 'project'. Omitted for 'global' scope.
category
String
Default: promote
The functional category of the stage. Can be none,  code or promote.
repositories
array: string
A list of repository keys assigned to this stage. This field is only applicable and allowed when the category is promote.


Response
On Success 
HTTP Return code: 201
Parameter Name
Type
Description
name
string
The unique name of the stage (e.g., "dev", "qa", "prod"). Must be unique within its scope.
scope
string
The level at which the stage exists. Can be 'global' or 'project'.
project_key
string
The project key. Omitted for 'global' scope.
category
string
The functional category of the stage. Can be 'none'or 'Promote'.
repositories
array: string
A list of repository keys assigned to this stage.
used_in_lifecycle
array: string
List of project keys where the stage is being used in its lifecycle
created_by
string
The user who created the stage.
created
string
The timestamp (ISO 8601) when the stage was created.


On Failure
Status Code
Description
400
Bad Request
401
Bad Credentials
403
Permissions Denied
409
Conflict



Parameter Name
Type
Description
message
string




Example
Request HTTP Example:

POST 'https://{host}.jfrog.io/access/api/v2/stages/
Content-Type: application/json
Authorization: ••••••

Request Body Example:
{
  "name": "production-us-east",
  "scope": "project",
  "project_key": "mobile-app",
  "category": "promote",
  "repositories": ["docker-prod-us-east-local", "generic-prod-us-east-local"]
}

Response Body Example:
{
  "name": "production-us-east",
  "scope": "project",
  "project_key": "mobile-app",
  "category": "promote",
  "repositories": [
    "docker-prod-us-east-local",
    "generic-prod-us-east-local"
  ],
  "used_in_lifecycle": [],
  "created_by": "pm_user",
  "created_at": "2025-05-28T17:51:25Z",
  "modified_at": "2025-05-28T17:59:25Z"
}


Get Stage Details
API

Description
Retrieves the details of a specific stage by its name.

Request URL
GET https://{{artifactory-host}}/access/api/v2/stages/{{stage-name}}

Query Parameter
Parameter Name
Type
Description
project_key
string
Filters the list for a specific project. 


Request Body
Parameter Name
Type
Description








Response
On Success 
HTTP Return code: 200
Parameter Name
Type
Description
name
string
The unique name of the stage (e.g., "dev", "qa", "prod"). Must be unique within its scope.
scope
string
The level at which the stage exists. Can be 'global' or 'project'.
project_key
string
The project key. Omitted for 'global' scope.
category
string
The functional category of the stage.
repositories
array: string
A list of repository keys assigned to this stage.
used_in_lifecycles
array: string
List of project keys where the stage is being used in its lifecycle
created_by
string
The user who created the stage.
created
string
The timestamp (ISO 8601) when the stage was created.
modified
string
The timestamp (ISO 8601) when the stage was last modified.


On Failure
Status Code
Description
401
Bad Credentials
403
Permissions Denied
404
Not Found



Parameter Name
Type
Description
message
string
Error message


Example
Request HTTP Example:

GET 'https://{host}.jfrog.io/access/api/v2/stages/production-us-east?project_key=mobile-app'
Authorization: ••••••

Request Body Example:
{
}

Response Body Example:
{
  "name": "production-us-east",
  "scope": "project",
  "project_key": "mobile-app",
  "category": "promote",
  "repositories": [
    "docker-prod-us-east-local",
    "generic-prod-us-east-local"
  ],
  "used_in_lifecycle": ["mobile-app"],
  "created_by": "pm_user",
  "created_at": "2025-05-28T17:51:25Z",
  "modified_at": "2025-05-28T17:59:25Z"
}


Get Stages
API

Description
Retrieves a list of all stages, with optional filtering.
Without a project_key the endpoint is available only to platform admins. In that case the API will return all the global stages.
With a specific project_key the endpoint is available also to project admins (for the given project key). In this case the API returns both global and project stages but the “usage” (repositories and used_in_lifecycles) will be scoped to only the given project key.

Request URL
GET https://{{artifactory-host}}/access/api/v2/stages/

Query Parameter
Parameter Name
Type
Description
project_key
string
Filters the list for a specific project. Only valid when scope is 'project'.
scope
string
Filters the list by 'global' or 'project'.
category
string
Filters the list by code or promote.


Request Body
Parameter Name
Type
Description








Response
On Success 
HTTP Return code: 200
Parameter Name
Type
Description
name
string
The unique name of the stage (e.g., "dev", "qa", "prod"). Must be unique within its scope.
scope
string
The level at which the stage exists. Can be 'global' or 'project'.
project_key
string
The project key. Omitted for 'global' scope.
category
string
The functional category of the stage.
repositories
array: string
A list of repository keys assigned to this stage.
used_in_lifecycle
array: string
List of project keys where the stage is being used in its lifecycle
created_by
string
The user who created the stage.
created
string
The timestamp (ISO 8601) when the stage was created.
modified
string
The timestamp (ISO 8601) when the stage was last modified.


On Failure
Status Code
Description
401
Bad Credentials
403
Permissions Denied



Parameter Name
Type
Description
message
string
Error message


Example
Request HTTP Example:

GET 'https://{host}.jfrog.io/access/api/v2/stages/production-us-east?project_key=mobile-app'
Authorization: ••••••

Request Body Example:
{
}

Response Body Example:
[
  {
    "name": "staging-us-east",
    "scope": "project",
    "project_key": "mobile-app",
    "category": "promote",
    "repositories": ["docker-staging-us-east-local"],
    "used_in_lifecycle": ["mobile-app"],
    "created_by": "admin",
    "created_at": "2025-05-27T11:00:00Z",
    "modified_at": "2025-05-27T11:00:00Z"
  },
  {
    "name": "PROD",
    "scope": "global",
    "project_key": "mobile-app",
    "category": "promote",
    "repositories": ["docker-staging-us-east-local"],
    "used_in_lifecycle": ["mobile-app"],
    "created_by": "system",
    "created_at": "2023-05-27T11:00:00Z",
    "modified_at": "2023-05-27T11:00:00Z"
  },
  {
    "name": "qa-us-east",
    "scope": "project",
    "project_key": "mobile-app",
    "category": "promote",
    "repositories": [
      "docker-prod-us-east-local",
      "generic-prod-us-east-local"
    ],
    "used_in_lifecycle": ["mobile-app"],
    "created_by": "pm_user",
    "created_at": "2025-05-28T17:51:25Z",
    "modified_at": "2025-05-28T17:51:25Z"
  }
]


Update Stage
API

Description
Updates the details of the specified stage with new data. All fields in the body are optional and only the existing fields will be replaced.

Request URL
PATCH https://{{artifactory-host}}/access/api/v2/stages/{{stage-name}}

Query Parameter
Parameter Name
Type
Description
project_key
string
The project containing the specific stage.


Request Body
Parameter Name
Type
Description
name
string
The unique name of the stage (e.g., "dev", "qa", "prod"). Must be unique within its scope.
category
string
The functional category of the stage.Can only be modified to code or promote if the stage is not in use.
repositories
array: string
A list of repository keys assigned to this stage. 


Response
On Success 
HTTP Return code: 200
Parameter Name
Type
Description








On Failure
Status Code
Description
400
Bad Request
401
Bad Credentials
403
Permissions Denied
404
Not Found



Parameter Name
Type
Description
message
string
Error message


Example
Request HTTP Example:

PATCH 'https://{host}.jfrog.io/stages/api/v1/stages/production-us-east?project_key=mobile-app'
Content-Type: application/json
Authorization: ••••••

Request Body Example:
{
  "name": "qa-us-east",
  "category": "promote",
  "repositories": [
    "docker-prod-us-east-local",
    "generic-prod-us-east-local",
    "helm-prod-us-east-local"
  ]
}

Response Body Example:
{
  "name": "qa-us-east",
  "scope": "project",
  "project_key": "mobile-app",
  "category": "promote",
  "repositories": [
    "docker-prod-us-east-local",
    "generic-prod-us-east-local",
    "helm-prod-us-east-local"
  ],
  "used_in_lifecycle": ["mobile-app"],
  "created_by": "pm_user",
  "created_at": "2025-05-28T17:51:25Z",
  "modified_at": "2025-05-28T17:51:27Z"
}


Delete Stage
API

Description
Deletes a stage.

Request URL
DELETE https://{{artifactory-host}}/access/api/v2/stages/{{stage-name}}

Query Parameter
Parameter Name
Type
Description
project_key
string
Filters the list for a specific project


Request Body
Parameter Name
Type
Description








Response
On Success 
HTTP Return code: 204
Parameter Name
Type
Description








On Failure
Status Code
Description
401
Bad Credentials
403
Permissions Denied
404
Not Found
409
Conflict



Parameter Name
Type
Description
message
string
Error message



Example
Request HTTP Example:

DELETE 'https://{host}.jfrog.io/stages/api/v1/stages/production-us-east?project_key=mobile-app'
Authorization: ••••••

Request Body Example:
{
}

Response Body Example:
{
  "errors": [
    {
      "message": "Stage 'production-us-east' is in use and cannot be deleted."
    }
  ]
}


Get Lifecycle
API

Description
Retrieves the current lifecycle definition for a specific project.

Request URL
GET https://{{artifactory-host}}/access/api/v2/lifecycle/

Query Parameter
Parameter Name
Type
Description
project_key
string
Filters the list for a specific project


Request Body
Parameter Name
Type
Description








Response
On Success 
HTTP Return code: 202
Parameter Name
Type
Description
releaseStage
string
Name of the release stage
lifecycle
array: array(section)
Ordered list of Lifecycle section object (one for each category)
lifecycle.category
string
The name of the category. Either code or promote.
lifecycle.category.stages
array(stage)
An ordered list of Stage Objects that belong to this category.
lifecycle.category.stages.name
string
The name of the stage (e.g., "dev", "qa", "prod"). 
lifecycle.category.stages.scope
string
The level at which the stage exists. Can be 'global' or 'project'.


On Failure
Status Code
Description
401
Bad Credentials
403
Permissions Denied



Parameter Name
Type
Description
message
string
Error message


Example
Request HTTP Example:

GET 'https://{host}.jfrog.io/access/api/v2/stages/lifecycle'
Authorization: ••••••

Request Body Example:
{
}

Response Body Example:
{
  "releaseStage": "PROD",
  "categories": [
    {
      "category": "code",
      "stages": [
        { "name": "PR", "scope": "global" },
        { "name": "COMMIT", "scope": "global" }
      ]
    }, 
    {
      "category": "promote",
      "stages": [
        { "name": "qa-testing", "scope": "project" },
        { "name": "PROD", "scope": "global" }
      ]
    }
  ]
}




Update Lifecycle
API

Description
Modifies the stages of a project's lifecycle. This operation allows adding, removing, or reordering stages. The fixed, global stages (PR, COMMIT, PROD) cannot be altered and should not be included in the request.

Request URL
PATCH https://{{artifactory-host}}/access/api/v2/lifecycle/

Query Parameter
Parameter Name
Type
Description
project_key
string
Filters the list for a specific project


Request Body
Parameter Name
Type
Description
promote_stages
array: array(string)
The new, ordered list of stage names


Response
On Success 
HTTP Return code: 202
Parameter Name
Type
Description
category
array: array(stages)
An ordered list of all categories, each category will have an ordered list of stages. 
category.stages
array: objects
An ordered list of stages. Each stage has a name, scope, and an indication if it’s a fixed stage.
categories.stages.name
string
The unique name of the stage (e.g., "dev", "qa"). Must be unique within its scope.
categories.stages.scope
string
The level at which the stage exists. Can be 'global' or 'project'.


On Failure
Status Code
Description
400
Bad Request
401
Bad Credentials
403
Permissions Denied
404
Not Found
422
Unprocessable Entity



Parameter Name
Type
Description
message
string
Error message


Example
Request HTTP Example:

PATCH 'https://{host}.jfrog.io/access/api/v2/lifecycle'
Content-Type: application/json
Authorization: ••••••

Request Body Example:
{
  "promote_stages": [
    "qa-testing",
    "staging-deploy"
  ]
}

Response Body Example:
[
  {
    "category": "code",
    "stages": [
      { "name": "PR", "scope": "global" },
      { "name": "COMMIT", "scope": "global" }
    ]
  },
  {
    "category": "promote",
    "stages": [
      { "name": "qa-testing", "scope": "project" },
      { "name": "staging-deploy", "scope": "project" },
      { "name": "PROD", "scope": "global" }
    ]
  }
]



Packages Operations 
Get Application Package Bindings
API

Description
Retrieves a paginated list of unique packages bound with the specified application, along with summary details.

Request URL
GET https://{{artifactory-host}}/apptrust/api/v1/applications/{{application_key}}/package_bindingspackages

Query Parameter
Parameter Name
Type
Description
name
string
Filters the list by a specific package type (e.g., "maven", "npm", "docker", "generic").
type
string
The 0-indexed starting position of the first item to return for pagination.
offset
int
The starting position of the first item to return for pagination.
limit
int
The maximum number of items per page for pagination.
order_by
string
Default: package_name
Field to sort the results by. Supported values: package_name, package_type.
order_asc
boolean
Default: false
Defines whether to list the application in ascending (true) or descending (false) order.


Request Body
Parameter Name
Type
Description








Response
On Success 
HTTP Return code: 200
Parameter Name
Type
Description
packages
array:object
An array of Package Summary Objects.
packages.name
string
The name of the package (e.g., "my-shared-library").
packages.type
string
The type of the package (e.g., "maven", "npm", "docker", "generic").
packages.num_versions
int
The total count of distinct versions of this package that are owned by the current application.
packages.latest_version
string
The version string of the most recent version of this package that is owned by the current application.


On Failure
Status Code
Description
400
Bad Request
401
Bad Credentials
403
Permissions Denied
404
Not Found



Parameter Name
Type
Description








Example
Request HTTP Example:

GET 'https://{host}.jfrog.io/access/api/v1/applications/web-portal-app/packages?type=npm&offset=0&limit=10&order_by=package_name&order_asc=true HTTP/1.1
Content-Type: application/json
Authorization: ••••••

Request Body Example:
{

}

Response Body Example:
{
  "packages": [
    // Assuming 'portal-ui-components' comes after 'portal-auth-client' alphabetically
    {
      "name": "portal-ui-components",
      "type": "npm",
      "latest_version": "2.5.1",
      "num_versions": 5
    },
    {
      "name": "portal-auth-client",
      "type": "npm",
      "latest_version": "1.3.0",
      "num_versions": 3
    }
  ],
  "pagination": {
    "offset": 0,
    "limit": 10,
    "total_items": 2
  }
}


Get Bound Package Versions
API

Description
Retrieves a paginated list of all versions for a specific package that are bound to the specified application, including available source control details for each version.

Request URL
GET https://{{artifactory-host}}/apptrust/api/v1/applications/{{application_key}}/package_versions

Query Parameter
Parameter Name
Type
Description
offset
int
Default: 0. The number of records to skip for pagination.
limit
int
Default: 25. The maximum number of records to return. The maximum number is 250.
package_type
string
The type of the package (e.g., "maven", "npm", "docker", "generic").
package_name
string
The name of the package.
package_version
string
The version of the package. If not specified, the package will return all versions bound to this application.


Request Body
Parameter Name
Type
Description








Response
On Success 
HTTP Return code: 200
Parameter Name
Type
Description
versions
array:object
An array of Package Version objects.
versions.version
string
The version string of the package.
versions.vcs_url
string
The source control URL associated with the package version. Only present if available from build information.
versions.vcs_branch
string
The source control branch from which the package version was built. Only present if available.
versions.vcs_revision
string
The source control revision (e.g., commit hash) of the package version. Only present if available.
total
int
The total number of bound versions for this package.
offset
int
The offset value used for this request.
limit
int
The limit value used for this request.


On Failure
Status Code
Description
401
Bad Credentials
403
Permissions Denied
404
Not Found



Parameter Name
Type
Description








Example
Request HTTP Example:

GET 'https://{host}.jfrog.io/apptrust/api/v1/applications/web-portal-app/packages/npm/portal-ui-components/versions?limit=2&order_by=version&order_asc=false'
Authorization: ••••••

Request Body Example:
{

}

Response Body Example:
{
  "versions": [
    {
      "version": "2.5.1",
      "vcs_url": "https://github.com/my-org/web-portal.git",
      "vcs_branch": "main",
      "vcs_revision": "a1b2c3d4e5f67890"
    },
    {
      "version": "2.5.0",
      "vcs_url": "https://github.com/my-org/web-portal.git",
      "vcs_branch": "feature/new-ui",
      "vcs_revision": "f6e5d4c3b2a10987"
    }
  ],
  "offset": 0,
  "limit": 2,
  "total": 5
}


Bind Package Version
API

Description
Bind a specific, unbound package version with the given application.

Request URL
POST https://{{artifactory-host}}/apptrust/api/v1/applications/{{application_key}}/packages

Query Parameter
Parameter Name
Type
Description








Request Body
Parameter Name
Type
Description
package_type
Required
string
The type of the package (e.g., "maven", "npm", "docker", "generic").
package_name
Required
string
The name of the package.
package_version
string
The version of the package. If not specified, the package will be bound to this application by default.


Response
On Success 
HTTP Return code: 201
Parameter Name
Type
Description
application_key
string
The application key to which the package version is now associated.
package_type
string
The type of the package (e.g., "maven", "npm", "docker", "generic").
package_name
string
The name of the package.
package_version
string
Optional. The version of the package. 
bound_at
string
ISO 8601 timestamp indicating when the association was made.
bound_by
string
The user or system principal that performed the association.


On Failure
Status Code
Description
400
Bad Request
401
Bad Credentials
403
Permissions Denied
404
Not Found
409
Conflict



Parameter Name
Type
Description








Example
Request HTTP Example:

POST 'https://{host}.jfrog.io/apptrust/api/v1/applications/my-web-app/package-versions'
Content-Type: application/json
Authorization: ••••••

Request Body Example:
{
  "package_type": "maven",
  "package_name": "com.example:common-utils",
  "package_version": "1.2.3"
}

Response Body Example:
{
  "application_key": "my-web-app",
  "package_type": "maven",
  "package_name": "com.example:common-utils",
  "package_version": "1.2.3",
  "bound_at": "2025-06-04T20:30:00Z",
  "bound_by": "user@example.com"
}


Unbind Package Version
API

Description
Disassociates or "unbinds" a specific package version from the given application. This action removes the ownership link, making the package version considered as not belonging to the application.

Request URL
DELETE https://{{artifactory-host}}/apptrust/api/v1/applications/{{application_key}}/packages
Query Parameter
Parameter Name
Type
Description








Request Body
Parameter Name
Type
Description
package_type
Required
string
The type of the package (e.g., "maven", "npm", "docker", "generic").
package_name
Required
string
The name of the package.
package_version
string
The version of the package. If not specified, all versions bound to this application will be unbound. Versions bound to other applications will not be impacted. 


Response
On Success 
HTTP Return code: 204
Parameter Name
Type
Description








On Failure
Status Code
Description
400
Bad Request
401
Bad Credentials
403
Permissions Denied
404
Not Found



Parameter Name
Type
Description








Example
Request HTTP Example:

DELETE 'https://{host}.jfrog.io/apptrust/api/v1/applications/my-web-app/package/npm/colors/1.4.0"
Content-Type: application/json
Authorization: ••••••

Request Body Example:
{
}

Response Body Example:
{
}


Activity Log Operations 
Get Activity Log
API

Description
Retrieves activity logs with optional filtering and sorting parameters.

Request URL
GET  https://{{artifactory-host}}/apptrust/api/v1/activity/log

Query Parameter
Parameter Name
Type
Description
application_key
array: string
Filter by application key (can be specified multiple times, CSV)
project_key
array: string
Filter by project key (can be specified multiple times, CSV)
timestamp_from
integer
Filter by timestamp from (unix timestamp)
timestamp_to
integer
Filter by timestamp to (unix timestamp)
subject_type
array: string
Filter by subject type (can be specified multiple times, CSV)
subject_name
string
Filter by subject name
event_type
array: string
Filter by event type (can be specified multiple times, CSV)
event_category
array: string
Filter by event category (can be specified multiple times, CSV)
result
array: string
Filter by result (can be specified multiple times, CSV). Can be success, failure, warning.
prefix
string
Filter by prefix
sort_by
string
Field to sort by (timestamp, event_id, subject_type, subject_name, event_type, event_category, result, application_key, project_key, created_by). Default: timestamp
sort
string
Sort order direction (asc, desc). Default: desc


Request Body
Parameter Name
Type






Response
On Success 
HTTP Return code: 200
Parameter Name
Type
Description
event_id
string
Unique identifier for the activity log entry
application_key
string
Key of the associated application
application_name
string
Display name of the associated application.
project_key
string
Key of the associated project
project_name
string
Display name of the associated project.
timestamp
integer
Unix timestamp when the event occurred
subject_type
string
Type of the subject that triggered the event
subject_name
string
Name of the subject that triggered the event
event_description
string
Human-readable description of the event
event_type
string
Type of event that occurred
event_category
string
Category classification of the event
created_by
string
User who initiated the event
result
string
Result status of the event (success, failure, warning)
additional_data
object
Additional structured data related to the event


On Failure
Status Code
Description
400
Bad Request
401
Unauthorized
403
Forbidden
500
Internal server error.



Parameter Name
Type
Description








Example
Request HTTP Example:

GET 'https://{host}.jfrog.io/apptrust/api/v1/activity/log?project_key=catalina&event_category=lifecycle&sort_by=timestamp&sort=desc' Authorization: •••••• 

Request Body Example:
{
}

Response Body Example:
[
  {
    "event_id": "01HN1234567890ABCDEFGHIJK",
    "timestamp": 1672531200000,
    "subject_type": "application",
    "subject_name": "catalina-app",
    "event_description": "Application version 1.2.0 promoted to QA",
    "event_type": "promote",
    "event_category": "lifecycle",
    "result": "success",
    "additional_data": {
      "version": "1.2.0",
      "stage": "QA"
    },
    "created_by": "admin@example.com",
    "application_key": "catalina-app",
    "application_name": "Catalina App",
    "project_key": "catalina",
    "project_name": "Catalina Project"
  },
  {
    "event_id": "01HN0987654321ZYXWVUTSRQP",
    "timestamp": 1672527600000,
    "subject_type": "application",
    "subject_name": "catalina-app",
    "event_description": "Application created successfully",
    "event_type": "create",
    "event_category": "lifecycle",
    "result": "success",
    "additional_data": {},
    "created_by": "admin@example.com",
    "application_key": "catalina-app",
    "application_name": "Catalina App",
    "project_key": "catalina",
    "project_name": "Catalina Project"
  }
]



AppTrust Webhooks
[
  {
    "id": "appTrust",
    "name": "AppTrust",
    "service": "appTrust",
    "event_types": [
      {
        "id": "entry_gate_evaluation",
        "name": "entry gate evaluation",
        "description": "The webhook is triggered when an entry gate evaluation starts.",
        "payload_sample": "{\"applicationVersion\":\"1.0.0\",\"applicationKey\":\"my-app\",\"stage\":\"qa\"}"
      },
      {
        "id": "entry_gate_validation",
        "name": "entry gate validation",
        "description": "The webhook is triggered when an entry gate is validated.",
        "payload_sample": "{\"applicationVersion\":\"1.0.0\",\"applicationKey\":\"my-app\",\"stage\":\"qa\"}"
      },
      {
        "id": "entry_gate_failure",
        "name": "entry gate failure",
        "description": "The webhook is triggered when an entry gate validation fails.",
        "payload_sample": "{\"applicationVersion\":\"1.0.0\",\"applicationKey\":\"my-app\",\"stage\":\"qa\"}"
      },
      {
        "id": "exit_gate_evaluation",
        "name": "exit gate evaluation",
        "description": "The webhook is triggered when an exit gate evaluation starts.",
        "payload_sample": "{\"applicationVersion\":\"1.0.0\",\"applicationKey\":\"my-app\",\"stage\":\"dev\"}"
      },
      {
        "id": "exit_gate_validation",
        "name": "exit gate validation",
        "description": "The webhook is triggered when an exit gate is validated.",
        "payload_sample": "{\"applicationVersion\":\"1.0.0\",\"applicationKey\":\"my-app\",\"stage\":\"dev\"}"
      },
      {
        "id": "exit_gate_failure",
        "name": "exit gate failure",
        "description": "The webhook is triggered when an exit gate validation fails.",
        "payload_sample": "{\"applicationVersion\":\"1.0.0\",\"applicationKey\":\"my-app\",\"stage\":\"dev\"}"
      },
      {
        "id": "release_started",
        "name": "release started",
        "description": "The webhook is triggered when a release process is started.",
        "payload_sample": "{\"applicationVersion\":\"1.0.0\",\"applicationKey\":\"my-app\",\"stage\":\"prod\"}"
      },
      {
        "id": "release_completed",
        "name": "release completed",
        "description": "The webhook is triggered when a release process is completed successfully.",
        "payload_sample": "{\"applicationVersion\":\"1.0.0\",\"applicationKey\":\"my-app\",\"stage\":\"prod\"}"
      },
      {
        "id": "release_failed",
        "name": "release failed",
        "description": "The webhook is triggered when a release process fails.",
        "payload_sample": "{\"applicationVersion\":\"1.0.0\",\"applicationKey\":\"my-app\",\"stage\":\"prod\"}"
      },
      {
        "id": "version_creation_started",
        "name": "version creation started",
        "description": "The webhook is triggered when an application version creation process starts.",
        "payload_sample": "{\"applicationVersion\":\"1.0.0\",\"applicationKey\":\"my-app\"}"
      },
      {
        "id": "version_creation_completed",
        "name": "version creation completed",
        "description": "The webhook is triggered when an application version creation process completes successfully.",
        "payload_sample": "{\"applicationVersion\":\"1.0.0\",\"applicationKey\":\"my-app\"}"
      },
      {
        "id": "version_creation_failed",
        "name": "version creation failed",
        "description": "The webhook is triggered when an application version creation process fails.",
        "payload_sample": "{\"applicationVersion\":\"1.0.0\",\"applicationKey\":\"my-app\"}"
      },
      {
        "id": "version_promotion_started",
        "name": "version promotion started",
        "description": "The webhook is triggered when an application version promotion process starts.",
        "payload_sample": "{\"applicationVersion\":\"1.0.0\",\"applicationKey\":\"my-app\",\"stage\":\"qa\"}"
      },
      {
        "id": "version_promotion_completed",
        "name": "version promotion completed",
        "description": "The webhook is triggered when an application version promotion process completes successfully.",
        "payload_sample": "{\"applicationVersion\":\"1.0.0\",\"applicationKey\":\"my-app\",\"stage\":\"qa\"}"
      },
      {
        "id": "version_promotion_failed",
        "name": "version promotion failed",
        "description": "The webhook is triggered when an application version promotion process fails.",
        "payload_sample": "{\"applicationVersion\":\"1.0.0\",\"applicationKey\":\"my-app\",\"stage\":\"qa\"}"
      }
    ]
  }
]




RLM Operations
Get Release Bundle Content
API

Description
Retrieves the details for a specified release bundle version, including its releasable artifacts, sources, and current lifecycle status.

Request URL
GET https://{{artifactory-host}}/lifecycle/api/v2/release_bundle/internal/details/{name}/{version}

Request Headers
Parameter Name
Description






Query Parameter
Parameter Name
Type
Description
project
string
Default: default
The project key of a Release Bundle, which defines its storing repository.
offset
int
Default: 0
The number of records to skip for pagination.
limit
int
Default: 25
The maximum number (up to 250) of records to return.
include
string
The level of detail for the response. Can be one of: sources, releasables,releasables_expanded.
package_type
string
Filters the releasables list by releasables.package_type.
Format: one or many <package_type> separated by commas.
Example: package_type=docker,maven,npm
source_build
string
Filters the releasables list by releasables.source[type: “build”]. 
Format: one or many <build_name:build_number> separated by commas.
Example: source_builds=This-Build:1.0.0,That-Build:2.0.0
source_release_bundle
string
Filters the releasables list by releasables.source[type: “release_bundle”].
Format: one or many <RB_name:RB_version> separated by commas.
Example: source_release_bundles=This-RB:1.0.0,That-RB:2.0.0
order_by
string
Default: name:asc
The field and order to sort the results by.
Format: field:order. 
Supported fields: name, package_type. 
Supported orders: asc, desc. (e.g., name:asc)


Request Body
Parameter Name
Type
Description








Response
On Success HTTP Return code: 200
Parameter Name
Type
Description
service_id
string
The unique identifier of the Artifactory instance where the Release Bundle version was created.
release_bundle_name
string
The name of the release bundle.
release_bundle_version
string
The version identifier of the release bundle.
project_key
string
The key of the project this release bundle belongs to.
release_bundle_sha256
string
The release bundle manifest’s digest.
status
string
The overall status of the release bundle version. Can be STARTED, FAILED, COMPLETED, DELETING.
created_by
string
The user ID that created this application version.
created_at
string
The ISO 8601 timestamp, indicating when the application version was created.
tag
string
A tag to be associated with the Release Bundle.  
release_status
string
The release status of the bundle. 
Can be PRE_RELEASE, RELEASED, TRUSTED_RELEASE
current_stage
string
The stage (environment label) of the latest successfully completed promotion.
current_promotion_created
string
The ISO 8601 timestamp, indicating when the application version was promoted (optional).
releasables_count	
int
The total number of releasables in the bundle.
artifacts_count
int
The total number of artifacts in the bundle.
total_size
int
The total size of all artifacts in the bundle in bytes.
releasables
array:object
An array of releasable items included in the bundle.
releasables.name
string
The name of the releasable (e.g., package name or artifact file name).
releasables.version
string
The version of the package. Empty for non-package files.
releasables.releasable_type
string
The type of releasable. Can be an artifact or package_version.
releasables.sha256
string
The SHA256 checksum of the leading file.
releasables.package_type
string
The repo-type where the package or artifact is found (e.g., docker, maven, generic). 
releasables.releasable_size
int
The total size of all artifacts in the releasable, in bytes.
releasables.sources
array:object
Describes how the releasable was added to this bundle.
releasables.sources.type
string
The type of the source (e.g., release_bundle, build, direct).
releasables.sources.release_bundle.name
string
The name of the source release bundle. 
This field only exists if the type is release_bundle.
releasables.sources.release_bundle.version
string
The version of the source release bundle.
This field only exists if the type is release_bundle.
releasables.sources.release_bundle.repo_key
string
The repository key where the source release bundle is stored.
This field only exists if the type is release_bundle.
releasables.sources.build.name
string
The name of the source build.
This field only exists if the type is build.
releasables.sources.build.number
string
The number of the source build.
This field only exists if the type is build.
releasables.sources.build.timestamp
string
The timestamp of when the build was created.
This field only exists if the type is build.
releasables.sources.build.repo_key
string
The repository key of the build-info repository.
This field only exists if the type is build.
releasables.artifacts
array:object
An array of artifacts that are part of this releasable.
releasables.artifacts.path
string
The repository path to the artifact.
releasables.artifacts.download_path
string
A full repository path to download an artifact from a Release Bundle repository.
releasables.artifacts.sha256
string
The SHA256 checksum of the artifact.
releasables.artifacts.size
int
The size of the artifact in bytes.
sources
array:object
A hierarchical list of sources from which this bundle was created.
sources.type
string
The type of the source (e.g., release_bundle, build, direct).
sources.build
object
Details for a build source. Present only if type is build.
sources.build.name
string
The name of the source build.
sources.build.number
string
The number of the source build.
sources.build.timestamp
string
The timestamp of when the build was created.
sources.build.repo_key
string
The repository key of the build-info repository.
sources.release_bundle
object
Details for a release_bundle source. Present only if type is release_bundle.
sources.release_bundle.name
string
The name of the source release bundle.
sources.release_bundle.version
string
The version of the source release bundle.
sources.release_bundle.repo_key
string
The repository key where the source release bundle is stored.
sources.release_bundle.application
boolean
An optional (nullable) indicator that a source Release Bundle represents an Application Version.
Can be either true or not present at all. Intended for internal integrations only, so the Application Service can differentiate between sources.release_bundle and sources.application_version.
sources.child_sources
array:object
A nested array of source objects, creating a hierarchy.
offset
int
The offset value used for this request.
limit
int
The limit value used for this request.
total
int
The total number of releasables respecting the provided parameters for filtering.



On Failure
Status Code
Description
message
400
Bad Request
The request was malformed. This could be due to an invalid value for a query parameter like view.
401
Bad Credentials
The request lacks valid authentication credentials.
403
Permissions Denied
The authenticated user does not have the necessary permissions to access the requested resource.
404
Resource not found
The requested release bundle name or version does not exist.


Example
include=null
Response Body Example:
{
    "service_id": "jfrt@01k0rvp1dtz2ex14zkv683083n",
    "release_bundle_name": "Commons-RB",
    "release_bundle_version": "1.0.1",
    "release_bundle_sha256": "465dd6e4df6f55dbb45027e4b831f91544e69bc27bfe1e4f2e7796f7f3f3347c",
    "created_by": "admin",
    "created_at": "2025-07-22T13:37:35.560Z",
    "project_key": "default",
    "status": "COMPLETED",
    "release_status": "PRE_RELEASE",
    "current_stage": "QA",
    "releasables_count": 7,
    "artifacts_count": 16,
    "total_size": 2663648
}


include=sources
Response Body Example:
{
    "service_id": "jfrt@01k0rvp1dtz2ex14zkv683083n",
    "release_bundle_name": "Commons-RB",
    "release_bundle_version": "1.0.1",
    "release_bundle_sha256": "465dd6e4df6f55dbb45027e4b831f91544e69bc27bfe1e4f2e7796f7f3f3347c",
    "created_by": "admin",
    "created_at": "2025-07-22T13:37:35.560Z",
    "project_key": "default",
    "status": "COMPLETED",
    "release_status": "PRE_RELEASE",
    "current_stage": "QA",
    "releasables_count": 7,
    "artifacts_count": 16,
    "total_size": 2663648,
    "sources": [
        {
            "type": "build",
            "build": {
                "repo_key": "artifactory-build-info",
                "name": "Commons-Build",
                "number": "1.0.1",
                "timestamp": "2025-07-22T13:44:10.442+0300"
            }
        },
        {
            "type": "release_bundle",
            "release_bundle": {
                "application": true,
                "repo_key": "release-bundles-v2",
                "name": "Commons-RB",
                "version": "1.0.0"
            }
        },
        {
            "type": "direct"
        }
    ]
}

include=releasables
Response Body Example:
{
    "service_id": "jfrt@01k0rvp1dtz2ex14zkv683083n",
    "release_bundle_name": "Commons-RB",
    "release_bundle_version": "1.0.1",
    "release_bundle_sha256": "465dd6e4df6f55dbb45027e4b831f91544e69bc27bfe1e4f2e7796f7f3f3347c",
    "created_by": "admin",
    "created_at": "2025-07-22T13:37:35.560Z",
    "project_key": "default",
    "status": "COMPLETED",
    "release_status": "PRE_RELEASE",
    "current_stage": "QA",
    "releasables_count": 7,
    "artifacts_count": 16,
    "total_size": 2663648,
    "releasables": [
        {
            "name": "commons",
            "version": "1.0.1",
            "package_type": "docker",
            "releasable_type": "package_version",
            "sha256": "79d4681724e705676e58d0823fe5daf631b6d7a3dc27e6ccb1582f7a01ab6264",
            "releasable_size": 1386,
            "sources": [
                {
                    "type": "build",
                    "build": {
                        "repo_key": "artifactory-build-info",
                        "name": "Commons-Build",
                        "number": "1.0.1",
                        "timestamp": "2025-07-22T13:44:10.442+0300"
                    }
                }
            ]
        },
        {
            "name": "commons",
            "version": "1.0.0",
            "package_type": "docker",
            "releasable_type": "package_version",
            "sha256": "058f1f75bdbea15401c7bb4adb466bc4090e68cdecce1b73e3ca7ab641de12c4",
            "releasable_size": 1386,
            "sources": [
                {
                    "type": "release_bundle",
                    "release_bundle": {
                        "application": true,
                        "repo_key": "release-bundles-v2",
                        "name": "Commons-RB",
                        "version": "1.0.0"
                    }
                }
            ]
        },
        {
            "name": "commons-1.0.0.txt",
            "package_type": "generic",
            "releasable_type": "artifact",
            "sha256": "f87e4c72e60300b451739d545afc0251a6e2f4bd1beaa1902ba739455897ecb8",
            "releasable_size": 470,
            "sources": [
                {
                    "type": "release_bundle",
                    "release_bundle": {
                        "application": true,
                        "repo_key": "release-bundles-v2",
                        "name": "Commons-RB",
                        "version": "1.0.0"
                    }
                }
            ]
        },
        {
            "name": "commons-1.0.1.txt",
            "package_type": "generic",
            "releasable_type": "artifact",
            "sha256": "66f39929e6a3fe18b4fea1feb3096849baa24d79cee75ef64247b195ccb709a0",
            "releasable_size": 470,
            "sources": [
                {
                    "type": "build",
                    "build": {
                        "repo_key": "artifactory-build-info",
                        "name": "Commons-Build",
                        "number": "1.0.1",
                        "timestamp": "2025-07-22T13:44:10.442+0300"
                    }
                }
            ]
        },
        {
            "name": "commons-1.0.2.txt",
            "package_type": "generic",
            "releasable_type": "artifact",
            "sha256": "3c380adfb7961d003508c8c7fd1915339adfd8e66a899d3bf54ee70ffef3a303",
            "releasable_size": 470,
            "sources": [
                {
                    "type": "direct"
                }
            ]
        },
        {
            "name": "org.apache.tomcat:commons",
            "version": "1.0.1",
            "package_type": "maven",
            "releasable_type": "package_version",
            "sha256": "00079acbdddb305eb6386d81df20680d24f86ad0e42058c1b81a8d5eaf89106b",
            "releasable_size": 2652059,
            "sources": [
                {
                    "type": "build",
                    "build": {
                        "repo_key": "artifactory-build-info",
                        "name": "Commons-Build",
                        "number": "1.0.1",
                        "timestamp": "2025-07-22T13:44:10.442+0300"
                    }
                }
            ]
        },
        {
            "name": "org.apache.tomcat:commons",
            "version": "1.0.0",
            "package_type": "maven",
            "releasable_type": "package_version",
            "sha256": "42a32d492427ecd97921f56063742ff156917283cc1d491b274a133b15234839",
            "releasable_size": 7407,
            "sources": [
                {
                    "type": "release_bundle",
                    "release_bundle": {
                        "application": true,
                        "repo_key": "release-bundles-v2",
                        "name": "Commons-RB",
                        "version": "1.0.0"
                    }
                }
            ]
        }
    ],
    "offset": 0,
    "limit": 25,
    "total": 7
}


include=sources,releasables_expanded
Response Body Example:
{
    "service_id": "jfrt@01k0rvp1dtz2ex14zkv683083n",
    "release_bundle_name": "Commons-RB",
    "release_bundle_version": "1.0.1",
    "release_bundle_sha256": "465dd6e4df6f55dbb45027e4b831f91544e69bc27bfe1e4f2e7796f7f3f3347c",
    "created_by": "admin",
    "created_at": "2025-07-22T13:37:35.560Z",
    "project_key": "default",
    "status": "COMPLETED",
    "release_status": "PRE_RELEASE",
    "current_stage": "QA",
    "releasables_count": 7,
    "artifacts_count": 16,
    "total_size": 2663648,
    "releasables": [
        {
            "name": "commons",
            "version": "1.0.1",
            "package_type": "docker",
            "releasable_type": "package_version",
            "sha256": "79d4681724e705676e58d0823fe5daf631b6d7a3dc27e6ccb1582f7a01ab6264",
            "releasable_size": 1386,
            "sources": [
                {
                    "type": "build",
                    "build": {
                        "repo_key": "artifactory-build-info",
                        "name": "Commons-Build",
                        "number": "1.0.1",
                        "timestamp": "2025-07-22T13:44:10.442+0300"
                    }
                }
            ],
            "artifacts": [
                {
                    "path": "commons/1.0.1/manifest.json",
                    "download_path": "release-bundles-v2/Commons-RB/1.0.1/artifacts/docker/commons/1.0.1/manifest.json",
                    "sha256": "79d4681724e705676e58d0823fe5daf631b6d7a3dc27e6ccb1582f7a01ab6264",
                    "size": 523
                },
                {
                    "path": "commons/1.0.1/sha256__534b364b35f9cfd69f9d8ebdaf9508b15eddab9281c10e43b8ed99d31fbab2a5",
                    "download_path": "release-bundles-v2/Commons-RB/1.0.1/artifacts/docker/commons/1.0.1/sha256__534b364b35f9cfd69f9d8ebdaf9508b15eddab9281c10e43b8ed99d31fbab2a5",
                    "sha256": "534b364b35f9cfd69f9d8ebdaf9508b15eddab9281c10e43b8ed99d31fbab2a5",
                    "size": 207
                },
                {
                    "path": "commons/1.0.1/sha256__68014ce29b3c51c42bca81a719ff35d57431328ab61569d03f85facf6b57f0b8",
                    "download_path": "release-bundles-v2/Commons-RB/1.0.1/artifacts/docker/commons/1.0.1/sha256__68014ce29b3c51c42bca81a719ff35d57431328ab61569d03f85facf6b57f0b8",
                    "sha256": "68014ce29b3c51c42bca81a719ff35d57431328ab61569d03f85facf6b57f0b8",
                    "size": 656
                }
            ]
        },
        {
            "name": "commons",
            "version": "1.0.0",
            "package_type": "docker",
            "releasable_type": "package_version",
            "sha256": "058f1f75bdbea15401c7bb4adb466bc4090e68cdecce1b73e3ca7ab641de12c4",
            "releasable_size": 1386,
            "sources": [
                {
                    "type": "release_bundle",
                    "release_bundle": {
                        "application": true,
                        "repo_key": "release-bundles-v2",
                        "name": "Commons-RB",
                        "version": "1.0.0"
                    }
                }
            ],
            "artifacts": [
                {
                    "path": "commons/1.0.0/manifest.json",
                    "download_path": "release-bundles-v2/Commons-RB/1.0.1/artifacts/docker/commons/1.0.0/manifest.json",
                    "sha256": "ee135d815ce5e653187e7c3573203c743d83582e247b9469066cb31d167ae060",
                    "size": 523
                },
                {
                    "path": "commons/1.0.0/sha256__058f1f75bdbea15401c7bb4adb466bc4090e68cdecce1b73e3ca7ab641de12c4",
                    "download_path": "release-bundles-v2/Commons-RB/1.0.1/artifacts/docker/commons/1.0.0/sha256__058f1f75bdbea15401c7bb4adb466bc4090e68cdecce1b73e3ca7ab641de12c4",
                    "sha256": "058f1f75bdbea15401c7bb4adb466bc4090e68cdecce1b73e3ca7ab641de12c4",
                    "size": 656
                },
                {
                    "path": "commons/1.0.0/sha256__ba6b0809a41c086fdbe29433a16d10e9debd498466cedc23d9d884f25225cdf4",
                    "download_path": "release-bundles-v2/Commons-RB/1.0.1/artifacts/docker/commons/1.0.0/sha256__ba6b0809a41c086fdbe29433a16d10e9debd498466cedc23d9d884f25225cdf4",
                    "sha256": "ba6b0809a41c086fdbe29433a16d10e9debd498466cedc23d9d884f25225cdf4",
                    "size": 207
                }
            ]
        },
        {
            "name": "commons-1.0.0.txt",
            "package_type": "generic",
            "releasable_type": "artifact",
            "sha256": "f87e4c72e60300b451739d545afc0251a6e2f4bd1beaa1902ba739455897ecb8",
            "releasable_size": 470,
            "sources": [
                {
                    "type": "release_bundle",
                    "release_bundle": {
                        "application": true,
                        "repo_key": "release-bundles-v2",
                        "name": "Commons-RB",
                        "version": "1.0.0"
                    }
                }
            ],
            "artifacts": [
                {
                    "path": "commons-1.0.0.txt",
                    "download_path": "release-bundles-v2/Commons-RB/1.0.1/artifacts/generic/commons-1.0.0.txt",
                    "sha256": "f87e4c72e60300b451739d545afc0251a6e2f4bd1beaa1902ba739455897ecb8",
                    "size": 470
                }
            ]
        },
        {
            "name": "commons-1.0.1.txt",
            "package_type": "generic",
            "releasable_type": "artifact",
            "sha256": "66f39929e6a3fe18b4fea1feb3096849baa24d79cee75ef64247b195ccb709a0",
            "releasable_size": 470,
            "sources": [
                {
                    "type": "build",
                    "build": {
                        "repo_key": "artifactory-build-info",
                        "name": "Commons-Build",
                        "number": "1.0.1",
                        "timestamp": "2025-07-22T13:44:10.442+0300"
                    }
                }
            ],
            "artifacts": [
                {
                    "path": "commons-1.0.1.txt",
                    "download_path": "release-bundles-v2/Commons-RB/1.0.1/artifacts/generic/commons-1.0.1.txt",
                    "sha256": "66f39929e6a3fe18b4fea1feb3096849baa24d79cee75ef64247b195ccb709a0",
                    "size": 470
                }
            ]
        },
        {
            "name": "commons-1.0.2.txt",
            "package_type": "generic",
            "releasable_type": "artifact",
            "sha256": "3c380adfb7961d003508c8c7fd1915339adfd8e66a899d3bf54ee70ffef3a303",
            "releasable_size": 470,
            "sources": [
                {
                    "type": "direct"
                }
            ],
            "artifacts": [
                {
                    "path": "commons-1.0.2.txt",
                    "download_path": "release-bundles-v2/Commons-RB/1.0.1/artifacts/generic/commons-1.0.2.txt",
                    "sha256": "3c380adfb7961d003508c8c7fd1915339adfd8e66a899d3bf54ee70ffef3a303",
                    "size": 470
                }
            ]
        },
        {
            "name": "org.apache.tomcat:commons",
            "version": "1.0.1",
            "package_type": "maven",
            "releasable_type": "package_version",
            "sha256": "00079acbdddb305eb6386d81df20680d24f86ad0e42058c1b81a8d5eaf89106b",
            "releasable_size": 2652059,
            "sources": [
                {
                    "type": "build",
                    "build": {
                        "repo_key": "artifactory-build-info",
                        "name": "Commons-Build",
                        "number": "1.0.1",
                        "timestamp": "2025-07-22T13:44:10.442+0300"
                    }
                }
            ],
            "artifacts": [
                {
                    "path": "org/apache/tomcat/commons/1.0.1/commons-1.0.1-jar-with-dependencies.jar",
                    "download_path": "release-bundles-v2/Commons-RB/1.0.1/artifacts/maven/org/apache/tomcat/commons/1.0.1/commons-1.0.1-jar-with-dependencies.jar",
                    "sha256": "4cc59b113d2c53f3ac3572feebad7333b36a969843980f001ece46f19ad220b2",
                    "size": 2643388
                },
                {
                    "path": "org/apache/tomcat/commons/1.0.1/commons-1.0.1-tests.jar",
                    "download_path": "release-bundles-v2/Commons-RB/1.0.1/artifacts/maven/org/apache/tomcat/commons/1.0.1/commons-1.0.1-tests.jar",
                    "sha256": "ea7c6ee3237487dcb35d90a70752a939120a3450cb7569030d2f33406ae108d6",
                    "size": 2661
                },
                {
                    "path": "org/apache/tomcat/commons/1.0.1/commons-1.0.1.jar",
                    "download_path": "release-bundles-v2/Commons-RB/1.0.1/artifacts/maven/org/apache/tomcat/commons/1.0.1/commons-1.0.1.jar",
                    "sha256": "c03497c62e122af3b9e2e05c5aa0acbee904ad4a93a9100eae84deeed0d07612",
                    "size": 2678
                },
                {
                    "path": "org/apache/tomcat/commons/1.0.1/commons-1.0.1.pom",
                    "download_path": "release-bundles-v2/Commons-RB/1.0.1/artifacts/maven/org/apache/tomcat/commons/1.0.1/commons-1.0.1.pom",
                    "sha256": "00079acbdddb305eb6386d81df20680d24f86ad0e42058c1b81a8d5eaf89106b",
                    "size": 3332
                }
            ]
        },
        {
            "name": "org.apache.tomcat:commons",
            "version": "1.0.0",
            "package_type": "maven",
            "releasable_type": "package_version",
            "sha256": "42a32d492427ecd97921f56063742ff156917283cc1d491b274a133b15234839",
            "releasable_size": 7407,
            "sources": [
                {
                    "type": "release_bundle",
                    "release_bundle": {
                        "application": true,
                        "repo_key": "release-bundles-v2",
                        "name": "Commons-RB",
                        "version": "1.0.0"
                    }
                }
            ],
            "artifacts": [
                {
                    "path": "org/apache/tomcat/commons/1.0.0/commons-1.0.0-tests.jar",
                    "download_path": "release-bundles-v2/Commons-RB/1.0.1/artifacts/maven/org/apache/tomcat/commons/1.0.0/commons-1.0.0-tests.jar",
                    "sha256": "47d0c55a4c114ed8d0eef350f6b01b0afc36d16dcf458c1e1ad547e2894b0770",
                    "size": 2543
                },
                {
                    "path": "org/apache/tomcat/commons/1.0.0/commons-1.0.0.jar",
                    "download_path": "release-bundles-v2/Commons-RB/1.0.1/artifacts/maven/org/apache/tomcat/commons/1.0.0/commons-1.0.0.jar",
                    "sha256": "42a32d492427ecd97921f56063742ff156917283cc1d491b274a133b15234839",
                    "size": 2560
                },
                {
                    "path": "org/apache/tomcat/commons/1.0.0/commons-1.0.0.pom",
                    "download_path": "release-bundles-v2/Commons-RB/1.0.1/artifacts/maven/org/apache/tomcat/commons/1.0.0/commons-1.0.0.pom",
                    "sha256": "e5be371d36fbf45268fe32a71608946d3eabf4af1d8be7f508f0c2f7f8ca7765",
                    "size": 2304
                }
            ]
        }
    ],
    "sources": [
        {
            "type": "build",
            "build": {
                "repo_key": "artifactory-build-info",
                "name": "Commons-Build",
                "number": "1.0.1",
                "timestamp": "2025-07-22T13:44:10.442+0300"
            }
        },
        {
            "type": "release_bundle",
            "release_bundle": {
                "application": true,
                "repo_key": "release-bundles-v2",
                "name": "Commons-RB",
                "version": "1.0.0"
            }
        },
        {
            "type": "direct"
        }
    ],
    "offset": 0,
    "limit": 25,
    "total": 7
}




GET RBv2 Promotions 
API

Description
Returns the details of all promotions for the specified Application version. 

Request URL
GET https://{{artifactory-host}}/…
Query Parameter
Parameter Name
Type
Description
include {messages}
string
Returns any error messages generated when creating the promotion.
offset
integer
Sets the number of records to skip before returning the query response. Used for pagination purposes.
limit
integer
Sets the maximum number of versions to return at one time. Used for pagination purposes.
filter_by


Defines a filter for the list of promotions.

You can filter according to:
bundle_version  (for example, filter_by=1.0.0)
source_stage  (for example, filter_by=QA)
target_stage  (for example, filter_by=QA)
promotion_created_by (for example, filter_by=user1)
status (e.g., "success", "pending", "failed").
order_by
string
Default: created
Defines the criterion by which to order the list of promotions: created (standard timestamp or milliseconds),  created_by, release_bundle_version , stage
order_asc
boolean
Default: false
Defines whether to list the application in ascending (true) or descending (false) order.


Request Body
Parameter Name
Type
Description








Response
On Success 
HTTP Return code: 200
Parameter Name
Type
Description
status
string
Filters promotion records by their current status (e.g., "success", "pending", "failed").
repository_key
string
The key of the repository associated with the promotion
release_bundle_name
string
The name of the release bundle.
release_bundle_version
string
The version of the release bundle.
source_environment
string
The lifecycle stage from which the application version was promoted.
environment
string
The lifecycle stage to which the application version was promoted.
service_id
string
The ID of the service involved in the operation.
created_by
string
The user ID or entity that initiated the promotion.
created
string
The ISO 8601 timestamp indicating when the promotion record was created.
created_millis
int
The timestamp in milliseconds since the Unix epoch when the promotion record was created.
xray_retrieval_status
string
The status of Xray's retrieval and scanning process for the promoted version.
total
int
The total number of releasable records returned.
limit
int
The offset value used for this request.
offset
int
The limit value used for this request.

On Failure
Status Code
Description
401
Bad Credentials
403
Permissions Denied



Parameter Name
Type
Description
status
string
Filters promotion records by their current status (e.g., "success", "pending", "failed").
repository_key
string
The key of the repository associated with the promotion
release_bundle_name
string
The name of the release bundle.
release_bundle_version
string
The version of the release bundle.
source_stage
string
The lifecycle stage from which the application version was promoted.
target_stage
string
The lifecycle stage to which the application version was promoted.
service_id
string
The ID of the service involved in the operation.
created_by
string
The user ID or entity that initiated the promotion.
created
string
The ISO 8601 timestamp indicating when the promotion record was created.
created_millis
int
The timestamp in milliseconds since the Unix epoch when the promotion record was created.
xray_retrieval_status
string
The status of Xray's retrieval and scanning process for the promoted version.
messages
String
Error messages related to the processing of the operation (if any).
total
int
The total number of releasable records returned.
limit
int
The offset value used for this request.
offset
int
The limit value used for this request.


Example
Request HTTP Example:



Request Body Example:
{
}

Response Body Example:
{
    "promotions": [
        {
            "status": "FAILED",
            "repository_key": "release-bundles-v2",
            "release_bundle_name": "Commons-Bundle",
            "release_bundle_version": "1.0.0",
            "source_stage": "QA",
            "target_stage": "Staging",
            "service_id": "jfrt@01h0nvs1pwjtzs15x7kbtv1sve",
            "created_by": "admin",
            "created": "2023-05-19T06:47:56.518Z",
            "created_millis": 1684478876518,
            "xray_retrieval_status": "NOT_APPLICABLE",
            "messages": [
                {
                    "text": "Target artifact already exists: commons-qa-generic-local/commons/release-notes-1.0.0.txt"
                }
            ]
        },
        {
            "status": "COMPLETED",
            "repository_key": "release-bundles-v2",
            "release_bundle_name": "Commons-Bundle",
            "release_bundle_version": "1.0.0",
            "source_stage": "QA",
            "target_stage": "Staging",
            "service_id": "jfrt@01h0nvs1pwjtzs15x7kbtv1sve",
            "created_by": "admin",
            "created": "2023-05-19T06:21:44.916Z",
            "created_millis": 1684477304916,
            "xray_retrieval_status": "NOT_APPLICABLE"
        }
    ],
    "total": 2,
    "limit": 1000,
    "offset": 0
}



Get 
API

Description
Retrieves a list of all release bundle versions that contain a specific package version.

Request URL
GET https://{{artifactory-host}}/lifecycle/
Query Parameter
Parameter Name
Type
Description








Request Body
Parameter Name
Type
Description








Response
On Success 
HTTP Return code: 200
Parameter Name
Type
Description







On Failure
Status Code
Description











Parameter Name
Type
Description








Example
Request HTTP Example:



Request Body Example:
{
}

Response Body Example:
{
}
