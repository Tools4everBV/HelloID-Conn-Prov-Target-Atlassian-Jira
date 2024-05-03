# HelloID-Conn-Prov-Target-Atlassian-Jira

> [!IMPORTANT]
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<p align="center">
  <img src="https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-Atlassian-Jira/blob/main/Logo.png?raw=true">
</p> 

## Table of contents

- [HelloID-Conn-Prov-Target-Atlassian-Jira](#helloid-conn-prov-target-atlassian-jira)
  - [Table of contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Remarks](#remarks)
  - [Introduction](#introduction)
  - [Getting started](#getting-started)
    - [Provisioning PowerShell V2 connector](#provisioning-powershell-v2-connector)
      - [Correlation configuration](#correlation-configuration)
      - [Field mapping](#field-mapping)
    - [Connection settings](#connection-settings)
  - [Setup the connector](#setup-the-connector)
    - [API token](#api-token)
    - [Permissions](#permissions)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Prerequisites
- [ ] _HelloID_ Provisioning agent (cloud or on-prem).
- [ ] _HelloID_ environment.
- [ ] API token in Atlassian. The following values are needed to connect:
  - [ ] Username.
  - [ ] Password.

## Remarks
- There is no update API available, therefore there is no update action available either.

## Introduction
_HelloID-Conn-Prov-Target-Atlassian-Jira_ is a _target_ connector. _Atlassian_ provides a set of REST API's that allow you to programmatically interact with its data. The Atlassian jira connector uses the API endpoints listed in the table below.

| Endpoint                                                                                                                                    | Description            |
| ------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------- |
| [/rest/api/3/user](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-users/#api-rest-api-3-user-post)                   | Create user (POST)     |
| [/rest/api/3/user](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-users/#api-rest-api-3-user-delete)                 | Delete user (DELETE)   |
| [/rest/api/3/groups/picker](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-groups/#api-rest-api-3-groups-picker-get) | List groups (GET)      |
| [/rest/api/3/group/user](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-groups/#api-rest-api-3-group-user-post)      | Add member (POST)      |
| [/rest/api/3/group/user](https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-groups/#api-rest-api-3-group-user-delete)    | Remove member (DELETE) |


The following lifecycle actions are available:

| Action                        | Description                            |
| ----------------------------- | -------------------------------------- |
| create.ps1                    | Create or correlate to an account      |
| delete.ps1                    | Delete an account                      |
| groups - permissions.ps1      | List groups as permissions             |
| groups - grantPermission.ps1  | Grant groupmembership to an account    |
| groups - revokePermission.ps1 | Revoke groupmembership from an account |
| configuration.json            | Default _configuration.json_           |
| fieldMapping.json             | Default _fieldMapping.json_            |

## Getting started
By using this connector you will have the ability to seamlessly create delete and user accounts in Atlassian Jira. Additionally, you can manage the groupmemberships.

Connecting to Atlassian API is straightforward. Simply utilize the API Username and API Password pair and connect using basic authentication.
For further details, refer to the following pages in the Atlassian Docs:
[Basic auth for REST APIs](https://developer.atlassian.com/cloud/jira/platform/basic-auth-for-rest-apis/).

### Provisioning PowerShell V2 connector

#### Correlation configuration
The correlation configuration is used to specify which properties will be used to match an existing account within _Atlassian Jira_ to a person in _HelloID_.

To properly setup the correlation:

1. Open the `Correlation` tab.

2. Specify the following configuration:

    | Setting                   | Value  |
    | ------------------------- | ------ |
    | Enable correlation        | `True` |
    | Person correlation field  | ``     |
    | Account correlation field | `name` |

> [!TIP]
> _For more information on correlation, please refer to our correlation [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems/correlation.html) pages_.

#### Field mapping
The field mapping can be imported by using the _fieldMapping.json_ file.

### Connection settings
The following settings are required to connect to the API.

| Setting           | Description                                                                                                                  | Mandatory |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------- | --------- |
| Jira API URL      | The URL to the Jira environment                                                                                              | Yes       |
| Jira API Username | The Username to connect to the Jira environment                                                                              | Yes       |
| Jira API Token    | The API token to connect to the Jira environment                                                                             | Yes       |
| IsDebug           | When toggled, extra logging is shown. Note that this is only meant for debugging, please switch this off when in production. | No        |


## Setup the connector
### API token
Before you can connect to the Atlassian API and send requests, you need to register a new API token. This token serves as your gateway to the API, enabling you to establish connections and manage permissions effectively. To generate your API token, please refer to the instructions provided by Atlassian: [Manage API tokens for your Atlassian account](https://support.atlassian.com/atlassian-account/docs/manage-api-tokens-for-your-atlassian-account/)

### Permissions
The Jira REST API operates under the same access restrictions as the standard Jira web interface. This means that accessing Jira via the API requires proper authentication and authorization. If you attempt to access resources without proper permissions, you will encounter similar limitations as when accessing Jira through its web interface. In essence, your access via the Jira REST API mirrors your access privileges within the Jira environment.

## Getting help
> [!TIP]
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages_.

> [!TIP]
>  _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_.

## HelloID docs
The official HelloID documentation can be found at: https://docs.helloid.com/
