# HelloID-Conn-Prov-Target-Atlassian-Jira

| :information_source: Information |
|:---------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.       |

<br />
<p align="center">
  <img src="https://www.tools4ever.nl/connector-logos/atlassianjira-logo.png">
</p> 

## Versioning
| Version | Description | Date |
| - | - | - |
| 2.0.0   | New PowerShell v2 target | 2024/01/15 |
| 1.1.0   | Updated with group management | 2022/12/15  |
| 1.0.0   | Initial release | 2021/04/02  |

<!-- TABLE OF CONTENTS -->
## Table of Contents
- [Versioning](#versioning)
- [Table of Contents](#table-of-contents)
- [Introduction](#introduction)
- [Connection settings](#connection-settings)
- [Getting help](#getting-help)
- [HelloID Docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Target-Atlassian-Jira_ is a _target_ connector. _HelloID-Conn-Prov-Target-Atlassian-Jira_ provides a set of REST API's that allow you to programmatically interact with its data. The HelloID connector uses the API endpoints listed in the table below.

| Endpoint | Description |
| -------- | ----------- |
| /user    |             |
| /groups  |             |
| /group   |             |

Use the documentation of Atlassian to know more about the endpoints: 
- https://developer.atlassian.com/cloud/jira/platform/rest/v3/ 
- https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-users/#api-rest-api-3-user-post


The following lifecycle actions are available:
| Action                 | Description                                      |
| ---------------------- | ------------------------------------------------ |
| create.ps1             | PowerShell _create_ lifecycle action             |
| delete.ps1             | PowerShell _delete_ lifecycle action             |            |
| grantPermission.ps1    | PowerShell _grant_ lifecycle action              |
| revokePermission.ps1   | PowerShell _revoke_ lifecycle action             |
| permissions.ps1        | PowerShell _permissions_ lifecycle action        |
| configuration.json     | Default _[configuration.json](https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-Atlassian-Jira/blob/main/target/configuration.json)_ |
| fieldMapping.json      | Default _[fieldMapping.json](https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-Atlassian-Jira/blob/main/target/fieldMapping.json)_   |



## Provisioning PowerShell V2 connector

### Correlation configuration

The correlation configuration is used to specify which properties will be used to match an existing account within _Atlassian Jira_ to a person in _HelloID_.

To properly set up the correlation:

1. Open the `Correlation` tab.

2. Specify the following configuration:

    | Setting                   | Value                                                  |
    | ------------------------- | ------------------------------------------------------ |
    | Enable correlation        | `True`                                                 |
    | Person correlation field  | Not set                                                |
    | Account correlation field | `Name`                                    |

> [!TIP]
> _For more information on correlation, please refer to our correlation [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems/correlation.html) pages_.

### Field mapping
The field mapping can be imported by using the _fieldMapping.json_ file. 
For more information about importing target mappings click [here](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems/target-mappings/import-target-mappings.html). 

### Connection settings
The following settings are required to connect to the API.

| Setting     | Description |
| ------------ | ----------- |
| Jira Url | Example: https://customer.atlassian.net |
| Username | User with the correct permissions |
| Password | Password of the user |


## Getting help
> [!TIP]
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages_

> [!TIP]
> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

# HelloID Docs
The official HelloID documentation can be found at: https://docs.helloid.com/
